import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { tall, datoLang } from '@/lib/format'
import { produksjonsfaktor, type Vaerdag } from '@/lib/produksjonsplan'

const UKEDAG = ['søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag']

type SalgRad = { varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }

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

  let rader: { navn: string; baseline: number; faktor: number; foreslatt: number }[] = []
  let datadybde = 0
  let vaer: Vaerdag | null = null

  if (stasjon) {
    const [{ data: salg }, { data: v }] = await Promise.all([
      supabase
        .from('daglig_salg')
        .select('varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', stasjon.id)
        .eq('avdeling_kode', '120') // MAT
        .is('slettet_tid', null)
        .overrideTypes<SalgRad[]>(),
      supabase
        .from('vaer')
        .select('temp_maks, nedbor_mm')
        .eq('stasjon_id', stasjon.id)
        .eq('dato', dato)
        .maybeSingle<Vaerdag>(),
    ])
    vaer = v ?? null

    const dager = new Set<string>()
    const per = new Map<string, { navn: string; sum: number }>()
    for (const r of salg ?? []) {
      dager.add(r.dato)
      const key = r.varegruppe_kode ?? r.varegruppe_navn ?? '?'
      const p = per.get(key) ?? { navn: r.varegruppe_navn ?? '—', sum: 0 }
      p.sum += r.antall ?? 0
      per.set(key, p)
    }
    datadybde = dager.size || 1

    rader = [...per.values()]
      .map((p) => {
        const baseline = p.sum / datadybde
        const faktor = produksjonsfaktor(stasjon.stasjonstype, vaer, ukedag, p.navn)
        return { navn: p.navn, baseline, faktor, foreslatt: Math.round(baseline * faktor) }
      })
      .filter((r) => r.baseline > 0)
      .sort((a, b) => b.foreslatt - a.foreslatt)
  }

  return (
    <>
      <h1>Produksjonsplan</h1>
      <p className="undertittel">Forslag per varegruppe (MAT) for valgt dag</p>

      <section className="kort">
        <form method="get" className="plan-velg">
          <label className="felt">
            <span>Stasjon</span>
            <select name="butikknummer" defaultValue={valgtNr}>
              {(stasjoner ?? []).map((s) => (
                <option key={s.id} value={s.butikknummer}>{s.butikknummer} {s.navn}</option>
              ))}
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
            {vaer?.nedbor_mm != null && vaer.nedbor_mm > 0 ? `, ${vaer.nedbor_mm.toFixed(1)} mm` : ''}
            {' · baseline fra '}{datadybde} salgsdag{datadybde === 1 ? '' : 'er'}
          </p>
        )}
      </section>

      {rader.length === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen MAT-salgsdata for denne stasjonen ennå. Behandle en Salgsstatistikk-fil først.
          </p>
        </section>
      ) : (
        <section className="kort">
          <table className="tabell">
            <thead>
              <tr><th>Varegruppe</th><th>Baseline</th><th>Vær/dag-faktor</th><th>Foreslå produsert</th></tr>
            </thead>
            <tbody>
              {rader.map((r) => (
                <tr key={r.navn}>
                  <td>{r.navn}</td>
                  <td>{tall.format(Math.round(r.baseline))}</td>
                  <td>×{r.faktor.toFixed(2)}</td>
                  <td><strong>{tall.format(r.foreslatt)}</strong></td>
                </tr>
              ))}
            </tbody>
          </table>
          {datadybde < 14 && (
            <p className="undertittel" style={{ marginTop: '0.75rem' }}>
              ⚠ Tynt datagrunnlag ({datadybde} dag{datadybde === 1 ? '' : 'er'}). Vær-faktorene er
              standardverdier — motoren lærer stasjonens egen følsomhet når mer historikk er importert (§7).
            </p>
          )}
        </section>
      )}
    </>
  )
}
