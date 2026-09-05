import type { SupabaseClient } from '@supabase/supabase-js'
import { randomUUID } from 'node:crypto'
import type { ForhandsPayload } from './typer'
import type { Rapporttype } from '@/lib/parsere/typer'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import { erBpFil, parseBp } from '@/lib/parsere/bp'
import { erBp25Fil, parseBp25 } from '@/lib/parsere/bp25'
import { bpLinjer as byggLinjer, type Bplinje } from '@/lib/bp/rader'
import { manglendeStasjoner, dekningsnotat, erDaglig } from './stasjonsdekning'
import { hoppetNotat } from '@/lib/bp/hoppede'
import { bruttoKurve, timelonnKurve, maanedsrammer } from '@/lib/bp/fordeling'
import { parseDelingsfil, type Kastbudsjett } from '@/lib/parsere/delingsfil'
import { arknavn } from '@/lib/parsere/xlsx-rader'
import { aarsgrunnlagFra, finnAaret } from '@/lib/bp/delingsfil-aar'
import { koblePaaNavn } from '@/lib/bp/stasjonsnavn'
import { matbudsjettPerAar } from '@/lib/bp/hent'
import {
  LONNSKONTI, SYKEKONTI, kjedensSykesats, type Regnskapsrad,
} from '@/lib/bemanning/sykereserve'
import { erPdf, erTekstfil, pdfTilTekst } from '@/lib/parsere/pdf'
import { lagStasjonsmatcher } from './stasjonsmatch'
import { parseStempling, gjenkjennStempling, utenDubletter } from '@/lib/parsere/stempling'
import { lagBemanningsvarsler } from '@/lib/bemanningsvarsler'
import { after } from 'next/server'
import { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import { kjorRegnskapsanalyse } from '@/lib/ai/regnskapsanalyse'
import { genererFokusForRetailer } from '@/lib/ai/fokus'
import { ParserFeil, forsteDatoIso } from '@/lib/parsere/felles'
import { opprettVarsel } from '@/lib/varsler'
import { vurderDag, UKER_TILBAKE } from './rimelighet'
import { berorteUker } from './ukecache'
import { vurderDublett } from './dublett'
import { lagKaffevarsel } from '@/lib/kaffesvinn'

// Behandlings-kjernen (§6). Tar imot en supabase-klient — UI-knappen bruker
// brukersesjonen, e-post-webhooken bruker service-role. Ingen session/revalidate
// her, så den kan kjøres fra begge.
type Klient = SupabaseClient
/**
 * Merknaden om stasjoner som ikke var i fila.
 *
 * Bare for datasett som kommer EN FIL PER DAG. For regnskap, BP og svinn
 * er en stasjon uten rader helt normalt, og en merknad ville vaert stoey
 * - og stoey laerer folk aa se bort fra merknader.
 */
function stasjonsmerknad(
  rapporttype: Rapporttype,
  res: Lagring,
  stasjoner: { id: string; navn: string; butikknummer: string }[],
): string | null {
  if (!erDaglig(rapporttype) || !res.truffet || res.antallRader === 0) return null
  return dekningsnotat(manglendeStasjoner(res.truffet, stasjoner))
}

type Lagring = {
  antallRader: number
  umatchet: string[]
  notat?: string | null
  /**
   * Stasjons-id-ene lagringen faktisk skrev noe for.
   *
   * `umatchet` fanger en stasjon i fila vi ikke kjenner. Dette fanger
   * speilbildet - en stasjon vi kjenner som ikke er i fila - og det er
   * det farligste av de to: en ukjent stasjon roper, en manglende tier.
   * Se `stasjonsdekning.ts`.
   */
  truffet?: string[]
}

// Skriver rader i batcher (ikke én diger insert) — holder hvert kall raskt og
// under grensene, så store/mange filer ikke timer ut. Feiler en batch, sies
// hvilken (resten av importen kan kjøres på nytt idempotent).
const BATCH = 500

// Postgres nekter to rader med samme konfliktnoekkel i EN upsert:
// «ON CONFLICT DO UPDATE command cannot affect row a second time». Den
// feilmeldingen sier ingenting om hvilken rad, og en importor som skal
// vite dette om hver eneste tabell kommer til aa glemme det.
//
// Invarianten hoerer hjemme her, paa noeyaktig de kolonnene konflikten
// gjelder. Siste rad vinner - kallerne sorterer selv slik at den de vil
// beholde kommer sist (se utenDubletter i stempling.ts).
function utenKonfliktdubletter(
  rader: Record<string, unknown>[],
  onConflict: string,
): Record<string, unknown>[] {
  const kolonner = onConflict.split(',').map((k) => k.trim()).filter(Boolean)
  if (kolonner.length === 0) return rader
  const sett = new Map<string, Record<string, unknown>>()
  // JSON, ikke en skilletegn-streng: en verdi som selv inneholder skilletegnet
  // ville ellers kunne kollidere med en annen kombinasjon.
  for (const rad of rader) sett.set(JSON.stringify(kolonner.map((k) => rad[k])), rad)
  return sett.size === rader.length ? rader : [...sett.values()]
}

async function skrivBatch(supabase: Klient, tabell: string, rader: Record<string, unknown>[], onConflict?: string): Promise<void> {
  if (onConflict) rader = utenKonfliktdubletter(rader, onConflict)
  for (let i = 0; i < rader.length; i += BATCH) {
    const bit = rader.slice(i, i + BATCH)
    const { error } = onConflict
      ? await supabase.from(tabell).upsert(bit, { onConflict })
      : await supabase.from(tabell).insert(bit)
    if (error) throw new ParserFeil(`Lagring feilet (batch ${Math.floor(i / BATCH) + 1} av ${Math.ceil(rader.length / BATCH)}): ${error.message}`)
  }
}

async function hentStasjonsoppslag(supabase: Klient) {
  const { data } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn')
    .is('slettet_tid', null)
  const stasjoner = (data ?? []) as { id: string; butikknummer: string; navn: string }[]
  const medNummer = new Map<string, string>()
  const medNavn = new Map<string, string>()
  for (const s of stasjoner) {
    medNummer.set(s.butikknummer, s.id)
    medNavn.set(s.navn.trim().toLowerCase(), s.id)
  }
  return { medNummer, medNavn, stasjoner }
}

function datoFraFilnavn(filnavn: string): string | null {
  return forsteDatoIso(filnavn) ?? filnavn.match(/(\d{4})-(\d{2})-(\d{2})/)?.[0] ?? null
}

function periodeFraFilnavn(filnavn: string): string | null {
  const m = filnavn.match(/(20\d{2})(\d{2})/)
  return m ? `${m[1]}-${m[2]}-01` : null
}

// Behandler én kø-jobb: last ned → gjenkjenn → parse → lagre. Returnerer om
// noe ble lagret. Setter status undervegs og varsler ved feil.
export async function behandleJobbKjerne(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
): Promise<void> {
  const { data: jobb } = await supabase
    .from('import_jobber')
    .select('id, raa_filer(filnavn, storage_bucket, storage_sti)')
    .eq('id', jobbId)
    .single<{
      id: string
      raa_filer: { filnavn: string; storage_bucket: string; storage_sti: string } | null
    }>()
  if (!jobb?.raa_filer) return

  const settFeil = async (melding: string) => {
    await supabase.from('import_jobber').update({ status: 'feilet', feilmelding: melding }).eq('id', jobbId)
    await opprettVarsel(supabase, {
      retailer_id: retailerId,
      type: 'import_feil',
      tittel: `Import feilet: ${jobb.raa_filer?.filnavn ?? 'fil'}`,
      tekst: melding,
      lenke: '/import',
    })
  }

  // =====================================================================
  // EN JOBB UTEN FIL KAN IKKE BEHANDLES PAA NYTT - OG SKAL IKKE PROEVE
  //
  // Filer som parses i NETTLESEREN lagres aldri i Storage; klienten har
  // dem, og serveren faar bare resultatet. `klient/<uuid>-<filnavn>` er
  // en sentinel-sti som bare finnes fordi kolonnen er NOT NULL - se
  // `lagreForhandsparset`.
  //
  // «Behandle»-knappen ble likevel tilbudt paa dem. Trykket man den,
  // satte serveren status til `behandler`, fant ingen fil, og skrev
  // `feilet` over en jobb som hadde gaatt HELT FINT - med meldingen
  // «Kunne ikke laste ned fil: Object not found», som peker paa
  // lagringen mens problemet er at det aldri SKULLE ligge en fil der.
  //
  // Robert saa to slike rader for 26. og 27. august 2026 og trodde
  // dataene manglet. De var inne.
  //
  // Statusen roeres ikke her: en vellykket import skal ikke degraderes
  // av et forsoek som aldri kunne lykkes.
  // =====================================================================
  if (jobb.raa_filer.storage_sti.startsWith('klient/')) {
    await supabase
      .from('import_jobber')
      .update({
        feilmelding:
          'Denne fila ble lest i nettleseren, så den ligger ikke lagret. '
          + 'Last den opp på nytt for å behandle den igjen.',
      })
      .eq('id', jobbId)
    return
  }

  await supabase.from('import_jobber').update({ status: 'behandler' }).eq('id', jobbId)

  const nedlasting = await supabase.storage
    .from(jobb.raa_filer.storage_bucket)
    .download(jobb.raa_filer.storage_sti)
  if (nedlasting.error || !nedlasting.data) {
    await settFeil(`Kunne ikke laste ned fil: ${nedlasting.error?.message ?? 'ukjent'}`)
    return
  }
  const buffer = Buffer.from(await nedlasting.data.arrayBuffer())
  const filnavn = jobb.raa_filer.filnavn

  // Gjenkjenningen kjorer i sin EGEN try. Ligger den utenfor, og xlsx-leseren
  // kveles av en CSV, kastes det for statusen rekker aa bli satt - og jobben
  // blir staaende i «Leser fila ...» til nattjobben gjenoppretter den 20
  // minutter senere. Det skjedde med den forste stemplings-CSV-en.
  let rapporttype: Rapporttype
  let tekst: string | null = null
  try {
    // Rekkefolgen foelger hvor billig sjekken er, og hvor daarlig feilen
    // blir hvis vi tar den i feil orden. En xlsx-leser paa en PDF sier
    // «zip-fila er korrupt», som ikke hjelper noen.
    if (erPdf(buffer)) {
      tekst = await pdfTilTekst(buffer)
      rapporttype = gjenkjennStempling(tekst)
      if (rapporttype === 'ukjent') {
        await settFeil('PDF-en er ikke en Basis Export fra easy@work. Andre PDF-er kan ikke leses ennå.')
        return
      }
    } else if (erTekstfil(buffer)) {
      // CSV/tekst. easy@work eksporterer stemplingene slik, og det formatet
      // er bedre enn PDF-en: kolonner med navn, lengde i desimaltimer.
      tekst = buffer.toString('utf8')
      rapporttype = gjenkjennStempling(tekst)
      if (rapporttype === 'ukjent') {
        await settFeil('Tekst-/CSV-fila kjennes ikke igjen. Stemplinger fra easy@work leses; andre CSV-er ikke ennå.')
        return
      }
    } else {
      // BP-fila kjennes igjen av arknavnene alene. Den er 11-27 MB, og en
      // full lastArbeidsbok paa den koster over 2 GB heap - mer enn
      // funksjonen har. Begge formatene ryddes under samme rapporttype:
      // det ER samme dokument, og hvilken mal St1 sendte staar som
      // `format` paa raden. En ny enumverdi ville krevd en migrasjon for
      // en forskjell ingen leser bryr seg om.
      const erBp = await erBpFil(buffer).catch(() => false)
        || (() => { try { return erBp25Fil(buffer) } catch { return false } })()
      rapporttype = erBp ? 'st1_bp' : await gjenkjennRapporttype(buffer)
    }
  } catch (e) {
    await settFeil(`Kunne ikke lese fila: ${e instanceof Error ? e.message : String(e)}`)
    return
  }
  // Feilen her ble ignorert i lang tid, og det er grunnen til at en
  // manglende enum-verdi kunne leve uoppdaget: koeveien gikk videre med
  // rapporttype 'ukjent', mens nettleserveien kastet paa samme fil.
  const { error: typeFeil } = await supabase
    .from('import_jobber').update({ rapporttype }).eq('id', jobbId)
  if (typeFeil) {
    await settFeil(`Kunne ikke sette rapporttype «${rapporttype}»: ${typeFeil.message}`)
    return
  }

  try {
    const oppslag = await hentStasjonsoppslag(supabase)
    let res: Lagring
    let dato: string | null = null

    switch (rapporttype) {
      case 'st1_salgsstatistikk': {
        const r = await parseSalgsstatistikk(buffer)
        dato = r.dato
        res = await lagreSalgsstatistikk(supabase, retailerId, jobbId, oppslag.medNummer, r)
        break
      }
      case 'st1_salesperhour_inneute': {
        const r = await parseSalesPerHourInneUte(buffer)
        dato = r.dato ?? datoFraFilnavn(filnavn)
        if (!dato) throw new ParserFeil('Fant ingen dato i fil eller filnavn.')
        res = await lagreTimesalg(supabase, retailerId, jobbId, oppslag.medNavn, r, dato)
        break
      }
      case 'st1_cashierstats': {
        const r = await parseKassererstatistikk(buffer)
        dato = r.dato ?? datoFraFilnavn(filnavn)
        if (!dato) throw new ParserFeil('Fant ingen dato i fil eller filnavn.')
        res = await lagreKasserer(supabase, retailerId, jobbId, oppslag.medNummer, r, dato)
        break
      }
      case 'salgsgrid_varetrans': {
        const r = await parseVaretransaksjon(buffer)
        res = await lagreSvinn(supabase, retailerId, jobbId, oppslag.medNummer, r)
        break
      }
      case 'regnskap_resultat': {
        const r = await parseRegnskap(buffer)
        dato = r.periode ?? periodeFraFilnavn(filnavn)
        if (!dato) throw new ParserFeil('Fant ingen periode i fil eller filnavn.')
        const perStasjon = await parseRegnskapStasjoner(buffer)
        res = await lagreRegnskap(supabase, retailerId, jobbId, r, dato, perStasjon, oppslag.medNummer)
        // Usynlig svinn (per stasjon/produkt) — best effort, skal ikke velte importen.
        try {
          const us = await parseUsynligSvinn(buffer)
          await lagreUsynligSvinn(supabase, retailerId, jobbId, oppslag.medNummer, us, dato)
        } catch { /* fila har kanskje ikke per-stasjon-ark */ }
        // Bemanningsvarsler — også best effort.
        try {
          await varsleBemanning(supabase, retailerId, perStasjon, dato, oppslag.medNummer)
        } catch { /* varsler skal aldri velte en import */ }
        // Kaffevarsler — samme kontrakt: best effort.
        try {
          await varsleKaffe(supabase, retailerId, oppslag.medNummer, perStasjon)
        } catch { /* varsler skal aldri velte en import */ }
        break
      }
      case 'easyatwork_stempling': {
        const r = parseStempling(tekst as string)
        dato = r.fraDato
        res = await lagreStempling(supabase, jobbId, oppslag.stasjoner, r)
        break
      }
      case 'st1_bp': {
        // To maler, samme dokument. `erBp25Fil` leser bare arknavnene.
        const gammelMal = (() => { try { return erBp25Fil(buffer) } catch { return false } })()
        const r = gammelMal ? parseBp25(buffer) : await parseBp(buffer)
        dato = r.ar ? `${r.ar}-01-01` : null
        res = await lagreBp(
          supabase, retailerId, jobbId, r, oppslag.medNummer,
          gammelMal ? 'st1_bp25' : 'st1_bp26',
        )
        break
      }
      case 'st1_delingsfil': {
        const r = parseDelingsfil(buffer)
        res = await lagreDelingsfil(supabase, retailerId, jobbId, r, oppslag.stasjoner)
        break
      }
      default:
        // MELDINGA MAA SI HVA DEN SAA, ikke bare at den ikke forsto.
        //
        // «Gjenkjent som ukjent» kostet en runde fram og tilbake med
        // Robert 2026-08-31: delingsfila ble avvist, og ingen av oss
        // kunne se hvorfor uten aa ha fila i haanden. Arknavnene er det
        // gjenkjenningen faktisk leser, saa de hoerer med i svaret.
        await settFeil(
          `Gjenkjent som «${rapporttype}» – lagring for denne typen kommer senere.`
          + arkhint(buffer),
        )
        return
    }

    await supabase
      .from('import_jobber')
      .update({
        status: res.antallRader === 0 ? 'feilet' : 'parset',
        gjelder_dato: dato,
        antall_rader: res.antallRader,
        parset_tid: new Date().toISOString(),
        // MERKNADER, IKKE BARE FEIL. Feltet heter `feilmelding`, men
        // det er det eneste stedet importen kan si noe til den som
        // lastet opp - og en stille utelatelse er verre enn en synlig
        // merknad. Se `utenEan` i salgsstatistikk-parseren.
        feilmelding: [
          res.umatchet.length > 0
            ? `Ukjente stasjoner (registrer dem): ${res.umatchet.join(', ')}`
            : null,
          // SPEILBILDET AV `umatchet`. En stasjon vi kjenner som IKKE er i
          // fila - Laguneparken 26. og 27. august 2026 - lot importen
          // melde «parset» uten at noe manglet paa papiret.
          stasjonsmerknad(rapporttype, res, oppslag.stasjoner),
          res.notat ?? null,
        ].filter(Boolean).join(' · ') || null,
      })
      .eq('id', jobbId)

    // Tung AI kjøres i BAKGRUNNEN via after() — ETTER at svaret er sendt.
    // Opplastingen returnerer umiddelbart og kan aldri time ut/feile, uansett
    // hvor lenge analysen tar. Nattjobben + manuelle knapper er fallback hvis
    // bakgrunnsvinduet (maxDuration) skulle ta slutt før alt er ferdig.
    if (rapporttype === 'regnskap_resultat') {
      after(async () => {
        try { await kjorRegnskapsanalyse(supabase, retailerId) } catch { /* fallback: cron/knapp */ }
        try { await genererFokusForRetailer(supabase, retailerId) } catch { /* fallback: cron/knapp */ }
      })
    }
  } catch (e) {
    await settFeil(e instanceof ParserFeil ? e.message : `Uventet feil: ${String(e)}`)
  }
}

// Stemplingene lagres raa, en rad per stempling. Sammenslaing til vakter
// skjer i lesingen (vakter() i stempling.ts), ikke her - da kan tolkningen
// endres uten at noen ma laste opp tolv maaneder pa nytt.
//
// Stasjonen staar i Lokasjon-kolonnen, «St1 - Bones». Fila har ikke
// butikknummer, saa matchingen gaar pa navn. Det grupperes PER RAD, ikke
// per fil: kommer det en gang en samleeksport, skal ikke Laguneparkens
// timer havne pa Bones fordi den stasjonen sto oeverst.
async function lagreStempling(
  supabase: Klient,
  jobbId: string,
  stasjonsnavn: { id: string; navn: string }[],
  r: { stemplinger: import('@/lib/parsere/stempling').Stempling[] },
): Promise<Lagring> {
  const finnStasjon = lagStasjonsmatcher(stasjonsnavn)

  const perStasjon = new Map<string, typeof r.stemplinger>()
  const umatchet = new Set<string>()
  // Dubletter maa vekk FOER upserten: to like noekler i samme setning gir
  // «ON CONFLICT DO UPDATE command cannot affect row a second time».
  for (const s of utenDubletter(r.stemplinger)) {
    const id = finnStasjon(s.lokasjon)
    if (!id) { umatchet.add(s.lokasjon || 'ukjent lokasjon'); continue }
    const liste = perStasjon.get(id) ?? []
    liste.push(s)
    perStasjon.set(id, liste)
  }

  let lagret = 0
  for (const [stasjonId, liste] of perStasjon) {
    await skrivBatch(
      supabase,
      'stempling',
      liste.map((s) => ({
        stasjon_id: stasjonId,
        ansatt_nr: s.ansattNr,
        ansatt_navn: s.ansattNavn,
        dato: s.dato,
        fra_tid: s.fraTid,
        til_tid: s.tilTid,
        minutter: s.minutter,
        betalt: s.betalt,
        kilde_jobb_id: jobbId,
      })),
      'stasjon_id,ansatt_nr,dato,fra_tid',
    )
    lagret += liste.length
  }
  // Feilmeldingen skal si hva vi lette BLANT. «Ukjente stasjoner: St1 -
  // Bones» forteller ikke om stasjonen mangler eller bare heter noe annet,
  // og da blir neste steg gjetting.
  const kjente = stasjonsnavn.map((s) => s.navn).sort().join(', ')
  return {
    antallRader: lagret,
    umatchet: umatchet.size > 0
      ? [`${[...umatchet].join(', ')} (stasjoner i Sentiqa: ${kjente || 'ingen'})`]
      : [],
  }
}

// Browser-parsing: klienten parser fila lokalt (ingen server-parse-timeout) og
// sender PARSER-RESULTATET hit. Vi lagrer kun (batchet) + fører en jobb-rad.
// Ingen rå-fil i Storage (klienten har den) — sentinel-sti tilfredsstiller NOT NULL.
export async function lagreForhandsparset(
  supabase: Klient,
  retailerId: string,
  meta: { filnavn: string; sha256: string; storrelse: number },
  payload: ForhandsPayload,
): Promise<{ ok: boolean; hoppet?: boolean; melding?: string; antallRader?: number; feil?: string }> {
  const nyRaaFil = () => supabase
    .from('raa_filer')
    .insert({ retailer_id: retailerId, filnavn: meta.filnavn, storage_sti: `klient/${randomUUID()}-${meta.filnavn}`, mottakskanal: 'drop_zone', storrelse_bytes: meta.storrelse, sha256: meta.sha256 })
    .select('id').single<{ id: string }>()

  let { data: raaFil, error: filFeil } = await nyRaaFil()
  // Et duplikat er bare et duplikat hvis den forrige importen lyktes.
  // Feilet den, sto fila registrert uten data — og blokkerte sitt eget
  // nye forsøk. Se dublett.ts.
  if (filFeil?.code === '23505') {
    const svar = await vurderDublett(supabase, retailerId, meta.sha256)
    if (!svar.slippGjennom) return { ok: true, hoppet: true, melding: svar.melding }
    ;({ data: raaFil, error: filFeil } = await nyRaaFil())
  }
  if (filFeil || !raaFil) {
    return { ok: false, feil: filFeil?.message ?? 'Kunne ikke registrere fil.' }
  }
  const { data: jobb, error: jobbFeil } = await supabase
    .from('import_jobber')
    .insert({ raa_fil_id: raaFil.id, retailer_id: retailerId, rapporttype: payload.type, status: 'behandler' })
    .select('id').single<{ id: string }>()
  // Feilet dette, ville `jobb!.id` kastet en TypeError ut av server-actionen,
  // og brukeren fatt Next sin «An error occurred in the Server Components
  // render» — som ikke sier noe. Fila maa ogsaa fjernes, ellers blokkerer den
  // sitt eget nye forsok (se dublett.ts).
  if (jobbFeil || !jobb) {
    await supabase.from('raa_filer')
      .update({ slettet_tid: new Date().toISOString() }).eq('id', raaFil.id)
    return { ok: false, feil: `Kunne ikke opprette importjobb: ${jobbFeil?.message ?? 'ukjent'}` }
  }
  const jobbId = jobb.id

  const settFeil = async (m: string) => {
    await supabase.from('import_jobber').update({ status: 'feilet', feilmelding: m }).eq('id', jobbId)
    return { ok: false, feil: m }
  }
  try {
    const oppslag = await hentStasjonsoppslag(supabase)
    let res: Lagring
    let dato: string | null = null
    switch (payload.type) {
      case 'st1_salgsstatistikk':
        dato = payload.salg.dato
        res = await lagreSalgsstatistikk(supabase, retailerId, jobbId, oppslag.medNummer, payload.salg)
        break
      case 'st1_salesperhour_inneute':
        dato = payload.timesalg.dato ?? datoFraFilnavn(meta.filnavn)
        if (!dato) throw new ParserFeil('Fant ingen dato i fil eller filnavn.')
        res = await lagreTimesalg(supabase, retailerId, jobbId, oppslag.medNavn, payload.timesalg, dato)
        break
      case 'st1_cashierstats':
        dato = payload.kasserer.dato ?? datoFraFilnavn(meta.filnavn)
        if (!dato) throw new ParserFeil('Fant ingen dato i fil eller filnavn.')
        res = await lagreKasserer(supabase, retailerId, jobbId, oppslag.medNummer, payload.kasserer, dato)
        break
      case 'salgsgrid_varetrans':
        res = await lagreSvinn(supabase, retailerId, jobbId, oppslag.medNummer, payload.svinn)
        break
      case 'regnskap_resultat':
        dato = payload.regnskap.periode ?? periodeFraFilnavn(meta.filnavn)
        if (!dato) throw new ParserFeil('Fant ingen periode i fil eller filnavn.')
        res = await lagreRegnskap(supabase, retailerId, jobbId, payload.regnskap, dato, payload.stasjoner, oppslag.medNummer)
        if (payload.usynlig) { try { await lagreUsynligSvinn(supabase, retailerId, jobbId, oppslag.medNummer, payload.usynlig, dato) } catch { /* mangler per-stasjon-ark */ } }
        break
      default:
        return await settFeil('Ukjent rapporttype.')
    }
    await supabase.from('import_jobber').update({
      status: res.antallRader === 0 ? 'feilet' : 'parset',
      gjelder_dato: dato, antall_rader: res.antallRader, parset_tid: new Date().toISOString(),
      feilmelding: [
        res.umatchet.length > 0
          ? `Ukjente stasjoner (registrer dem): ${res.umatchet.join(', ')}`
          : null,
        stasjonsmerknad(payload.type, res, oppslag.stasjoner),
        res.notat ?? null,
      ].filter(Boolean).join(' · ') || null,
    }).eq('id', jobbId)
    if (payload.type === 'regnskap_resultat') {
      after(async () => {
        try { await kjorRegnskapsanalyse(supabase, retailerId) } catch { /* fallback: cron/knapp */ }
        try { await genererFokusForRetailer(supabase, retailerId) } catch { /* fallback */ }
      })
    }
    if (res.antallRader === 0) return { ok: false, feil: 'Ingen rader lagret — sjekk at stasjonene er registrert.' }
    return { ok: true, antallRader: res.antallRader }
  } catch (e) {
    return await settFeil(e instanceof ParserFeil ? e.message : `Uventet feil: ${String(e)}`)
  }
}

// --- Per-type lagring ---

async function lagreUsynligSvinn(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  medNummer: Map<string, string>,
  r: Awaited<ReturnType<typeof parseUsynligSvinn>>,
  periode: string,
): Promise<void> {
  await supabase.from('regnskap_usynlig_svinn').delete().eq('retailer_id', retailerId).eq('periode', periode)
  const rader: Record<string, unknown>[] = []
  for (const st of r.stasjoner) {
    const stasjonId = medNummer.get(st.butikknummer)
    if (!stasjonId) continue
    for (const p of st.produkter) {
      if (Math.abs(p.usynligKr) < 1000 && Math.abs(p.kast) < 1000) continue // kun meningsfulle utslag
      rader.push({ retailer_id: retailerId, stasjon_id: stasjonId, periode, kode: p.kode, navn: p.navn, salg: p.salg, brf_pst: p.brfPst, kast: p.kast, usynlig_kr: p.usynligKr, usynlig_pst: p.usynligPst, kilde_jobb_id: jobbId })
    }
  }
  if (rader.length > 0) await skrivBatch(supabase, 'regnskap_usynlig_svinn', rader)
}

async function lagreSalgsstatistikk(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  medNummer: Map<string, string>,
  r: Awaited<ReturnType<typeof parseSalgsstatistikk>>,
): Promise<Lagring> {
  const umatchet: string[] = []
  const rader: Record<string, unknown>[] = []
  for (const st of r.stasjoner) {
    const stasjonId = medNummer.get(st.butikknummer)
    if (!stasjonId) { umatchet.push(`${st.butikknummer} (${st.navn})`); continue }
    for (const l of st.linjer) {
      rader.push({
        retailer_id: retailerId, stasjon_id: stasjonId, dato: r.dato,
        ean: l.ean, varenr: l.varenr, varenavn: l.varenavn,
        avdeling_kode: l.avdelingKode, avdeling_navn: l.avdelingNavn,
        vareomrade_kode: l.vareomradeKode, vareomrade_navn: l.vareomradeNavn,
        varegruppe_kode: l.varegruppeKode, varegruppe_navn: l.varegruppeNavn,
        antall: l.antallTotalt, antall_tilbud: l.antallTilbud,
        omsetning_eks_mva: l.omsetningEksMva, bto_fortjeneste_kr: l.btoFortjenesteKr,
        bto_fortjeneste_pct: l.btoFortjenestePct, kilde_jobb_id: jobbId,
      })
    }
  }
  if (rader.length > 0) await skrivBatch(supabase, 'daglig_salg', rader, 'retailer_id,stasjon_id,dato,ean')

  // Er dagen rimelig? Se `varsleOmUrimeligDag` - den svarer paa noe
  // verken statusen, dekningen eller dublettsjekken kan svare paa.
  const berorte = [...new Set(
    r.stasjoner.map((st) => medNummer.get(st.butikknummer)).filter((x): x is string => Boolean(x)),
  )]
  for (const stasjonId of berorte) {
    await forkastUkecache(supabase, stasjonId, r.dato)
    await varsleOmUrimeligDag(supabase, retailerId, stasjonId, r.dato)
  }

  // EN UTELATELSE SKAL SES. Linjer uten EAN kan ikke lagres - se
  // `utenEan` i parseren - men den som lastet opp skal faa vite at de
  // fantes. 70 kr paa Lone i august 2026 er ubetydelig; blir tallet
  // stort, er det noe annet enn en rar enkeltlinje.
  const notat = r.utenEan.antall > 0
    ? `${r.utenEan.antall} linje${r.utenEan.antall === 1 ? '' : 'r'} uten EAN `
      + `ble ikke lagret (${Math.round(r.utenEan.kroner)} kr)`
    : null

  return { antallRader: rader.length, umatchet, notat, truffet: rader.map((r) => r.stasjon_id as string) }
}

// =====================================================================
// EN CACHE UTEN INVALIDERING BLIR STILLE FEIL
//
// `uke_rapport` skrives en gang per (stasjon, uke) og leses med
// `if (c) bruk cachen`. Den regner aldri om. Da 25. august 2026 ble
// importert paa nytt for Laguneparken, ble uka 24.-30. august staaende
// med de gamle tallene - og AI-sammendraget var skrevet paa grunnlag av
// dem.
//
// Vi ryddet det opp for haand en gang. Naa gjoer importen det selv.
//
// To uker, ikke en: ukerapporten sammenligner mot `mandag - 364`, saa
// en endret dag i fjor gjoer AARETS uke like feil gjennom
// `omsetning_ifjor`. Se ukecache.ts.
//
// Sletting og ikke oppdatering: raden inneholder ogsaa `avdelinger`,
// `brutto`, fjoraarstallene og AI-teksten. AA rette bare omsetningen
// ville gitt en rad der ett tall stemmer og resten ikke gjoer.
// =====================================================================
async function forkastUkecache(
  supabase: Klient,
  stasjonId: string,
  dato: string,
): Promise<void> {
  try {
    await supabase
      .from('uke_rapport')
      .delete()
      .eq('stasjon_id', stasjonId)
      .in('uke_mandag', berorteUker(dato))
  } catch {
    // Stille, av samme grunn som rimelighetssjekken: en vellykket import
    // skal ikke bli staaende som feilet fordi opprydningen snublet. Blir
    // cachen staaende, er den feil - men dataene er riktige, og neste
    // import av samme uke rydder den.
  }
}

// =====================================================================
// «DAGEN FINNES» ER IKKE DET SAMME SOM «DAGEN ER RIKTIG»
//
// 25. august 2026, Laguneparken: 8 rader, 676 kr, status «parset».
// Nabotirsdagene laa paa 37-39 000. Alt saa riktig ut - riktig stasjon,
// riktig dato, groenn import - og 44 578 kr manglet i rapportene.
//
// Denne sjekken blokkerer ikke. En dag KAN vaere halvert av ekte
// grunner: stengt for oppussing, stroembrudd, en helligdag vi ikke
// kjenner. Da skal tallet inn, bare med et flagg. AA avvise ekte data
// fordi de er uvanlige ville vaert en verre feil enn den vi retter.
//
// Den er heller ikke i veien for importen: feiler den, sluker vi det.
// En import som lykkes skal ikke bli staaende som feilet fordi VAKTEN
// snublet - det ville vaert samme form som «Behandle»-knappen som
// skriver «feilet» over en vellykket jobb.
// =====================================================================
async function varsleOmUrimeligDag(
  supabase: Klient,
  retailerId: string,
  stasjonId: string,
  dato: string,
): Promise<void> {
  try {
    const fra = new Date(`${dato}T12:00:00Z`)
    fra.setUTCDate(fra.getUTCDate() - (UKER_TILBAKE + 1) * 7)

    const { data } = await supabase
      .from('v_butikksalg_dag')
      .select('dato, kroner')
      .eq('stasjon_id', stasjonId)
      .gte('dato', fra.toISOString().slice(0, 10))
      .lte('dato', dato)
      .order('dato', { ascending: false })
      .overrideTypes<{ dato: string; kroner: number }[]>()

    const dager = (data ?? []).map((d) => ({ dato: d.dato, kroner: Number(d.kroner) }))
    const iDagRad = dager.find((d) => d.dato === dato)
    if (!iDagRad) return

    const funn = vurderDag(iDagRad, dager.filter((d) => d.dato !== dato))
    if (!funn) return

    const { data: st } = await supabase
      .from('stasjoner').select('navn').eq('id', stasjonId)
      .maybeSingle<{ navn: string }>()

    await opprettVarsel(supabase, {
      retailer_id: retailerId,
      stasjon_id: stasjonId,
      type: 'import_avvik',
      tittel: `${st?.navn ?? 'Stasjonen'}: uvanlig salgsdag ${dato}`,
      tekst: funn.tekst,
      lenke: '/dekning',
    })
  } catch {
    // Med vilje stille. Se blokkkommentaren over.
  }
}

async function lagreTimesalg(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  medNavn: Map<string, string>,
  r: Awaited<ReturnType<typeof parseSalesPerHourInneUte>>,
  dato: string,
): Promise<Lagring> {
  const umatchet: string[] = []
  const rader: Record<string, unknown>[] = []
  for (const st of r.stasjoner) {
    const stasjonId = medNavn.get(st.navn.trim().toLowerCase())
    if (!stasjonId) { umatchet.push(st.navn); continue }
    for (const t of st.timer) {
      rader.push({
        retailer_id: retailerId, stasjon_id: stasjonId, dato, time: t.time,
        salg: t.salg, kostpris: t.kostpris, mva: t.mva,
        antall_varer: t.antallVarer, antall_kunder: t.antallKunder,
        inne_kunder: t.inneKunder ?? null, ute_kunder: t.uteKunder ?? null,
        kilde_jobb_id: jobbId,
      })
    }
  }
  if (rader.length > 0) await skrivBatch(supabase, 'timesalg', rader, 'retailer_id,stasjon_id,dato,time')
  return { antallRader: rader.length, umatchet, truffet: rader.map((r) => r.stasjon_id as string) }
}

async function lagreKasserer(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  medNummer: Map<string, string>,
  r: Awaited<ReturnType<typeof parseKassererstatistikk>>,
  dato: string,
): Promise<Lagring> {
  const umatchet: string[] = []
  const rader: Record<string, unknown>[] = []
  for (const st of r.stasjoner) {
    const stasjonId = medNummer.get(st.butikknummer)
    if (!stasjonId) { umatchet.push(`${st.butikknummer} (${st.navn})`); continue }
    for (const k of st.kasserere) {
      rader.push({
        retailer_id: retailerId, stasjon_id: stasjonId, dato,
        kasserer_nr: k.nr, kasserer_navn: k.navn,
        omsetning_ink_mva: k.omsetningInkMva, bonger: k.bonger,
        retur_antall: k.returAntall, retur_belop: k.returBelop,
        makulerte_antall: k.makulerteAntall, makulerte_belop: k.makulerteBelop,
        slettede_antall: k.slettedeAntall, slettede_belop: k.slettedeBelop, kilde_jobb_id: jobbId,
      })
    }
  }
  if (rader.length > 0) await skrivBatch(supabase, 'kassererstatistikk', rader, 'retailer_id,stasjon_id,dato,kasserer_nr')
  return { antallRader: rader.length, umatchet, truffet: rader.map((r) => r.stasjon_id as string) }
}

async function lagreSvinn(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  medNummer: Map<string, string>,
  r: Awaited<ReturnType<typeof parseVaretransaksjon>>,
): Promise<Lagring> {
  const umatchet: string[] = []
  const rader: Record<string, unknown>[] = []
  const matchedeIder = new Set<string>()
  const datoer = new Set<string>()

  for (const st of r.stasjoner) {
    const stasjonId = medNummer.get(st.butikknummer)
    if (!stasjonId) { umatchet.push(`${st.butikknummer} (${st.navn})`); continue }
    matchedeIder.add(stasjonId)
    for (const t of st.transaksjoner) {
      if (t.dato) datoer.add(t.dato)
      rader.push({
        retailer_id: retailerId, stasjon_id: stasjonId, dato: t.dato,
        ean: t.ean, varenavn: t.varenavn, varenummer: t.varenummer,
        operatornr: t.operatornr, transaksjonstype: t.transaksjonstype,
        arsakskode: t.arsakskode, nettopris: t.nettopris, antall: t.antall,
        nettopris_total: t.nettoprisTotal, kilde_jobb_id: jobbId,
      })
    }
  }

  if (matchedeIder.size > 0 && datoer.size > 0) {
    await supabase
      .from('synlig_svinn')
      .delete()
      .in('stasjon_id', [...matchedeIder])
      .in('dato', [...datoer])
  }
  if (rader.length > 0) await skrivBatch(supabase, 'synlig_svinn', rader)
  return { antallRader: rader.length, umatchet }
}

// ---------------------------------------------------------------------
// Forretningsplanen (BP) — årsbudsjettet fra St1.
//
// Fila dekker hele kjeden; stasjoner som ikke tilhører denne retaileren
// hoppes over uten å regnes som feil. Det er normalt, ikke et avvik.
//
// Tre tabeller skrives:
//   bemanning_aar       årsramme + satser        (retailer_admin)
//   bemanning_budsjett  brutto/lønn per måned    (retailer_admin)
//   bemanning_maned     DISPONIBLE timer         (butikksjef ser denne)
//
// Sykefraværsreserven settes ikke av hånd: den regnes ut av stasjonens egen
// nettosykelønn (505 + 506 refusjon) mot samlet lønn siste tolv måneder, med
// clusterets poolede sats som gulv. En stasjon som ikke har hatt fravær ennå
// har vært heldig, ikke frisk — 0 % der er en garantert sprekk. Er reserven
// satt manuelt fra før, beholdes den.
// ---------------------------------------------------------------------

/**
 * Kjedens sykefraværssats, fra regnskapet, siste tolv måneder.
 *
 * ETT TALL FOR ALLE STASJONER — se `sykereserve.ts` for hvorfor. Kort:
 * fradraget er eierens margin, og en margin skal ikke variere med hvem
 * som er syk. Før dette var satsen `max(egen, snitt)`, som ga stasjonen
 * med høyest fravær både færre hender og mindre ramme.
 */
async function sykefravaerssats(
  supabase: Klient,
  retailerId: string,
): Promise<number> {
  const fra = new Date()
  fra.setUTCFullYear(fra.getUTCFullYear() - 1)
  const { data } = await supabase
    .from('regnskapslinjer')
    .select('stasjon_id, kode, regnskap')
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)
    .not('stasjon_id', 'is', null)
    .gte('periode', fra.toISOString().slice(0, 10))
    .in('kode', [...LONNSKONTI, ...SYKEKONTI])

  return kjedensSykesats((data ?? []) as Regnskapsrad[])
}

