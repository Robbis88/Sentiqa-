import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { HentKnapp } from './hent-knapp'

type Vaer = {
  stasjon_id: string
  dato: string
  temp_maks: number | null
  temp_min: number | null
  nedbor_mm: number | null
}

const dag = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', weekday: 'short', day: 'numeric', month: 'short' })

export default async function VaerSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til vær.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  const fra = new Date(idag)
  fra.setDate(fra.getDate() - 4)
  const fraISO = fra.toISOString().slice(0, 10)

  const [{ data: vaer }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('vaer')
      .select('stasjon_id, dato, temp_maks, temp_min, nedbor_mm')
      .gte('dato', fraISO)
      .order('dato')
      .overrideTypes<Vaer[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perStasjon = new Map<string, Vaer[]>()
  for (const v of vaer ?? []) {
    const l = perStasjon.get(v.stasjon_id) ?? []
    l.push(v)
    perStasjon.set(v.stasjon_id, l)
  }

  return (
    <>
      <h1>Vær</h1>
      <p className="undertittel">Siste dager + 7 dagers varsel (Open-Meteo) · grunnlag for §7-analysene</p>

      {bruker.rolle === 'retailer_admin' && <HentKnapp />}

      {perStasjon.size === 0 ? (
        <section className="kort">
          <p className="undertittel">
            {bruker.rolle === 'retailer_admin'
              ? 'Ingen værdata ennå. Sett koordinater på stasjonene (Stasjoner) og trykk «Hent vær».'
              : 'Ingen værdata ennå.'}
          </p>
        </section>
      ) : (
        [...perStasjon.entries()].map(([sid, dager]) => (
          <section className="kort" key={sid}>
            <h2>{navnFor.get(sid) ?? '—'}</h2>
            <div className="heatmap-wrap">
              <table className="tabell">
                <thead>
                  <tr><th>Dag</th><th>Maks</th><th>Min</th><th>Nedbør</th></tr>
                </thead>
                <tbody>
                  {dager.map((v) => (
                    <tr key={v.dato} className={v.dato === idag ? 'idag' : ''}>
                      <td>{dag.format(new Date(v.dato))}{v.dato === idag ? ' · i dag' : v.dato > idag ? ' (varsel)' : ''}</td>
                      <td>{v.temp_maks != null ? `${v.temp_maks.toFixed(0)}°` : '—'}</td>
                      <td>{v.temp_min != null ? `${v.temp_min.toFixed(0)}°` : '—'}</td>
                      <td>{v.nedbor_mm != null ? `${v.nedbor_mm.toFixed(1)} mm` : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        ))
      )}
    </>
  )
}
