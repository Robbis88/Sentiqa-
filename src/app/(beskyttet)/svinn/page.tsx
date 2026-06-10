import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
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
  if (!erLeder(bruker.rolle)) {
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

  // Rullende 30-dagers vindu for svinn% mot terskel (§11: ikke dag-for-dag).
  const slutt = siste.dato
  const startD = new Date(slutt)
  startD.setDate(startD.getDate() - 29)
  const start = startD.toISOString().slice(0, 10)

  const [{ data: rader }, { data: stasjoner }, { data: svinnVindu }, { data: matVindu }] = await Promise.all([
    supabase
      .from('synlig_svinn')
      .select('stasjon_id, dato, ean, varenavn, antall, nettopris_total')
      .eq('dato', siste.dato)
      .overrideTypes<Svinn[]>(),
    supabase
      .from('stasjoner')
      .select('id, navn, butikknummer, svinnterskel_prosent')
      .is('slettet_tid', null)
      .order('butikknummer')
      .overrideTypes<{ id: string; navn: string; butikknummer: string; svinnterskel_prosent: number | null }[]>(),
    supabase.from('synlig_svinn').select('stasjon_id, nettopris_total').gte('dato', start).lte('dato', slutt).overrideTypes<{ stasjon_id: string; nettopris_total: number | null }[]>(),
    supabase.from('v_salg_per_stasjon_dag').select('stasjon_id, mat_omsetning').gte('dato', start).lte('dato', slutt).overrideTypes<{ stasjon_id: string; mat_omsetning: number | null }[]>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Svinn% = synlig svinn / matsalg i vinduet, mot terskel per stasjon.
  const svinnSum = new Map<string, number>()
  for (const r of svinnVindu ?? []) svinnSum.set(r.stasjon_id, (svinnSum.get(r.stasjon_id) ?? 0) + (r.nettopris_total ?? 0))
  const matSum = new Map<string, number>()
  for (const r of matVindu ?? []) matSum.set(r.stasjon_id, (matSum.get(r.stasjon_id) ?? 0) + (r.mat_omsetning ?? 0))
  const terskelrader = (stasjoner ?? []).map((s) => {
    const svinn = svinnSum.get(s.id) ?? 0
    const mat = matSum.get(s.id) ?? 0
    const pst = mat > 0 ? (svinn / mat) * 100 : null
    const terskel = s.svinnterskel_prosent
    let klasse = 'gul'
    if (pst == null || terskel == null) klasse = ''
    else if (pst <= terskel) klasse = 'gronn'
    else if (pst <= terskel * 1.25) klasse = 'gul'
    else klasse = 'rod'
    return { navn: `${s.butikknummer} ${s.navn}`, pst, terskel, klasse, svinn, mat }
  })
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
        <h2>Svinn mot terskel · siste 30 dager</h2>
        <p className="undertittel">Synlig svinn i % av matsalg, mot terskel per stasjon (§11).</p>
        <table className="tabell">
          <thead><tr><th>Stasjon</th><th>Svinn %</th><th>Terskel</th><th>Status</th></tr></thead>
          <tbody>
            {terskelrader.map((r) => (
              <tr key={r.navn}>
                <td>{r.navn}</td>
                <td>{r.pst != null ? `${r.pst.toFixed(1)} %` : '—'}</td>
                <td>{r.terskel != null ? `${r.terskel} %` : '—'}</td>
                <td>
                  {r.klasse ? (
                    <span className={`status-pip ${r.klasse}`}>
                      {r.klasse === 'gronn' ? 'Under terskel' : r.klasse === 'gul' ? 'Følg med' : 'Over terskel'}
                    </span>
                  ) : (
                    '—'
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="kort">
        <h2>Per stasjon · {datoLang.format(new Date(siste.dato))}</h2>
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
