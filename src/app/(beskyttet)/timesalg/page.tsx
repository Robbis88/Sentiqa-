import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'

type Rad = { stasjon_id: string; time: string; salg: number | null }

function startTime(t: string): number {
  return Number.parseInt(t.split('-')[0], 10) || 0
}

export default async function TimesalgSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til timesalg.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('timesalg')
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()

  if (!siste) {
    return (
      <>
        <h1>Timesalg</h1>
        <p className="undertittel">
          Ingen timesalgsdata ennå. Last opp en SalesPerHour-fil under Import.
        </p>
      </>
    )
  }

  const [{ data: rader }, { data: stasjoner }] = await Promise.all([
    supabase.from('timesalg').select('stasjon_id, time, salg').eq('dato', siste.dato).overrideTypes<Rad[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const stasjonsliste = (stasjoner ?? []).filter((s) =>
    (rader ?? []).some((r) => r.stasjon_id === s.id),
  )
  const timer = [...new Set((rader ?? []).map((r) => r.time))].sort((a, b) => startTime(a) - startTime(b))

  // Pivot + maks for fargeintensitet
  const verdi = new Map<string, number>() // `${stasjon}|${time}` → salg
  let maks = 0
  for (const r of rader ?? []) {
    const v = r.salg ?? 0
    verdi.set(`${r.stasjon_id}|${r.time}`, v)
    if (v > maks) maks = v
  }
  const sumPer = (id: string) =>
    timer.reduce((a, t) => a + (verdi.get(`${id}|${t}`) ?? 0), 0)

  return (
    <>
      <h1>Timesalg</h1>
      <p className="undertittel">{datoLang.format(new Date(siste.dato))} · salg pr time</p>

      <section className="kort">
        <div className="heatmap-wrap">
          <table className="heatmap">
            <thead>
              <tr>
                <th>Time</th>
                {stasjonsliste.map((s) => (
                  <th key={s.id}>{s.navn}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {timer.map((t) => (
                <tr key={t}>
                  <td className="time">{t}</td>
                  {stasjonsliste.map((s) => {
                    const v = verdi.get(`${s.id}|${t}`) ?? 0
                    const alpha = maks > 0 ? v / maks : 0
                    return (
                      <td
                        key={s.id}
                        style={{ background: `rgba(15, 108, 189, ${alpha.toFixed(3)})`, color: alpha > 0.5 ? '#fff' : 'inherit' }}
                      >
                        {v > 0 ? kr.format(v) : ''}
                      </td>
                    )
                  })}
                </tr>
              ))}
              <tr className="sum">
                <td className="time">Sum</td>
                {stasjonsliste.map((s) => (
                  <td key={s.id}>{kr.format(sumPer(s.id))}</td>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}