async function lagreBp(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  r: Awaited<ReturnType<typeof parseBp>>,
  medNummer: Map<string, string>,
  format: 'st1_bp25' | 'st1_bp26',
): Promise<Lagring> {
  const ar = r.ar
  if (!ar) throw new ParserFeil('BP: fant ingen årstall i fila.')

  const { data: ret } = await supabase
    .from('retailers')
    .select('bemanning_sikkerhet_pst')
    .eq('id', retailerId)
    .single()
  const sikkerhetPst = (ret as { bemanning_sikkerhet_pst: number } | null)?.bemanning_sikkerhet_pst ?? 3

  const sykesats = await sykefravaerssats(supabase, retailerId)

  const mine = r.stasjoner
    .map((s) => ({ s, stasjonId: medNummer.get(s.butikknummer) }))
    .filter((x): x is { s: (typeof r.stasjoner)[number]; stasjonId: string } => Boolean(x.stasjonId))
  if (mine.length === 0) {
    throw new ParserFeil(
      `BP: ingen av de ${r.stasjoner.length} stasjonene i fila tilhører denne kjeden.`,
    )
  }

  // Låste måneder: en måned som allerede er avlagt bærer sitt eget budsjett i
  // regnskapsrapporten, og det er det kjeden måler mot. En senere revisjon av
  // BP-en kan ikke endre en lukket måned — Dale ble replanlagt ned i den
  // reviderte BP-en, men januar og februar sto igjen med de opprinnelige
  // tallene. For slike måneder brukes regnskapets brutto i fordelingen, og vi
  // skriver ingen bp_*-linjer.
  const { data: avlagt } = await supabase
    .from('regnskapslinjer')
    .select('stasjon_id, periode, kode, budsjett')
    .eq('retailer_id', retailerId)
    .eq('seksjon', 'bruttofortjeneste')
    .is('slettet_tid', null)
    .not('stasjon_id', 'is', null)
    .gte('periode', `${ar}-01-01`)
    .lte('periode', `${ar}-12-01`)
  const laast = new Map<string, number>()
  for (const rad of (avlagt ?? []) as {
    stasjon_id: string; periode: string; kode: string | null; budsjett: number | null
  }[]) {
    if ((rad.kode ?? '') === '40') continue // CR-rollup, ville dublert kategoriene
    const maned = Number.parseInt(rad.periode.slice(5, 7), 10)
    const n = `${rad.stasjon_id}|${maned}`
    laast.set(n, (laast.get(n) ?? 0) + (rad.budsjett ?? 0))
  }

  // Bevar reserve/sikkerhet som er satt manuelt fra før.
  const { data: eksisterende } = await supabase
    .from('bemanning_aar')
    .select('stasjon_id, reserve_pst, sikkerhet_pst, fast_arsverk_timer')
    .eq('ar', ar)
    .in('stasjon_id', mine.map((m) => m.stasjonId))
  const fra_for = new Map(
    ((eksisterende ?? []) as {
      stasjon_id: string; reserve_pst: number | null
      sikkerhet_pst: number | null; fast_arsverk_timer: number
    }[]).map((e) => [e.stasjon_id, e]),
  )

  const aarRader: Record<string, unknown>[] = []
  const budsjettRader: Record<string, unknown>[] = []
  const manedRader: Record<string, unknown>[] = []
  const bpLinjer: Record<string, unknown>[] = []
  // MAANEDENE SOM IKKE FIKK BP-LINJER. Aa hoppe over en avlagt maaned er
  // riktig - regnskapet baerer sitt eget budsjett - men det skjedde i
  // stillhet, og det er grunnen til at BP maa lastes foer regnskapet.
  const hoppede: { stasjon: string; maaneder: number[] }[] = []

  for (const { s, stasjonId } of mine) {
    const gammel = fra_for.get(stasjonId)
    // KJEDENS SATS, ALLTID. Ikke `gammel?.reserve_pst`: den bar de
    // gamle per-stasjon-verdiene, og ville frosset dem for alltid.
    const reservePst = sykesats
    const stasjonSikkerhet = gammel?.sikkerhet_pst ?? sikkerhetPst

    // EN BP UTEN TIMEBUDSJETT SKAL IKKE ROERE BEMANNINGSPLANLEGGEREN.
    //
    // Den gamle St1-malen har ikke timer i det hele tatt - og heller
    // ikke alle filer i det nye formatet har dem (Dales BP for 2025
    // mangler `Timebudsjett Grunnlagsfil`). `?? 0`
    // sto her og gjorde «formatet sier det ikke» om til «null timer» -
    // og en import av en gammel BP ville da overskrevet `bemanning_aar`
    // med 0 og tatt timerammen for det aaret med seg. Ingen feilmelding,
    // bare en planlegger som plutselig ikke har timer aa fordele.
    //
    // Dokumentet (`bp_aar`/`bp_linje`) lagres uansett - det er hele
    // poenget med aa kunne laste opp fjoraarets BP. Det er BARE
    // bemanningstabellene som hopper over.
    // EN BP UTEN TIMEBUDSJETT SKAL IKKE ROERE BEMANNINGSPLANLEGGEREN.
    //
    // Den gamle St1-malen har ikke timer i det hele tatt - og heller
    // ikke alle filer i det nye formatet har dem (Dales BP for 2025
    // mangler `Timebudsjett Grunnlagsfil`). `?? 0`
    // sto her og gjorde "formatet sier det ikke" om til "null timer" -
    // og en import av en gammel BP ville da overskrevet `bemanning_aar`
    // med 0 og tatt timerammen for det aaret med seg. Ingen feilmelding,
    // bare en planlegger som plutselig ikke har timer aa fordele.
    //
    // BARE bemanningsradene staar over. Budsjettlinjene til
    // regnskapslinjer og dokumentet i `bp_aar`/`bp_linje` skrives
    // uansett - det er hele poenget med aa kunne laste fjoraarets BP.
    const harTimebudsjett = s.timerAar !== null
    const timerAar = s.timerAar ?? 0

    if (harTimebudsjett) aarRader.push({
      stasjon_id: stasjonId, ar,
      timer_aar: timerAar,
      fast_arsverk_timer: gammel?.fast_arsverk_timer ?? 0,
      reserve_pst: reservePst,
      sikkerhet_pst: stasjonSikkerhet,
      kilde: `import ${jobbId}`,
      oppdatert_tid: new Date().toISOString(),
    })

    // Avlagt måned slår BP-en; åpne og framtidige måneder tar BP-tallet.
    const brutto = s.maaneder.map((m) => laast.get(`${stasjonId}|${m.maned}`) ?? m.bruttoKr)
    // EN IMPLEMENTASJON, TO KALLSTEDER. Delingsfila fordeler det samme
    // fra `bp_linje` (`fordelFraDokument`). Sto regnestykket begge
    // steder, kunne de skli fra hverandre uten at noe sa fra.
    const rammer = maanedsrammer(timerAar, brutto, {
      reservePst,
      sikkerhetPst: stasjonSikkerhet,
    })

    const minehoppede: number[] = []
    for (const m of s.maaneder) {
      const erLaast = laast.has(`${stasjonId}|${m.maned}`)
      if (erLaast) minehoppede.push(m.maned)
      const ramme = rammer[m.maned - 1]
      if (harTimebudsjett) budsjettRader.push({
        stasjon_id: stasjonId, ar, maned: m.maned,
        timer: ramme.timer,
        lonn_kr: m.timelonnKr,
        brutto_bp_kr: ramme.brutto_bp_kr,
        reserve_pst: reservePst,
        oppdatert_tid: new Date().toISOString(),
      })
      if (harTimebudsjett) manedRader.push({
        stasjon_id: stasjonId, ar, maned: m.maned,
        disponible_timer: ramme.disponible_timer,
        beregnet_tid: new Date().toISOString(),
      })

      // BP-en er et fullt månedsbudsjett per stasjon, ikke bare timer og
      // brutto. Månedene som ennå ikke er avlagt finnes ikke i
      // regnskapslinjer fra noen annen kilde, så de legges inn herfra med
      // egne seksjonsnavn (bp_*) — da kan de slettes presist ved ny
      // innlasting uten å røre regnskapets egne linjer.
      if (erLaast) continue // regnskapet bærer allerede budsjettet for denne måneden
      const periode = `${ar}-${String(m.maned).padStart(2, '0')}-01`
      const bpLinje = (seksjon: string, kode: string, post: string, budsjett: number) => ({
        retailer_id: retailerId, stasjon_id: stasjonId, periode, seksjon, kode, post,
        sortering: null, regnskap: 0, budsjett, avvik: 0, index_pct: 0,
        regnskap_hittil: 0, budsjett_hittil: 0, kilde_jobb_id: jobbId,
      })
      for (const k of m.kategorier) {
        bpLinjer.push(bpLinje('bp_omsetning', k.kode, k.post, k.salgKr))
        bpLinjer.push(bpLinje('bp_bruttofortjeneste', k.kode, k.post, k.salgKr - k.varekostKr))
      }
      for (const k of m.konti) {
        bpLinjer.push(bpLinje('bp_kostnad', k.kode, k.post, k.belopKr))
      }
    }
    if (minehoppede.length > 0) {
      // Butikknummeret alene: `BpStasjon` baerer ikke navn, og det er
      // uansett nummeret som staar i BP-fila.
      hoppede.push({ stasjon: s.butikknummer, maaneder: minehoppede })
    }
  }

  // -------------------------------------------------------------------
  // BP-EN SOM SITT EGET DOKUMENT (0155)
  // -------------------------------------------------------------------
  // Dette er hva fila SA, uroert av maanedslaasen under. De to svarer paa
  // hvert sitt spoersmaal: `bp_*`-linjene i regnskapslinjer sier hva denne
  // maaneden maales mot, `bp_aar`/`bp_linje` sier hva St1 lovet for aaret.
  //
  // Uten dette finnes ikke et avsluttet aar som BP i det hele tatt -
  // laasen hopper over hver avlagt maaned, og for 2025 er det alle tolv.
  // Da er det ingenting aa sammenligne den nye BP-en MOT.
  //
  // Skrives FOERST, og med egne feilsvar: er dokumentet lagret, kan
  // resten kjoeres om igjen uten aa miste det.
  const naa = new Date().toISOString()
  const bpAarRader = mine.map(({ s, stasjonId }) => ({
    retailer_id: retailerId,
    stasjon_id: stasjonId,
    ar,
    // null, ikke 0: BP25-malen HAR ikke timebudsjett, og «ingen timer»
    // er noe helt annet enn «formatet sier det ikke».
    timer_aar: s.timerAar,
    format,
    kilde_jobb_id: jobbId,
    oppdatert_tid: naa,
  }))
  await skrivBatch(supabase, 'bp_aar', bpAarRader, 'stasjon_id,ar')

  // Id-ene maa leses tilbake: `bp_linje` peker paa aargangen, ikke paa
  // (stasjon, aar), slik at `retailer_id` ikke kan drive fra den.
  const { data: aargangene } = await supabase
    .from('bp_aar')
    .select('id, stasjon_id')
    .eq('ar', ar)
    .in('stasjon_id', mine.map((m) => m.stasjonId))
  const bpAarId = new Map(
    ((aargangene ?? []) as { id: string; stasjon_id: string }[])
      .map((x) => [x.stasjon_id, x.id]),
  )
  // En skriving som ikke traff noe skal si fra. Uten dette ville
  // linjene bare uteblitt, og importen meldt seg ferdig: dokumentet
  // hadde manglet, og sida ville sagt «ingen BP for dette aaret».
  if (bpAarId.size === 0) {
    throw new ParserFeil(
      `BP: skrev ${bpAarRader.length} aargangsrader, men fant ingen igjen. `
      + 'Er 0155 kjoert mot denne basen?',
    )
  }

  // Radbyggingen ligger i `bpLinjer` og ikke her, fordi den maa vaere ren:
  // `hent.test.ts` beviser at fila og basen gir samme tall, og den maa
  // bruke SAMME radbygging som importen. Skrives den av i testen, beviser
  // testen bare at kopien stemmer med seg selv.
  const dokumentLinjer: Record<string, unknown>[] = []
  for (const { s, stasjonId } of mine) {
    const aargangId = bpAarId.get(stasjonId)
    if (!aargangId) continue
    for (const l of byggLinjer(s)) {
      dokumentLinjer.push({ bp_aar_id: aargangId, retailer_id: retailerId, ...l })
    }
  }
  // Slettes foerst: en revidert BP kan ha FAERRE linjer enn den forrige,
  // og en ren upsert ville latt de gamle bli staaende. Cascade fra
  // `bp_aar` tar dem ikke - aargangen ble oppdatert, ikke slettet.
  await supabase
    .from('bp_linje')
    .delete()
    .in('bp_aar_id', [...bpAarId.values()])
  await skrivBatch(supabase, 'bp_linje', dokumentLinjer)

  await skrivBatch(supabase, 'bemanning_aar', aarRader, 'stasjon_id,ar')
  await skrivBatch(supabase, 'bemanning_budsjett', budsjettRader, 'stasjon_id,ar,maned')
  await skrivBatch(supabase, 'bemanning_maned', manedRader, 'stasjon_id,ar,maned')

  // regnskapslinjer har ingen unik nøkkel, så budsjettlinjene kan ikke
  // upsertes. De slettes på seksjonsnavn + år først — det treffer bare BP-ens
  // egne rader, aldri regnskapets. Merk at regnskapsimporten sletter ALT for
  // sin periode; det er riktig, for da bærer den avlagte måneden sitt eget
  // budsjett og BP-raden er overflødig.
  await supabase
    .from('regnskapslinjer')
    .delete()
    .eq('retailer_id', retailerId)
    .in('seksjon', ['bp_omsetning', 'bp_bruttofortjeneste', 'bp_kostnad'])
    .gte('periode', `${ar}-01-01`)
    .lte('periode', `${ar}-12-01`)
  await skrivBatch(supabase, 'regnskapslinjer', bpLinjer)

  return {
    antallRader:
      aarRader.length + budsjettRader.length + manedRader.length
      + bpLinjer.length + bpAarRader.length + dokumentLinjer.length,
    umatchet: [],
    // EN STILLE UTELATELSE ER VERRE ENN EN SYNLIG MERKNAD. Samme
    // mekanisme som `utenEan` og stasjonsdekningen bruker.
    notat: hoppetNotat(hoppede, Math.max(0, ...mine.map(({ s: st }) => st.maaneder.length))),
  }
}

