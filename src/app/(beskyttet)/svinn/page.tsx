import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, datoLang } from '@/lib/format'

type Svinn = {
  stasjon_id: string
  dato: string | null
  ean: string | null
  varenavn: string | null
  antall: number | null
  nettopris_total: number | null
}

export default async function SvinnSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til svinn.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('synlig_svinn')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  if (!siste?.dato) {
    return (
      <>
        <h1>Synlig svinn</h1>
        <p className="undertittel">
          Ingen svinndata ennå. Last opp en Varetransaksjonsliste under Import.
        </p>
      </>
    )
  }

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('synlig_svinn')
      .select('stasjon_id, dato, ean, varenavn, antall, nettopris_total')
      .eq('dato', siste.dato)
      .overrideTypes<Svinn[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const alle = rader ?? []
  const total = alle.reduce((a, r) => a + (r.nettopris_total ?? 0), 0)

  // Per stasjon
  const perStasjon = new Map<string, { sum: number; antall: number }>()
  for (const r of alle) {
    const p = perStasjon.get(r.stasjon_id) ?? { sum: 0, antall: 0 }
    p.sum += r.nettopris_total ?? 0
    p.antall += r.antall ?? 0
    perStasjon.set(r.stasjon_id, p)
  }
  const stasjonsrader = [...perStasjon.entries()].sort((a, b) => b[1].sum - a[1].sum)

  // Topp varer (på tvers)
  const perVare = new Map<string, { navn: string; sum: number; antall: number }>()
  for (const r of alle) {
    const key = r.ean ?? r.varenavn ?? '?'
    const v = perVare.get(key) ?? { navn: r.varenavn ?? '—', sum: 0, antall: 0 }
    v.sum += r.nettopris_total ?? 0
    v.antall += r.antall ?? 0
    perVare.set(key, v)
  }
  const toppVarer = [...perVare.values()].sort((a, b) => b.sum - a.sum).slice(0, 10)

  return (
    <>
      <h1>Synlig svinn</h1>
      <p className="undertittel">{datoLang.format(new Date(siste.dato))}</p>

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(total)}</span>
          <span className="kpi-merke">Synlig svinn totalt</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(alle.reduce((a, r) => a + (r.antall ?? 0), 0))}</span>
          <span className="kpi-merke">Antall enheter</span>
        </div>
      </section>

      <section className="kort">
        <h2>Per stasjon</h2>
        <table className="tabell">
          <thead><tr><th>Stasjon</th><th>Svinn</th><th>Enheter</th></tr></thead>
          <tbody>
            {stasjonsrader.map(([id, p]) => (
              <tr key={id}>
                <td>{navnFor.get(id) ?? '—'}</td>
                <td>{kr.format(p.sum)}</td>
                <td>{tall.format(p.antall)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="kort">
        <h2>Mest svinn (varer)</h2>
        <table className="tabell">
          <thead><tr><th>Vare</th><th>Svinn</th><th>Enheter</th></tr></thead>
          <tbody>
            {toppVarer.map((v, i) => (
              <tr key={i}>
                <td>{v.navn}</td>
                <td>{kr.format(v.sum)}</td>
                <td>{tall.format(v.antall)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}
