import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang, iDag } from '@/lib/format'
import { lagProduksjonsplan, leggTilDager, type SalgsPunkt, type Vaerdag } from '@/lib/produksjonsplan'
import { PlanTabell, type Gruppe, type Produkt } from './plan-tabell'
import { TabletPlan, type TabletGruppe } from './tablet-plan'

// Produksjons-varegrupper (St1): kun det som faktisk produseres/bakes.
const KODER = ['1201', '1202', '1203', '1216', '1217', '1218', '1219', '1221']
const UKEDAG = ['søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag']

type SalgRad = { varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }

export default async function ProduksjonsplanSide({
  searchParams,
}: {
  searchParams: Promise<{ butikknummer?: string; dato?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()

  // Tablet: ansatte ser den publiserte planen for i dag og logger «lagd hittil».
  if (bruker.rolle === 'butikkbruker_tablet') {
    const idag = iDag()
    const { data: st } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).limit(1).maybeSingle<{ id: string; navn: string; butikknummer: string }>()
    if (!st) return <section className="tablet-seksjon"><h2>🥐 Produksjon</h2><p>Ingen stasjon.</p></section>
    const { data: hode } = await supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', st.id).eq('dato', idag).maybeSingle<{ notat: string | null; publisert_tid: string | null }>()
    if (!hode?.publisert_tid) {
      return <section className="tablet-seksjon"><h2>🥐 Produksjon</h2><p>Ingen produksjonsplan publisert i dag.</p></section>
    }
    const { data: linjer } = await supabase
      .from('produksjonsplan_linjer').select('varenavn, varegruppe_navn, planlagt, start_antall, lagd_hittil')
      .eq('stasjon_id', st.id).eq('dato', idag).eq('ekskludert', false).gt('planlagt', 0)
      .order('varegruppe_navn').overrideTypes<{ varenavn: string; varegruppe_navn: string | null; planlagt: number; start_antall: number; lagd_hittil: number }[]>()
    const gmap = new Map<string, TabletGruppe>()
    for (const l of linjer ?? []) {
      const navn = l.varegruppe_navn ?? 'Produksjon'
      let g = gmap.get(navn)
      if (!g) { g = { navn, produkter: [] }; gmap.set(navn, g) }
      g.produkter.push({ varenavn: l.varenavn, planlagt: l.planlagt, start_antall: l.start_antall, lagd_hittil: l.lagd_hittil })
    }
    return (
      <>
        <h1>🥐 Produksjon i dag</h1>
        <TabletPlan stasjonId={st.id} dato={idag} notat={hode.notat} grupper={[...gmap.values()]} />
      </>
    )
  }

  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til produksjonsplan.</p>
  }
  const sp = await searchParams

  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; butikknummer: string; navn: string; stasjonstype: string }[]>()

  const valgtNr = sp.butikknummer || stasjoner?.[0]?.butikknummer || ''
  const stasjon = (stasjoner ?? []).find((s) => s.butikknummer === valgtNr)

  const imorgen = new Date()
  imorgen.setDate(imorgen.getDate() + 1)
  const dato = sp.dato && /^\d{4}-\d{2}-\d{2}$/.test(sp.dato) ? sp.dato : imorgen.toISOString().slice(0, 10)
  const ukedag = new Date(dato).getUTCDay()

  let grupper: Gruppe[] = []
  let datadybde = 0
  let vaer: Vaerdag | null = null
  let advarsler: string[] = []
  let hodeData: { notat: string | null; publisert_tid: string | null } | null = null

  if (stasjon) {
    const fjorBase = leggTilDager(dato, -364)
    // Siste dag med faktisk salg (ikke «i dag») — så manglende dager bakerst
    // ikke trekker snittet ned.
    const { data: sisteRad } = await supabase
      .from('daglig_salg').select('dato').eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER).is('slettet_tid', null)
      .order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
    const sisteSalgsdato = sisteRad?.dato ?? leggTilDager(dato, -1)
    const fra = leggTilDager(dato, -392) // dekker fjor-vindu + nylig + fjor-trend

    const [{ data: salg }, { data: vMaal }, { data: vFjor }, { data: lagrede }, { data: hode }] = await Promise.all([
      supabase.from('daglig_salg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato').eq('stasjon_id', stasjon.id).in('varegruppe_kode', KODER).gte('dato', fra).lte('dato', sisteSalgsdato).is('slettet_tid', null).overrideTypes<SalgRad[]>(),
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<Vaerdag>(),
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', fjorBase).maybeSingle<Vaerdag>(),
      supabase.from('produksjonsplan_linjer').select('varenavn, planlagt, start_antall, ekskludert').eq('stasjon_id', stasjon.id).eq('dato', dato).overrideTypes<{ varenavn: string; planlagt: number; start_antall: number; ekskludert: boolean }[]>(),
      supabase.from('produksjonsplan_hode').select('notat, publisert_tid').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<{ notat: string | null; publisert_tid: string | null }>(),
    ])
    vaer = vMaal ?? null
    hodeData = hode ?? null
    const punkter: SalgsPunkt[] = (salg ?? [])
      .map((r) => ({ dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall ?? 0 }))
      .filter((p) => p.varenavn)
    datadybde = new Set(punkter.map((p) => p.dato)).size

    const plan = lagProduksjonsplan({ maalDato: dato, sisteSalgsdato, salg: punkter, vaerMaal: vMaal ?? null, vaerFjor: vFjor ?? null, vaerfolsomhet: 0.5 })
    advarsler = plan.advarsler

    const lagretFor = new Map((lagrede ?? []).map((l) => [l.varenavn, l]))
    const grupperMap = new Map<string, Gruppe>()
    for (const f of plan.forslag) {
      const l = lagretFor.get(f.varenavn)
      const produkt: Produkt = {
        varenavn: f.varenavn, baseline: f.basis, faktor: f.samletfaktor, foreslatt: f.foreslatt,
        planlagt: l?.planlagt ?? f.foreslatt, start_antall: l?.start_antall ?? 0, ekskludert: l?.ekskludert ?? false, flagg: f.flagg,
      }
      const nokkel = f.varegruppeKode ?? f.varegruppeNavn ?? '—'
      let g = grupperMap.get(nokkel)
      if (!g) { g = { kode: f.varegruppeKode, navn: f.varegruppeNavn ?? `Varegruppe ${f.varegruppeKode ?? '?'}`, produkter: [] }; grupperMap.set(nokkel, g) }
      g.produkter.push(produkt)
    }
    grupper = [...grupperMap.values()].sort((a, b) => (a.kode ?? '').localeCompare(b.kode ?? ''))
  }

  return (
    <>
      <h1>Produksjonsplan</h1>
      <p className="undertittel">Forslag bygd på fjorårets samme ukedag (median) + nylig trend + værvarsel, med kampanje-deteksjon. Juster før du produserer.</p>

      <section className="kort">
        <form method="get" className="plan-velg">
          <label className="felt">
            <span>Stasjon</span>
            <select name="butikknummer" defaultValue={valgtNr}>
              {(stasjoner ?? []).map((s) => <option key={s.id} value={s.butikknummer}>{s.butikknummer} {s.navn}</option>)}
            </select>
          </label>
          <label className="felt">
            <span>Dag</span>
            <input type="date" name="dato" defaultValue={dato} />
          </label>
          <button type="submit">Vis plan</button>
        </form>
        {stasjon && (
          <p className="undertittel" style={{ marginTop: '0.75rem' }}>
            {UKEDAG[ukedag]} {datoLang.format(new Date(dato))} · type {stasjon.stasjonstype}
            {vaer?.temp_maks != null ? ` · varsel ${vaer.temp_maks.toFixed(0)}°` : ' · ingen værvarsel'}
            {' · baseline fra '}{datadybde} salgsdag{datadybde === 1 ? '' : 'er'}
          </p>
        )}
      </section>

      {advarsler.length > 0 && (
        <section className="kort oppmerksomhet">
          <ul className="fokus-liste">{advarsler.map((a, i) => <li key={i}>{a}</li>)}</ul>
        </section>
      )}

      {grupper.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen produksjonssalg (varegruppe 1201–1221) for denne stasjonen ennå. Behandle en Salgsstatistikk-fil først.
          </p>
        </section>
      ) : (
        <>
          <PlanTabell grupper={grupper} stasjonId={stasjon!.id} dato={dato} notat={hodeData?.notat ?? null} publisertTid={hodeData?.publisert_tid ?? null} />
          {datadybde < 14 && (
            <p className="undertittel">
              ⚠ Tynt datagrunnlag ({datadybde} dag{datadybde === 1 ? '' : 'er'}). Forslaget blir mer presist med mer historikk (§7).
            </p>
          )}
        </>
      )}
    </>
  )
}