// ---------------------------------------------------------------------
// DELINGSFILA: TIMEBUDSJETTET SOM IKKE STAAR I BP-EN
// ---------------------------------------------------------------------
// Den gamle St1-malen har ikke timer. Delingsfila oppgir dem, og de
// skrives inn paa den BP-aargangen de hoerer til.
//
// TRE TING SOM MAA STEMME, OG ALLE TRE SIER FRA NAAR DE IKKE GJOER DET:
//
//   navnene    "SHELL LAGUNEPARKEN" mot "St1 Laguneparken" - koblingen
//              er entydig eller den finnes ikke (koblePaaNavn)
//   aaret      fila sier det ikke; det finnes ved aa kjenne igjen
//              budsjettert matomsetning (finnAaret)
//   aargangen  BP-en for det aaret maa vaere lastet foerst, ellers er
//              det ingen rad aa skrive timene paa
/**
 * Arknavnene, til feilmeldinger.
 *
 * Gjenkjenningen leser nettopp disse, saa naar den ikke kjenner igjen en
 * fil, er det de som forteller hvorfor. Kaster den - fila er ikke en
 * xlsx - sier vi det i stedet, som er et like nyttig svar.
 */
function arkhint(buffer: Buffer): string {
  try {
    const navn = arknavn(buffer)
    return navn.length
      ? ` Arkene i fila: ${navn.join(', ')}.`
      : ` Fila har ingen ark (${buffer.length} byte).`
  } catch (e) {
    // GRUNNEN, IKKE BARE AT DET GIKK GALT. `gjenkjennRapporttype` svelger
    // denne feilen med vilje - den skal falle tilbake paa den gamle veien
    // - men da er den borte, og en fil som avvises paa serveren og ikke
    // lokalt har ingen spor aa foelge. Her er det siste stedet den finnes.
    return ` Fila lot seg ikke aapne som xlsx: ${e instanceof Error ? e.message : String(e)}`
      + ` (${buffer.length} byte).`
  }
}

