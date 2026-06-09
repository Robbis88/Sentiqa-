import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { produksjonsfaktor, type Vaerdag } from '@/lib/produksjonsplan'
import { PlanTabell, type Gruppe, type Produkt } from './plan-tabell'

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
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til produksjonsplan.</p>
  }
  const supabase = await lagSupabaseServerKlient()
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

  if (stasjon) {
    const [{ data: salg }, { data: v }, { data: lagrede }] = await Promise.all([
      supabase
        .from('daglig_salg')
        .select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', stasjon.id)
        .in('varegruppe_kode', KODER)
        .is('slettet_tid', null)
        .overrideTypes<SalgRad[]>(),
      supabase.from('vaer').select('temp_maks, nedbor_mm').eq('stasjon_id', stasjon.id).eq('dato', dato).maybeSingle<Vaerdag>(),
      supabase
        .from('produksjonsplan_linjer')
        .select('varenavn, planlagt')
        .eq('stasjon_id', stasjon.id)
        .eq('dato', dato)
        .overrideTypes<{ varenavn: string; planlagt: number }[]>(),
    ])
    vaer = v ?? null
    const lagretFor = new Map((lagrede ?? []).map((l) => [l.varenavn, l.planlagt]))

    const dager = new Set<string>()
    const per = new Map<string, { sum: number; kode: string | null; gruppenavn: string | null }>()
    for (const r of salg ?? []) {
      const navn = (r.varenavn ?? '').trim()
      if (!navn) continue
      dager.add(r.dato)
      const p = per.get(navn) ?? { sum: 0, kode: r.varegruppe_kode, gruppenavn: r.varegruppe_navn }
      p.sum += r.antall ?? 0
      if (!p.kode && r.varegruppe_kode) p.kode = r.varegruppe_kode
      if (!p.gruppenavn && r.varegruppe_navn) p.gruppenavn = r.varegruppe_navn
      per.set(navn, p)
    }
    datadybde = dager.size || 1

    const grupperMap = new Map<string, Gruppe>()
    for (const [varenavn, info] of per.entries()) {
      const baseline = info.sum / datadybde
      if (baseline <= 0) continue
      const faktor = produksjonsfaktor(stasjon.stasjonstype, vaer, ukedag, info.gruppenavn ?? '')
      const foreslatt = Math.round(baseline * faktor)
      const produkt: Produkt = { varenavn, baseline, faktor, foreslatt, planlagt: lagretFor.get(varenavn) ?? foreslatt }
      const nokkel = info.kode ?? info.gruppenavn ?? '—'
      let g = grupperMap.get(nokkel)
      if (!g) {
        g = { kode: info.kode, navn: info.gruppenavn ?? `Varegruppe ${info.kode ?? '?'}`, produkter: [] }
        grupperMap.set(nokkel, g)
      }
      g.produkter.push(produkt)
    }
    grupper = [...grupperMap.values()]
      .map((g) => ({ ...g, produkter: g.produkter.sort((a, b) => b.foreslatt - a.foreslatt) }))
      .sort((a, b) => (a.kode ?? '').localeCompare(b.kode ?? ''))
  }

  return (
    <>
      <h1>Produksjonsplan</h1>
      <p className="undertittel">Forslag per produkt, gruppert på varegruppe. Juster antallene før du produserer.</p>

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

      {grupper.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen produksjonssalg (varegruppe 1201–1221) for denne stasjonen ennå. Behandle en Salgsstatistikk-fil først.
          </p>
        </section>
      ) : (
        <>
          <PlanTabell grupper={grupper} stasjonId={stasjon!.id} dato={dato} />
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
