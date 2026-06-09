import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { beregnRutinestat, type Rutinestat } from '@/lib/rutinestat'

const MEDALJE = ['🥇', '🥈', '🥉']
function prosentKlasse(p: number) {
  return p >= 90 ? 'gronn' : p >= 70 ? 'gul' : 'rod'
}

export default async function RutineOversikt() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Kun eier/butikksjef har tilgang til oversikten.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const { data: stasjoner } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer')

  const rader: { navn: string; stat: Rutinestat }[] = await Promise.all(
    (stasjoner ?? []).map(async (s) => ({
      navn: `${s.butikknummer} ${s.navn}`,
      stat: await beregnRutinestat(supabase, s.id, idag),
    })),
  )
  rader.sort((a, b) => b.stat.prosent - a.stat.prosent)

  return (
    <>
      <h1>Rutiner — oversikt</h1>
      <p className="undertittel">Gjennomføring siste 30 dager · rangering 🏆 · streak 🔥</p>

      {rader.length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen stasjoner ennå.</p></section>
      ) : (
        rader.map((r, i) => (
          <section className="kort rangering-kort" key={r.navn}>
            <div className="rangering-topp">
              <span className="rangering-plass">{MEDALJE[i] ?? `#${i + 1}`}</span>
              <strong>{r.navn}</strong>
              <span className={`status-pip ${prosentKlasse(r.stat.prosent)}`}>{r.stat.prosent}%</span>
              {r.stat.streak > 0 && <span className="streak">🔥 {r.stat.streak} dager</span>}
            </div>
            <p className="undertittel">
              {r.stat.utfort} av {r.stat.forventet} forventede rutiner gjennomført
            </p>
            {r.stat.toppUtforere.length > 0 && (
              <p className="undertittel">
                Topputførere: {r.stat.toppUtforere.map((t) => `${t.navn} (${t.antall})`).join(' · ')}
              </p>
            )}
          </section>
        ))
      )}
    </>
  )
}