async function lagreDelingsfil(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  r: ReturnType<typeof parseDelingsfil>,
  stasjoner: { id: string; navn: string; butikknummer: string }[],
): Promise<Lagring> {
  // NAVNET ER IKKE NØKKELEN — BELØPET ER.
  //
  // Stasjonene byttet fra Shell til St1 mot slutten av 2025, så
  // 2025-fila sier «SHELL LAGUNEPARKEN» mens basen sier «St1
  // Laguneparken». `finnAaret` kobler på budsjettert matomsetning, som er
  // BP-ens Mat på krona og ikke endrer seg når skiltet gjør det.
  //
  // Navnekoblingen sendes med som KRYSSJEKK: peker de to hver sin vei, er
  // ett av dem feil, og da skrives ingenting.
  // AARET FINNES I BEGGE ARKENE, OG 2026-FILA HAR BARE DET ENE.
  //
  // Timer-arkets `Budsjettert matomsetning` og Mat-arkets `Budsjettert
  // salg` er samme stoerrelse - Laguneparken 4 651 908 i begge. Uten
  // dette leste hele importen aaret av `r.stasjoner`, som er TOM naar
  // fila ikke har «Timer», og svarte «Ingen av stasjonene i delingsfila
  // () kunne kobles» - med tom parentes, fordi det ikke var noen aa
  // nevne.
  //
  // Bare avdelingsraden: den ER Mat-totalen, og det er den som svarer til
  // Timer-arkets tall. Undergruppene ville lagt seks smaa avvik inn i et
  // snitt som skal treffe én aargang.
  const aarsgrunnlag = aarsgrunnlagFra(r)

  const paaNavn = koblePaaNavn(stasjoner, aarsgrunnlag.map((s) => s.butikknavn))
  const matbudsjett = await matbudsjettPerAar(supabase)
  const svar = finnAaret(aarsgrunnlag, paaNavn.kobling, matbudsjett)
  if (svar.ar === null) throw new ParserFeil(`Delingsfil: ${svar.grunn}`)
  const { ar, kobling } = svar

  // TIMENE SKRIVES BARE DER AARGANGEN ALT FINNES. `bp_aar` er BP-ens eget
  // dokument; en delingsfil uten en BP aa henge paa er en fil vi ikke kan
  // plassere, og en tom rad ville vaert en oppfinnelse.
  //
  // OG SAA FORDELES DE. En `timer_aar` alene gir en aarsramme uten
  // maaneder - den ser komplett ut og er det ikke, og planleggeren leser
  // `bemanning_maned`, ikke `bp_aar`.
  //
  // Fordelingen sto lenge igjen som en bevisst grense: for Kelsar er den
  // uten betydning (2025 er avsluttet, 2026 er BP26 og baerer timene
  // selv). En kjede med den GAMLE malen for INNEVAERENDE aar sto derimot
  // uten timer i planleggeren. `fordelFraDokument` under lukker det.
  const { data: aargangene, error: les } = await supabase
    .from('bp_aar').select('id, stasjon_id').eq('ar', ar)
  if (les) throw new ParserFeil(`Delingsfil: kunne ikke lese BP ${ar}: ${les.message}`)
  const radFor = new Map(
    ((aargangene ?? []) as { id: string; stasjon_id: string }[])
      .map((a) => [a.stasjon_id, a.id]),
  )

  const naa = new Date().toISOString()
  let skrevet = 0
  const utenAargang: string[] = []
  // Stasjonene timene faktisk ble skrevet paa - de og bare de skal fordeles.
  const rortAargang = new Set<string>()
  for (const s of r.stasjoner) {
    const stasjonId = kobling.get(s.butikknavn.trim().toLowerCase())
    if (!stasjonId) continue
    const radId = radFor.get(stasjonId)
    if (!radId) { utenAargang.push(s.butikknavn); continue }
    const { error } = await supabase
      .from('bp_aar')
      .update({ timer_aar: s.timebudsjett, oppdatert_tid: naa, kilde_jobb_id: jobbId })
      .eq('id', radId)
    if (error) throw new ParserFeil(`Delingsfil: kunne ikke skrive timer: ${error.message}`)
    rortAargang.add(stasjonId)
    skrevet++
  }

  // BARE NAAR DET FAKTISK VAR TIMER AA SKRIVE.
  //
  // 2026-fila har ingen «Timer», og da er `skrevet` null uten at noe er
  // galt - kastbudsjettet under er hele leveransen. Ubetinget kastet
  // denne fila for aaret vi driver i, ETTER at aaret var funnet.
  if (skrevet === 0 && r.stasjoner.length > 0) {
    throw new ParserFeil(
      `Delingsfil: fant BP ${ar}, men ingen av stasjonene hadde en aargang aa skrive timene paa.`,
    )
  }
  // BARE DET SOM ER NOE AA GJOERE NOE MED.
  //
  // `ukoblet` er stasjoner i fila som ikke er vaare - St1 sender ofte hele
  // klyngen, og det er helt normalt. Meldinga «Ukjente stasjoner
  // (registrer dem)» ba Robert registrere Bones og Varden, som han alt
  // eier. Et varsel om noe som ikke er galt laerer folk aa se bort fra
  // varsler.
  //
  // `utenAargang` er derimot handlingsdyktig: stasjonen ER vaar, men det
  // finnes ingen BP for det aaret aa skrive timene paa.
  const fordelt = await fordelFraDokument(supabase, retailerId, jobbId, ar, [...rortAargang])
  const kast = await lagreKastbudsjett(supabase, retailerId, jobbId, ar, r.kastbudsjett, kobling)
  return { antallRader: skrevet + fordelt + kast, umatchet: utenAargang }
}

