import { redirect } from 'next/navigation'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { beregnRutinestat } from '@/lib/rutinestat'
import { hentHjemData } from '@/lib/tablethjem'
import { nesteRetning } from '@/lib/stempling/tilstand'
import type { Stemplingstilstand } from '../stempling-rad'
import { oversettMange, oversettTabletOrd } from '@/lib/oversett'
import { iDag } from '@/lib/format'
import { TabletHjem } from '../tablet-hjem'
import { AdminDashbord } from '../admin-dashbord'
import { ButikksjefDashbord } from '../butikksjef-dashbord'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'

// Dashbordet kan gjøre litt tyngre oppslag (regnskap/ukerapport) — gi rom.
export const maxDuration = 60

export default async function OversiktSide(
  { searchParams }: { searchParams: Promise<{ stasjon?: string; butikknummer?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()

  // Nettbrettets «I dag» (egen verden). Se tablet-hjem.tsx for hvorfor
  // flisene og okonomien ikke lenger staar her.
  if (bruker.rolle === 'butikkbruker_tablet') {
    const aktiv = await lesAktivAnsatt()
    const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
    const { cookies } = await import('next/headers')
    const sprak = (await cookies()).get('sprak')?.value ?? 'no'
    const naaTid = new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Oslo', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date())
    const [{ data: st }, { data: meldinger }, { data: runde }, { data: sjekkAlle }, { data: sjekkSvar }] = await Promise.all([
      supabase.from('stasjoner').select('id').is('slettet_tid', null).limit(1).maybeSingle<{ id: string }>(),
      supabase.from('tablet_meldinger').select('id, tekst, viktig').is('slettet_tid', null).order('viktig', { ascending: false }).order('opprettet_tid', { ascending: false }).limit(10).overrideTypes<{ id: string; tekst: string; viktig: boolean }[]>(),
      supabase.from('puls_runde').select('id, puls_sporsmal(tekst)').eq('status', 'aktiv').lte('start_dato', idag).gte('slutt_dato', idag).is('slettet_tid', null).order('opprettet_tid', { ascending: false }).limit(1).maybeSingle<{ id: string; puls_sporsmal: { tekst: string } | null }>(),
      supabase.from('sjekkpunkter').select('id, stasjon_id, sporsmaal, klokkeslett, kritisk').is('slettet_tid', null).overrideTypes<{ id: string; stasjon_id: string; sporsmaal: string; klokkeslett: string | null; kritisk: boolean }[]>(),
      supabase.from('sjekkpunkt_svar').select('sjekkpunkt_id').eq('dato', idag).overrideTypes<{ sjekkpunkt_id: string }[]>(),
    ])
    const besvart = new Set((sjekkSvar ?? []).map((s) => s.sjekkpunkt_id))
    const sjekkpunkter = (sjekkAlle ?? [])
      .filter((p) => !besvart.has(p.id) && (!p.klokkeslett || p.klokkeslett <= naaTid))
      .map((p) => ({ id: p.id, sporsmaal: p.sporsmaal, kritisk: p.kritisk, stasjon_id: p.stasjon_id }))
    const rutinestat = st ? await beregnRutinestat(supabase, st.id, idag) : null
    // Det som faktisk gjenstaar i dag - grunnlaget for skiftlista.
    const rutinerIgjen = Math.max(0, (rutinestat?.forventet ?? 0) - (rutinestat?.utfort ?? 0))
    const hjem = st ? await hentHjemData(supabase, st.id) : { skills: null, premie: { vunnet: 0, brukt: 0, igjen: 0 }, produksjon: null, vekst: null }

    // ER HUN STEMPLET INN? Raden paa «I dag» skal si hva et trykk
    // FOERER TIL, ikke hva den heter — «Stemple ut» naar hun staar inne.
    //
    // KOBLET PAA ID, ALDRI PAA NAVN. Samme ansatt finnes under tre
    // identiteter i denne basen: `ansatt_nr`, `ansatte.id` og et
    // fritekstnavn. Vakt-kapselen baerer id-en; stemplingen foeres paa
    // nummeret. Broa mellom dem gaar gjennom raden, ikke gjennom navnet
    // — to som heter det samme ville ellers delt arbeidsdag.
    //
    // `nesteRetning()` er den samme funksjonen `stemple()` bruker.
    // Delt, saa raden og handlinga ikke kan si hver sin ting.
    let stempling: Stemplingstilstand = { slag: 'ukjent' }
    if (aktiv && st) {
      const { data: ansattRad } = await supabase
        .from('ansatte').select('ansatt_nr').eq('id', aktiv.id)
        .maybeSingle<{ ansatt_nr: string | null }>()
      if (ansattRad?.ansatt_nr) {
        const { data: siste } = await supabase
          .from('stempling_hendelse')
          .select('type, tidspunkt')
          .eq('stasjon_id', st.id)
          .eq('ansatt_nr', ansattRad.ansatt_nr)
          .is('annullert_tid', null)
          .order('tidspunkt', { ascending: false })
          .limit(1)
          .maybeSingle<{ type: 'inn' | 'ut'; tidspunkt: string }>()
        stempling = siste && nesteRetning(siste) === 'ut'
          ? {
              slag: 'inne',
              siden: new Intl.DateTimeFormat('nb-NO', {
                timeZone: 'Europe/Oslo', hour: '2-digit', minute: '2-digit', hour12: false,
              }).format(new Date(siste.tidspunkt)),
            }
          : { slag: 'ute' }
      }
    }

    // «Meldinger fra butikksjef» = oppgaver merket vis_paa_tablet for stasjonen.
    // Åpne vises alltid; ferdige henger med i 24 t (kollapset) og forsvinner så.
    const doegnSidenDato = new Date()
    doegnSidenDato.setHours(doegnSidenDato.getHours() - 24)
    const doegnSiden = doegnSidenDato.toISOString()
    let sjefMeldinger: { id: string; tittel: string; beskrivelse: string | null; bilde_url: string | null; frist: string | null; fullfort: boolean }[] = []
    if (st) {
      const { data: opp } = await supabase
        .from('oppgaver')
        .select('id, tittel, beskrivelse, bilde_url, frist, status, fullfort_tid')
        .eq('stasjon_id', st.id)
        .eq('vis_paa_tablet', true)
        .is('slettet_tid', null)
        .overrideTypes<{ id: string; tittel: string; beskrivelse: string | null; bilde_url: string | null; frist: string | null; status: string; fullfort_tid: string | null }[]>()
      sjefMeldinger = (opp ?? [])
        .filter((o) => o.status !== 'fullfort' || (o.fullfort_tid != null && o.fullfort_tid >= doegnSiden))
        .map((o) => ({ id: o.id, tittel: o.tittel, beskrivelse: o.beskrivelse, bilde_url: o.bilde_url, frist: o.frist, fullfort: o.status === 'fullfort' }))
    }

    // Oversett: faste UI-ord + dynamisk innhold (puls, meldinger, sjekkpunkt)
    const pulsTekst = runde?.puls_sporsmal?.tekst ?? null
    const dyn = [
      ...(pulsTekst ? [pulsTekst] : []),
      ...(meldinger ?? []).map((m) => m.tekst),
      ...sjekkpunkter.map((s) => s.sporsmaal),
      ...sjefMeldinger.flatMap((m) => [m.tittel, ...(m.beskrivelse ? [m.beskrivelse] : [])]),
    ]
    const [ord, dynMap] = await Promise.all([oversettTabletOrd(sprak), oversettMange(dyn, sprak)])
    const o = (s: string) => dynMap.get(s) ?? s
    const meldingerO = (meldinger ?? []).map((m) => ({ ...m, tekst: o(m.tekst) }))
    const sjekkO = sjekkpunkter.map((s) => ({ ...s, sporsmaal: o(s.sporsmaal) }))
    const sjefMeldingerO = sjefMeldinger.map((m) => ({ ...m, tittel: o(m.tittel), beskrivelse: m.beskrivelse ? o(m.beskrivelse) : null }))
    const pulsRunde = pulsTekst && runde ? { id: runde.id, tekst: o(pulsTekst) } : null

    return <TabletHjem navn={aktiv?.navn} meldinger={meldingerO} sjefMeldinger={sjefMeldingerO} idag={idag} pulsRunde={pulsRunde} sjekkpunkter={sjekkO} hjem={hjem} rutinerIgjen={rutinerIgjen} stempling={stempling} ord={ord} />
  }

  // Plattform-eier hører hjemme i plattform-konsollen, ikke et kjede-dashbord.
  if (bruker.rolle === 'plattform_redaktor') redirect('/plattform')

  // =================================================================
  // STASJONSKONTEKSTEN, FELLES FOR BEGGE LEDERROLLENE.
  //
  // Sto foer bare i eiergrenen. Butikksjefen med flere stasjoner fikk
  // derfor et skall som sa «5102 Grenseby» over en side som regnet paa
  // alle tre - noyaktig den doble konteksten trinn 09 lukket, paa
  // systemets forside.
  //
  // URL-EN MAA LESES HER OGSAA. Proxyen skriver riktignok kapselen naar
  // lenka baerer en gyldig stasjon, men den kapselen gjelder foerst fra
  // NESTE forespoersel. En delt lenke ville altsaa vist skallets nye
  // stasjon over sidas gamle - paa foerste visning, som er den eneste
  // visningen en delt lenke faar.
  //
  // Rekkefolgen (URL foer hukommelse foer det fornuftige) og
  // aggregatregelen ligger i `velgStasjon`/`TAALER_AGGREGAT`, ikke her.
  // For /oversikt taaler bare eieren aggregat, saa butikksjefen faar
  // alltid EN konkret stasjon - som skallet.
  // =================================================================
  const { data: mine } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const stasjonsliste = (mine ?? []) as { id: string; navn: string; butikknummer: string }[]

  const sp = await searchParams
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  if (sp.butikknummer) sok.set('butikknummer', sp.butikknummer)

  const valgt = await husketStasjon(
    stasjonsliste,
    stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/oversikt', bruker.rolle, stasjonsliste.length),
  )

  // Eier: porteføljen som standard, én stasjon når han har valgt en i
  // toppstripen. Det er drill-downen — «Varden faller» skal kunne følges
  // helt inn i Vardens eget bilde, uten å bytte rolle eller side.
  // KAPABILITETEN KOMMER FRA TABELLEN, ikke fra en `true` her. Sto den
  // her, kunne den bli staaende mens tabellen sa noe annet - og
  // appskallet leser tabellen. Da viser toppstripen en stasjon mens
  // forsiden viser portefoljen.
  //
  // Merk foelgen: en eier med bare EN stasjon faar stasjonsbildet i
  // stedet for portefoljen. En portefolje av en ting er stasjonen, og
  // skallet sier det samme.
  if (bruker.rolle === 'retailer_admin' && valgt === null) {
    return <AdminDashbord bruker={bruker} idag={iDag()} />
  }

  // Eierens drill-down og butikksjefens operative bilde er den SAMME
  // flata med den samme stasjonen - forskjellen er bare hvordan de kom
  // hit. `valgt` kan vaere null for en butikksjef uten stasjoner i det
  // hele tatt; da faller vi tilbake til RLS-omfanget, som foer.
  return <ButikksjefDashbord bruker={bruker} bareStasjon={valgt ?? undefined} />
}
