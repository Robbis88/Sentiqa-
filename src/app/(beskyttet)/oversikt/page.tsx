import { redirect } from 'next/navigation'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { beregnRutinestat } from '@/lib/rutinestat'
import { hentHjemData } from '@/lib/tablethjem'
import { oversettMange, oversettTabletOrd } from '@/lib/oversett'
import { iDag } from '@/lib/format'
import { TabletHjem } from '../tablet-hjem'
import { AdminDashbord } from '../admin-dashbord'
import { ButikksjefDashbord } from '../butikksjef-dashbord'

// Dashbordet kan gjøre litt tyngre oppslag (regnskap/ukerapport) — gi rom.
export const maxDuration = 60

export default async function OversiktSide() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()

  // Tablet-hjem (egen verden): hero + streak + funksjons-fliser.
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
    const streak = st ? (await beregnRutinestat(supabase, st.id, idag)).streak : 0
    const hjem = st ? await hentHjemData(supabase, st.id) : { skills: null, premie: { vunnet: 0, brukt: 0, igjen: 0 }, produksjon: null, vekst: null }

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

    return <TabletHjem navn={aktiv?.navn} streak={streak} meldinger={meldingerO} sjefMeldinger={sjefMeldingerO} idag={idag} pulsRunde={pulsRunde} sjekkpunkter={sjekkO} hjem={hjem} ord={ord} />
  }

  // Plattform-eier hører hjemme i plattform-konsollen, ikke et kjede-dashbord.
  if (bruker.rolle === 'plattform_redaktor') redirect('/plattform')

  // Eier får sitt eget rike dashbord (hele kjeden).
  if (bruker.rolle === 'retailer_admin') {
    return <AdminDashbord bruker={bruker} idag={iDag()} />
  }

  // Butikksjef får sitt operative «min stasjon»-dashbord.
  return <ButikksjefDashbord bruker={bruker} />
}
