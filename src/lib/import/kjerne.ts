import type { SupabaseClient } from '@supabase/supabase-js'
import { randomUUID } from 'node:crypto'
import type { ForhandsPayload } from './typer'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import { parseBp } from '@/lib/parsere/bp'
import { fordelPaaMaaneder } from '@/lib/bemanning'
import { lagBemanningsvarsler } from '@/lib/bemanningsvarsler'
import { after } from 'next/server'
import { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import { kjorRegnskapsanalyse } from '@/lib/ai/regnskapsanalyse'
import { genererFokusForRetailer } from '@/lib/ai/fokus'
import { ParserFeil, forsteDatoIso } from '@/lib/parsere/felles'
import { opprettVarsel } from '@/lib/varsler'

// Behandlings-kjernen (§6). Tar imot en supabase-klient — UI-knappen bruker
// brukersesjonen, e-post-webhooken bruker service-role. Ingen session/revalidate
// her, så den kan kjøres fra begge.
type Klient = SupabaseClient
type Lagring = { antallRader: number; umatchet: string[] }

// Skriver rader i batcher (ikke én diger insert) — holder hvert kall raskt og
// under grensene, så store/mange filer ikke timer ut. Feiler en batch, sies
// hvilken (resten av importen kan kjøres på nytt idempotent).
const BATCH = 500
async function skrivBatch(supabase: Klient, tabell: string, rader: Record<string, unknown>[], onConflict?: string): Promise<void> {
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
  const medNummer = new Map<string, string>()
  const medNavn = new Map<string, string>()
  for (const s of (data ?? []) as { id: string; butikknummer: string; navn: string }[]) {
    medNummer.set(s.butikknummer, s.id)
    medNavn.set(s.navn.trim().toLowerCase(), s.id)
  }
  return { medNummer, medNavn }
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

  const rapporttype = await gjenkjennRapporttype(buffer)
  await supabase.from('import_jobber').update({ rapporttype }).eq('id', jobbId)

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
        break
      }
      case 'st1_bp': {
        const r = await parseBp(buffer)
        dato = r.ar ? `${r.ar}-01-01` : null
        res = await lagreBp(supabase, retailerId, jobbId, r, oppslag.medNummer)
        break
      }
      default:
        await settFeil(`Gjenkjent som «${rapporttype}» – lagring for denne typen kommer senere.`)
        return
    }

    await supabase
      .from('import_jobber')
      .update({
        status: res.antallRader === 0 ? 'feilet' : 'parset',
        gjelder_dato: dato,
        antall_rader: res.antallRader,
        parset_tid: new Date().toISOString(),
        feilmelding:
          res.umatchet.length > 0
            ? `Ukjente stasjoner (registrer dem): ${res.umatchet.join(', ')}`
            : null,
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

// Browser-parsing: klienten parser fila lokalt (ingen server-parse-timeout) og
// sender PARSER-RESULTATET hit. Vi lagrer kun (batchet) + fører en jobb-rad.
// Ingen rå-fil i Storage (klienten har den) — sentinel-sti tilfredsstiller NOT NULL.
export async function lagreForhandsparset(
  supabase: Klient,
  retailerId: string,
  meta: { filnavn: string; sha256: string; storrelse: number },
  payload: ForhandsPayload,
): Promise<{ ok: boolean; hoppet?: boolean; antallRader?: number; feil?: string }> {
  const { data: raaFil, error: filFeil } = await supabase
    .from('raa_filer')
    .insert({ retailer_id: retailerId, filnavn: meta.filnavn, storage_sti: `klient/${randomUUID()}-${meta.filnavn}`, mottakskanal: 'drop_zone', storrelse_bytes: meta.storrelse, sha256: meta.sha256 })
    .select('id').single<{ id: string }>()
  if (filFeil || !raaFil) {
    if (filFeil?.code === '23505') return { ok: true, hoppet: true } // allerede importert
    return { ok: false, feil: filFeil?.message ?? 'Kunne ikke registrere fil.' }
  }
  const { data: jobb } = await supabase
    .from('import_jobber')
    .insert({ raa_fil_id: raaFil.id, retailer_id: retailerId, rapporttype: payload.type, status: 'behandler' })
    .select('id').single<{ id: string }>()
  const jobbId = jobb!.id

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
      feilmelding: res.umatchet.length > 0 ? `Ukjente stasjoner (registrer dem): ${res.umatchet.join(', ')}` : null,
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
  return { antallRader: rader.length, umatchet }
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
  return { antallRader: rader.length, umatchet }
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
  return { antallRader: rader.length, umatchet }
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
const LONNSKONTI = ['501', '502', '503', '508', '540', '541']
const SYKEKONTI = ['505', '506']

async function sykefravaerssatser(
  supabase: Klient,
  retailerId: string,
): Promise<{ perStasjon: Map<string, number>; poolet: number }> {
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

  const lonn = new Map<string, number>()
  const syke = new Map<string, number>()
  let lonnSum = 0
  let sykeSum = 0
  for (const r of (data ?? []) as { stasjon_id: string; kode: string; regnskap: number | null }[]) {
    const v = r.regnskap ?? 0
    if (SYKEKONTI.includes(r.kode)) {
      syke.set(r.stasjon_id, (syke.get(r.stasjon_id) ?? 0) + v)
      sykeSum += v
    } else {
      lonn.set(r.stasjon_id, (lonn.get(r.stasjon_id) ?? 0) + v)
      lonnSum += v
    }
  }
  const poolet = lonnSum > 0 ? (sykeSum / lonnSum) * 100 : 0
  const perStasjon = new Map<string, number>()
  for (const [id, l] of lonn) {
    if (l > 0) perStasjon.set(id, Math.max(((syke.get(id) ?? 0) / l) * 100, poolet))
  }
  return { perStasjon, poolet }
}

async function lagreBp(
  supabase: Klient,
  retailerId: string,
  jobbId: string,
  r: Awaited<ReturnType<typeof parseBp>>,
  medNummer: Map<string, string>,
): Promise<Lagring> {
  const ar = r.ar
  if (!ar) throw new ParserFeil('BP: fant ingen årstall i fila.')

  const { data: ret } = await supabase
    .from('retailers')
    .select('bemanning_sikkerhet_pst')
    .eq('id', retailerId)
    .single()
  const sikkerhetPst = (ret as { bemanning_sikkerhet_pst: number } | null)?.bemanning_sikkerhet_pst ?? 3

  const { perStasjon: sykesats, poolet } = await sykefravaerssatser(supabase, retailerId)

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

  for (const { s, stasjonId } of mine) {
    const gammel = fra_for.get(stasjonId)
    const reservePst = gammel?.reserve_pst ?? sykesats.get(stasjonId) ?? poolet
    const stasjonSikkerhet = gammel?.sikkerhet_pst ?? sikkerhetPst
    const timerAar = s.timerAar ?? 0

    aarRader.push({
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
    const bruttoSum = brutto.reduce((a, b) => a + b, 0)
    const timerPerMaaned = fordelPaaMaaneder(timerAar, brutto, {
      reservePst,
      sikkerhetPst: stasjonSikkerhet,
    })

    for (const m of s.maaneder) {
      const erLaast = laast.has(`${stasjonId}|${m.maned}`)
      const bruttoMnd = brutto[m.maned - 1]
      // Rå månedsramme før fradrag — det retailer ser.
      const andel = bruttoSum > 0 ? bruttoMnd / bruttoSum : 1 / 12
      budsjettRader.push({
        stasjon_id: stasjonId, ar, maned: m.maned,
        timer: timerAar * andel,
        lonn_kr: m.timelonnKr,
        brutto_bp_kr: bruttoMnd,
        reserve_pst: reservePst,
        oppdatert_tid: new Date().toISOString(),
      })
      manedRader.push({
        stasjon_id: stasjonId, ar, maned: m.maned,
        disponible_timer: Math.max(0, timerPerMaaned[m.maned - 1]),
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
  }

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
      aarRader.length + budsjettRader.length + manedRader.length + bpLinjer.length,
    umatchet: [],
  }
}

// ---------------------------------------------------------------------
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