// ---------------------------------------------------------------------
// KASTBUDSJETTET PER UNDERGRUPPE
//
// St1 setter et kastbudsjett per vareomraade under 120 MAT. Tallene laa i
// delingsfila hele tiden; parseren leste bare «Timer»-arket.
//
// SAMME AARSKOBLING SOM TIMENE. Fila sier ikke hvilket aar den gjelder -
// `finnAaret` har alt avgjort det ved aa matche budsjettert matomsetning
// mot BP-en. Aa gjette her ville lagt budsjettet paa feil aar, og et
// kastkrav paa feil aar er verre enn ingen.
//
// SKRIVES OGSAA UTEN BP-AARGANG. Timene maa henge paa `bp_aar`; det maa
// ikke kastbudsjettet - det er sitt eget dokument. En stasjon uten BP26
// skal likevel kunne se hva den har lov til aa kaste.
// ---------------------------------------------------------------------
async function lagreKastbudsjett(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  ar: number,
  rader: Kastbudsjett[],
  kobling: Map<string, string>,
): Promise<number> {
  if (rader.length === 0) return 0
  const naa = new Date().toISOString()
  const inn = []
  for (const k of rader) {
    const stasjonId = kobling.get(k.butikknavn.trim().toLowerCase())
    // Stasjoner i fila som ikke er vaare hoppes over uten sty. St1 sender
    // ofte hele klyngen - se kommentaren om `ukoblet` over.
    if (!stasjonId) continue
    inn.push({
      retailer_id: retailerId,
      stasjon_id: stasjonId,
      ar,
      nivaa: k.nivaa,
      kode: k.kode,
      navn: k.navn,
      kast_pst_av_salg: k.kastPst,
      kast_budsjett_kr: k.kastKr,
      historisk_salg_kr: k.historiskSalg,
      usynlig_budsjett_kr: k.usynligKr,
      kilde_jobb_id: jobbId,
      oppdatert_tid: naa,
    })
  }
  if (inn.length === 0) return 0
  // UPSERT, IKKE INSERT. St1 sender reviderte filer, og en ny fil for
  // samme aar er en RETTELSE - ikke en rad ved siden av den gamle.
  const { error } = await supabase
    .from('kastbudsjett')
    .upsert(inn, { onConflict: 'stasjon_id,ar,nivaa,kode' })
  if (error) throw new ParserFeil(`Delingsfil: kunne ikke skrive kastbudsjett: ${error.message}`)
  return inn.length
}

