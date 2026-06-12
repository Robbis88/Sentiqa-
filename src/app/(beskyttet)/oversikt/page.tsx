import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { beregnRutinestat } from '@/lib/rutinestat'
import { hentHjemData } from '@/lib/tablethjem'
import { oversettMange, oversettTabletOrd } from '@/lib/oversett'
import { kr, prosent, datoLang, iDag } from '@/lib/format'
import { hentEllerLagUkerapport, type UkeRapport } from '@/lib/ukerapport'
import { TabletHjem } from '../tablet-hjem'
import { UkeKort } from '../uke-kort'
import { AdminDashbord } from '../admin-dashbord'

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
    const hjem = st ? await hentHjemData(supabase, st.id) : { skills: null, premie: { vunnet: 0, brukt: 0, igjen: 0 }, vekst: null }

    // Oversett: faste UI-ord + dynamisk innhold (puls, meldinger, sjekkpunkt)
    const pulsTekst = runde?.puls_sporsmal?.tekst ?? null
    const dyn = [...(pulsTekst ? [pulsTekst] : []), ...(meldinger ?? []).map((m) => m.tekst), ...sjekkpunkter.map((s) => s.sporsmaal)]
    const [ord, dynMap] = await Promise.all([oversettTabletOrd(sprak), oversettMange(dyn, sprak)])
    const o = (s: string) => dynMap.get(s) ?? s
    const meldingerO = (meldinger ?? []).map((m) => ({ ...m, tekst: o(m.tekst) }))
    const sjekkO = sjekkpunkter.map((s) => ({ ...s, sporsmaal: o(s.sporsmaal) }))
    const pulsRunde = pulsTekst && runde ? { id: runde.id, tekst: o(pulsTekst) } : null

    return <TabletHjem navn={aktiv?.navn} streak={streak} meldinger={meldingerO} pulsRunde={pulsRunde} sjekkpunkter={sjekkO} hjem={hjem} ord={ord} />
  }

  // Eier får sitt eget rike dashbord (hele kjeden).
  if (bruker.rolle === 'retailer_admin') {
    return <AdminDashbord bruker={bruker} idag={iDag()} />
  }

  // Siste salgsdag + total omsetning (RLS scoper til brukerens stasjoner)
  const { data: sisteDag } = await supabase
    .from('v_salg_per_stasjon_dag')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  let salgOms = 0
  if (sisteDag) {
    const { data } = await supabase
      .from('v_salg_per_stasjon_dag')
      .select('omsetning')
      .eq('dato', sisteDag.dato)
      .overrideTypes<{ omsetning: number }[]>()
    salgOms = (data ?? []).reduce((a, r) => a + (r.omsetning ?? 0), 0)
  }

  // Siste regnskapsperiode (admin – cluster). Brukes til KPI + oppmerksomhet.
  const { data: sisteReg } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .is('stasjon_id', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  let oppmerksomhet: { post: string; index_pct: number; avvik: number }[] = []
  if (sisteReg) {
    const { data } = await supabase
      .from('regnskapslinjer')
      .select('seksjon, post, avvik, index_pct')
      .eq('periode', sisteReg.periode)
      .is('stasjon_id', null)
      .overrideTypes<{ seksjon: string; post: string; avvik: number | null; index_pct: number | null }[]>()
    oppmerksomhet = (data ?? [])
      .filter((l) => l.seksjon === 'omsetning' && l.index_pct != null && !/totalt$/i.test(l.post))
      .filter((l) => (l.index_pct ?? 0) < -10)
      .sort((a, b) => (a.index_pct ?? 0) - (b.index_pct ?? 0))
      .slice(0, 4)
      .map((l) => ({ post: l.post, index_pct: l.index_pct ?? 0, avvik: l.avvik ?? 0 }))
  }


  // Dagens drift-status (RLS scoper til brukerens stasjoner)
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  const [{ count: rutTot }, { count: rutGjort }, { count: sjekkTot }, { count: sjekkSvart }] = await Promise.all([
    supabase.from('rutiner').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
    supabase.from('rutine_utforinger').select('*', { count: 'exact', head: true }).eq('dato', idag),
    supabase.from('sjekkpunkter').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
    supabase.from('sjekkpunkt_svar').select('*', { count: 'exact', head: true }).eq('dato', idag),
  ])

  // Fokuspunkter til butikksjefen (deres landingsside)
  let fokus: { type: string; tekst: string; tittel: string | null }[] = []
  if (bruker.rolle === 'butikksjef') {
    const { data: sisteF } = await supabase
      .from('fokuspunkter')
      .select('periode')
      .order('periode', { ascending: false })
      .limit(1)
      .maybeSingle<{ periode: string }>()
    if (sisteF) {
      const { data } = await supabase
        .from('fokuspunkter')
        .select('type, tekst, tittel')
        .eq('periode', sisteF.periode)
        .limit(6)
        .overrideTypes<{ type: string; tekst: string; tittel: string | null }[]>()
      fokus = data ?? []
    }
  }

  // Ukerapport (forrige uke vs i fjor). Admin: alle stasjoner, butikksjef: egne
  // (RLS scoper stasjon-spørringen). Lazy + cachet i uke_rapport.
  let ukerapporter: UkeRapport[] = []
  if (bruker.rolle === 'butikksjef' && bruker.retailerId) {
    const { data: mineStasjoner } = await supabase
      .from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer')
      .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()
    try { ukerapporter = await hentEllerLagUkerapport(supabase, bruker.retailerId, mineStasjoner ?? []) } catch { ukerapporter = [] }
  }

  return (
    <>
      <h1>Oversikt</h1>
      <p className="undertittel">Hei, {bruker.fulltNavn ?? bruker.epost}.</p>

      {ukerapporter.map((r) => <UkeKort key={r.stasjonId} rapport={r} />)}

      {oppmerksomhet.length > 0 && (
        <section className="kort oppmerksomhet">
          <h2>Trenger oppmerksomhet</h2>
          <ul>
            {oppmerksomhet.map((o) => (
              <li key={o.post}>
                <span className="status-pip rod">{prosent.format(o.index_pct / 100)}</span>
                <strong>{o.post}</strong> ligger {kr.format(Math.abs(o.avvik))} under budsjett denne perioden.
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="nokkeltall">
        <Link href="/salg" className="kpi lenke">
          <span className="kpi-tall">{kr.format(salgOms)}</span>
          <span className="kpi-merke">
            Omsetning {sisteDag ? datoLang.format(new Date(sisteDag.dato)) : '– ingen data'}
          </span>
        </Link>
        {(rutTot ?? 0) > 0 && (
          <Link href="/rutiner" className="kpi lenke">
            <span className="kpi-tall">{rutGjort ?? 0} / {rutTot}</span>
            <span className="kpi-merke">Rutiner gjort i dag</span>
          </Link>
        )}
        {(sjekkTot ?? 0) > 0 && (
          <Link href="/sjekkpunkt" className="kpi lenke">
            <span className="kpi-tall">{sjekkSvart ?? 0} / {sjekkTot}</span>
            <span className="kpi-merke">Sjekkpunkt besvart</span>
          </Link>
        )}
      </section>

      {fokus.length > 0 && (
        <section className="kort">
          <h2>Dine fokuspunkter</h2>
          <ul className="fokus-liste">
            {fokus.map((f, i) => (
              <li key={i}>
                <span className={`status-pip ${f.type === 'positivt' ? 'gronn' : 'gul'}`}>
                  {f.type === 'positivt' ? 'Bra' : 'Følg med'}
                </span>{' '}
                {f.tittel ? <strong>{f.tittel}: </strong> : null}{f.tekst}
              </li>
            ))}
          </ul>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}>
            <Link href="/fokus">Se alle fokuspunkter →</Link>
          </p>
        </section>
      )}
    </>
  )
}
