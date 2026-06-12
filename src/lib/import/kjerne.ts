import type { SupabaseClient } from '@supabase/supabase-js'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import { kjorRegnskapsanalyse } from '@/lib/ai/regnskapsanalyse'
import { ParserFeil, forsteDatoIso } from '@/lib/parsere/felles'
import { opprettVarsel } from '@/lib/varsler'

// Behandlings-kjernen (§6). Tar imot en supabase-klient — UI-knappen bruker
// brukersesjonen, e-post-webhooken bruker service-role. Ingen session/revalidate
// her, så den kan kjøres fra begge.
type Klient = SupabaseClient
type Lagring = { antallRader: number; umatchet: string[] }

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
        // Auto-kjør eier-analysen rett etter (best effort + race-guard internt).
        try { await kjorRegnskapsanalyse(supabase, retailerId) } catch { /* manuell regenerering finnes */ }
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
  } catch (e) {
    await settFeil(e instanceof ParserFeil ? e.message : `Uventet feil: ${String(e)}`)
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
      if (Math.abs(p.usynligKr) < 1000) continue // kun meningsfulle utslag
      rader.push({ retailer_id: retailerId, stasjon_id: stasjonId, periode, kode: p.kode, navn: p.navn, salg: p.salg, brf_pst: p.brfPst, usynlig_kr: p.usynligKr, usynlig_pst: p.usynligPst, kilde_jobb_id: jobbId })
    }
  }
  if (rader.length > 0) await supabase.from('regnskap_usynlig_svinn').insert(rader)
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
  if (rader.length > 0) {
    const { error } = await supabase
      .from('daglig_salg')
      .upsert(rader, { onConflict: 'retailer_id,stasjon_id,dato,ean' })
    if (error) throw new ParserFeil(`Lagring feilet: ${error.message}`)
  }
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
  if (rader.length > 0) {
    const { error } = await supabase
      .from('timesalg')
      .upsert(rader, { onConflict: 'retailer_id,stasjon_id,dato,time' })
    if (error) throw new ParserFeil(`Lagring feilet: ${error.message}`)
  }
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
  if (rader.length > 0) {
    const { error } = await supabase
      .from('kassererstatistikk')
      .upsert(rader, { onConflict: 'retailer_id,stasjon_id,dato,kasserer_nr' })
    if (error) throw new ParserFeil(`Lagring feilet: ${error.message}`)
  }
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
  if (rader.length > 0) {
    const { error } = await supabase.from('synlig_svinn').insert(rader)
    if (error) throw new ParserFeil(`Lagring feilet: ${error.message}`)
  }
  return { antallRader: rader.length, umatchet }
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

  if (rader.length > 0) {
    const { error } = await supabase.from('regnskapslinjer').insert(rader)
    if (error) throw new ParserFeil(`Lagring feilet: ${error.message}`)
  }
  return { antallRader: rader.length, umatchet }
}