// ---------------------------------------------------------------------
// FORDELER AARSRAMMEN PAA MAANEDER, UT FRA DOKUMENTET I STEDET FOR FILA
//
// `lagreBp` gjoer det samme mens den har fila i haanden. Delingsfila
// kommer etterpaa og har ingen fil - bare et aarstall og et timebudsjett
// - saa kurven maa komme fra `bp_linje`, som er dokumentet slik fila var.
//
// SAMME TALL BEGGE VEIER er hele forutsetningen, og den er ikke antatt:
// `src/lib/bp/fordeling.test.ts` beviser at `bruttoKurve(bpLinjer(s))` er
// identisk med `s.maaneder.map(m => m.bruttoKr)`. Driver de fra
// hverandre, faller den testen - ikke en bruker.
//
// MAANEDSLAASEN LESES LIKT. En avlagt maaned baerer sitt eget budsjett i
// regnskapet, og det er det kjeden maaler mot; BP-ens tall for den
// maaneden er historikk. Samme spoerring som i `lagreBp`.
//
// Skriver BARE bemanningstabellene. `bp_*`-linjene i regnskapslinjer
// hoerer til BP-importen og roeres ikke: delingsfila sier noe om timer,
// ingenting om omsetning.
// ---------------------------------------------------------------------
async function fordelFraDokument(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  ar: number,
  stasjonIder: string[],
): Promise<number> {
  if (stasjonIder.length === 0) return 0

  const { data: aargangene } = await supabase
    .from('bp_aar')
    .select('id, stasjon_id, timer_aar')
    .eq('ar', ar)
    .in('stasjon_id', stasjonIder)
  const medTimer = ((aargangene ?? []) as {
    id: string; stasjon_id: string; timer_aar: number | null
  }[]).filter((a) => a.timer_aar !== null)
  if (medTimer.length === 0) return 0

  const { data: linjer } = await supabase
    .from('bp_linje')
    .select('bp_aar_id, maned, seksjon, kode, post, belop_kr')
    .in('bp_aar_id', medTimer.map((a) => a.id))
  const perAargang = new Map<string, Bplinje[]>()
  for (const l of (linjer ?? []) as ({ bp_aar_id: string } & Bplinje)[]) {
    const liste = perAargang.get(l.bp_aar_id) ?? []
    liste.push(l)
    perAargang.set(l.bp_aar_id, liste)
  }

  // Laaste maaneder - identisk spoerring med `lagreBp`.
  const { data: avlagt } = await supabase
    .from('regnskapslinjer')
    .select('stasjon_id, periode, kode, budsjett')
    .eq('retailer_id', retailerId)
    .eq('seksjon', 'bruttofortjeneste')
    .is('slettet_tid', null)
    .not('stasjon_id', 'is', null)
    .gte('periode', `${ar}-01-01`)
    .lte('periode', `${ar}-12-01`)
  const laast = new Map<string, number>()
  for (const rad of (avlagt ?? []) as {
    stasjon_id: string; periode: string; kode: string | null; budsjett: number | null
  }[]) {
    if ((rad.kode ?? '') === '40') continue // CR-rollup, ville dublert kategoriene
    const n = `${rad.stasjon_id}|${Number.parseInt(rad.periode.slice(5, 7), 10)}`
    laast.set(n, (laast.get(n) ?? 0) + (rad.budsjett ?? 0))
  }

  const { data: ret } = await supabase
    .from('retailers').select('bemanning_sikkerhet_pst').eq('id', retailerId).single()
  const sikkerhetPst = (ret as { bemanning_sikkerhet_pst: number } | null)?.bemanning_sikkerhet_pst ?? 3
  const sykesats = await sykefravaerssats(supabase, retailerId)

  // Bevar det som er satt manuelt - samme regel som i `lagreBp`.
  const { data: eksisterende } = await supabase
    .from('bemanning_aar')
    .select('stasjon_id, sikkerhet_pst, fast_arsverk_timer')
    .eq('ar', ar)
    .in('stasjon_id', medTimer.map((a) => a.stasjon_id))
  const fraFor = new Map(((eksisterende ?? []) as {
    stasjon_id: string; sikkerhet_pst: number | null; fast_arsverk_timer: number
  }[]).map((e) => [e.stasjon_id, e]))

  const naa = new Date().toISOString()
  const aarRader: Record<string, unknown>[] = []
  const budsjettRader: Record<string, unknown>[] = []
  const manedRader: Record<string, unknown>[] = []

  for (const a of medTimer) {
    const mine = perAargang.get(a.id) ?? []
    const timerAar = a.timer_aar as number
    const gammel = fraFor.get(a.stasjon_id)
    const stasjonSikkerhet = gammel?.sikkerhet_pst ?? sikkerhetPst

    // Avlagt maaned slaar BP-en; aapne og framtidige tar BP-tallet.
    const fraDok = bruttoKurve(mine)
    const brutto = fraDok.map((b, i) => laast.get(`${a.stasjon_id}|${i + 1}`) ?? b)
    const lonn = timelonnKurve(mine)
    const rammer = maanedsrammer(timerAar, brutto, {
      reservePst: sykesats,
      sikkerhetPst: stasjonSikkerhet,
    })

    aarRader.push({
      stasjon_id: a.stasjon_id, ar,
      timer_aar: timerAar,
      fast_arsverk_timer: gammel?.fast_arsverk_timer ?? 0,
      reserve_pst: sykesats,
      sikkerhet_pst: stasjonSikkerhet,
      kilde: `delingsfil ${jobbId}`,
      oppdatert_tid: naa,
    })
    for (const ramme of rammer) {
      budsjettRader.push({
        stasjon_id: a.stasjon_id, ar, maned: ramme.maned,
        timer: ramme.timer,
        lonn_kr: lonn[ramme.maned - 1],
        brutto_bp_kr: ramme.brutto_bp_kr,
        reserve_pst: sykesats,
        oppdatert_tid: naa,
      })
      manedRader.push({
        stasjon_id: a.stasjon_id, ar, maned: ramme.maned,
        disponible_timer: ramme.disponible_timer,
        beregnet_tid: naa,
      })
    }
  }

  await skrivBatch(supabase, 'bemanning_aar', aarRader, 'stasjon_id,ar')
  await skrivBatch(supabase, 'bemanning_budsjett', budsjettRader, 'stasjon_id,ar,maned')
  await skrivBatch(supabase, 'bemanning_maned', manedRader, 'stasjon_id,ar,maned')
  return aarRader.length + budsjettRader.length + manedRader.length
}


// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
// Varsel etter regnskapsimport: er paafyllene slaatt inn?
//
// REGELEN, fra Robert 2026-08-23: «Kaffelojalitet er der vi
// nedjusteres. Hvis kaffelojalitet er -2000 kr og kaffe/te er 2000, saa
// er det rett justert. Er kaffe/te 1000 kr, mangler det justering paa
// 1000 kr.»
//
// Kaffen forsvinner fra lageret og gir manko paa 13010; slaas
// utdelingen inn, gir den overskudd paa 13011. Det som staar igjen er
// justeringen som mangler. `v_kaffe_svinn` (0126) regner det ut.
//
// HELE AARET, IKKE MAANEDEN. Tallet er kumulativt og skal leses slik:
// «hittil i aar mangler dere X». En enkelt maaned er for smaa tall til
// aa skille rutine fra tilfeldighet - og det er aarets manko som skal
// nullstilles, ikke julis.
//
// Best effort: et varsel som feiler skal aldri velte importen.
// ---------------------------------------------------------------------
async function varsleKaffe(
  supabase: Klient,
  retailerId: string,
  medNummer: Map<string, string>,
  perStasjon: Awaited<ReturnType<typeof parseRegnskapStasjoner>>,
): Promise<void> {
  // Bare stasjonene som var med i DENNE importen. Uten det ville hver
  // opplasting varslet alle, ogsaa dem filen ikke naevner.
  const ider = perStasjon
    .map((st) => medNummer.get(st.butikknummer))
    .filter((id): id is string => Boolean(id))
  if (ider.length === 0) return

  const aar = `${new Date().getUTCFullYear()}-01-01`
  const { data } = await supabase
    .from('v_kaffe_svinn')
    .select('stasjon_id, kaffe_kr, lojalitet_kr, mangler_kr, maaneder, vanligste_paafyll, kr_per_kopp')
    .eq('aar', aar)
    .in('stasjon_id', ider)

  for (const r of (data ?? []) as KaffeRad[]) {
    const varsel = lagKaffevarsel({
      kaffeKr: r.kaffe_kr ?? 0,
      lojalitetKr: r.lojalitet_kr ?? 0,
      manglerKr: r.mangler_kr ?? 0,
      maaneder: r.maaneder ?? 0,
      vanligste: r.vanligste_paafyll && r.kr_per_kopp
        ? { varenavn: r.vanligste_paafyll, krPerKopp: r.kr_per_kopp }
        : null,
    })
    if (!varsel) continue
    await opprettVarsel(supabase, {
      retailer_id: retailerId,
      stasjon_id: r.stasjon_id,
      type: varsel.type,
      tittel: varsel.tittel,
      tekst: varsel.tekst,
      lenke: '/regnskap',
    })
  }
}

type KaffeRad = {
  stasjon_id: string
  kaffe_kr: number | null
  lojalitet_kr: number | null
  mangler_kr: number | null
  maaneder: number | null
  vanligste_paafyll: string | null
  kr_per_kopp: number | null
}

// Varsler etter regnskapsimport: hvordan gikk bemanningen forrige måned?
//
// Alt vi trenger kom nettopp inn i samme fil — «Sammenstilling» gir timer,
// timesats, brutto per variabel time og lønnsandel per stasjon. Rammen de
// måles mot ligger i bemanning_maned, som BP-opplastingen fylte.
//
// Best effort: et varsel som feiler skal aldri velte importen.
// ---------------------------------------------------------------------
async function varsleBemanning(
  supabase: Klient,
  retailerId: string,
  perStasjon: Awaited<ReturnType<typeof parseRegnskapStasjoner>>,
  periode: string,
  medNummer: Map<string, string>,
): Promise<void> {
  const ar = Number.parseInt(periode.slice(0, 4), 10)
  const maned = Number.parseInt(periode.slice(5, 7), 10)
  if (!ar || !maned) return

  const tall = (linjer: { seksjon: string; post: string; regnskap: number }[], post: string) =>
    linjer.find((l) => l.seksjon === 'nokkeltall' && l.post === post)?.regnskap ?? 0

  const maalt = perStasjon
    .map((st) => {
      const stasjonId = medNummer.get(st.butikknummer)
      if (!stasjonId) return null
      const timer = tall(st.linjer, 'Timelønn - antall timer')
      if (timer <= 0) return null
      return {
        stasjonId,
        timer,
        sats: tall(st.linjer, 'Timelønn - gj.sn. timesats'),
        bruttoPrTime: tall(st.linjer, 'Bruttofortj pr variabel time'),
        lonnAvBrutto: tall(st.linjer, 'Lønns% av bruttofortjeneste'),
        // 505 sykelønn + 506 refusjon = nettokostnad.
        sykelonn: st.linjer
          .filter((l) => l.seksjon === 'driftskostnader' && (l.kode === '505' || l.kode === '506'))
          .reduce((a, l) => a + l.regnskap, 0),
      }
    })
    .filter((x): x is NonNullable<typeof x> => x !== null)
  if (maalt.length === 0) return

  // Clusterets brutto per bemanningstime — målestokken den enkelte stasjon
  // sammenlignes mot. Brutto per stasjon er timer × brutto-per-time.
  const timerSum = maalt.reduce((a, m) => a + m.timer, 0)
  const bruttoSum = maalt.reduce((a, m) => a + m.timer * m.bruttoPrTime, 0)
  const clusterBruttoPrTime = timerSum > 0 ? bruttoSum / timerSum : 0

  const ider = maalt.map((m) => m.stasjonId)
  const [{ data: rammer }, { data: budsjetter }] = await Promise.all([
    supabase.from('bemanning_maned').select('stasjon_id, disponible_timer')
      .eq('ar', ar).eq('maned', maned).in('stasjon_id', ider),
    supabase.from('bemanning_budsjett').select('stasjon_id, timer, lonn_kr, brutto_bp_kr, reserve_pst')
      .eq('ar', ar).eq('maned', maned).in('stasjon_id', ider),
  ])
  const ramme = new Map(
    ((rammer ?? []) as { stasjon_id: string; disponible_timer: number }[])
      .map((r) => [r.stasjon_id, r.disponible_timer]),
  )
  const budsjett = new Map(
    ((budsjetter ?? []) as {
      stasjon_id: string; timer: number; lonn_kr: number | null
      brutto_bp_kr: number | null; reserve_pst: number | null
    }[]).map((b) => [b.stasjon_id, b]),
  )

  for (const m of maalt) {
    const b = budsjett.get(m.stasjonId)
    const varsler = lagBemanningsvarsler({
      maned,
      timerBrukt: m.timer,
      timerDisponible: ramme.get(m.stasjonId) ?? null,
      timesatsFaktisk: m.sats,
      timesatsBudsjett: b?.lonn_kr && b.timer > 0 ? b.lonn_kr / b.timer : null,
      bruttoPrTime: m.bruttoPrTime,
      bruttoPrTimeCluster: clusterBruttoPrTime,
      bruttoFaktisk: m.timer * m.bruttoPrTime,
      bruttoBudsjett: b?.brutto_bp_kr ?? null,
      sykelonnNetto: m.sykelonn,
      reserveKr: b?.reserve_pst != null && b.lonn_kr ? (b.reserve_pst / 100) * b.lonn_kr : null,
      lonnAvBrutto: m.lonnAvBrutto,
    })
    for (const v of varsler) {
      await opprettVarsel(supabase, {
        retailer_id: retailerId,
        stasjon_id: m.stasjonId,
        type: v.type,
        tittel: v.tittel,
        tekst: v.tekst,
        lenke: '/bemanning',
      })
    }
  }
}

async function lagreRegnskap(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  r: Awaited<ReturnType<typeof parseRegnskap>>,
  periode: string,
  perStasjon: Awaited<ReturnType<typeof parseRegnskapStasjoner>>,
  medNummer: Map<string, string>,
): Promise<Lagring> {
  type RegnskapInnsett = Awaited<ReturnType<typeof parseRegnskap>>['linjer'][number]
  const mapLinje = (l: RegnskapInnsett, stasjonId: string | null) => ({
    retailer_id: retailerId, stasjon_id: stasjonId, periode, seksjon: l.seksjon,
    kode: l.kode, post: l.post, sortering: l.sortering,
    regnskap: l.regnskap, budsjett: l.budsjett, avvik: l.avvik, index_pct: l.indexPct,
    regnskap_hittil: l.regnskapHittil, budsjett_hittil: l.budsjettHittil, kilde_jobb_id: jobbId,
  })

  const rader = r.linjer.map((l) => mapLinje(l, null)) // cluster
  const umatchet: string[] = []
  for (const st of perStasjon) {
    const stasjonId = medNummer.get(st.butikknummer)
    if (!stasjonId) { umatchet.push(`${st.butikknummer} (${st.navn})`); continue }
    for (const l of st.linjer) rader.push(mapLinje(l, stasjonId))
  }

  await supabase
    .from('regnskapslinjer')
    .delete()
    .eq('retailer_id', retailerId)
    .eq('periode', periode)

  if (rader.length > 0) await skrivBatch(supabase, 'regnskapslinjer', rader)
  return { antallRader: rader.length, umatchet }
}
