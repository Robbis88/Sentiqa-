import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { datoLang } from '@/lib/format'
import { PulsPicker } from './puls-picker'

type Svar = { stasjon_id: string; dato: string; humor: number; kommentar: string | null }

const EMOJI = ['', '😣', '🙁', '😐', '🙂', '😄']
function emojiFor(snitt: number): string {
  return EMOJI[Math.max(1, Math.min(5, Math.round(snitt)))]
}
const dag = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', weekday: 'short', day: 'numeric', month: 'short' })

export default async function PulsSide() {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  const aktivAnsatt = await lesAktivAnsatt()
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const { data: stasjoner } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer')

  // Leder ser aggregat siste 14 dager (RLS gir kun leder lesetilgang)
  let snittDager: { dato: string; snitt: number; antall: number }[] = []
  let kommentarer: { dato: string; humor: number; kommentar: string }[] = []
  let snittIdag: number | null = null
  if (erLeder) {
    const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
    const fra = new Date(idag); fra.setDate(fra.getDate() - 13)
    const { data } = await supabase
      .from('puls_svar')
      .select('stasjon_id, dato, humor, kommentar')
      .gte('dato', fra.toISOString().slice(0, 10))
      .order('dato')
      .overrideTypes<Svar[]>()
    const perDag = new Map<string, number[]>()
    for (const s of data ?? []) {
      const l = perDag.get(s.dato) ?? []
      l.push(s.humor)
      perDag.set(s.dato, l)
      if (s.kommentar) kommentarer.push({ dato: s.dato, humor: s.humor, kommentar: s.kommentar })
    }
    snittDager = [...perDag.entries()].map(([dato, hs]) => ({ dato, snitt: hs.reduce((a, b) => a + b, 0) / hs.length, antall: hs.length }))
    snittIdag = perDag.has(idag) ? perDag.get(idag)!.reduce((a, b) => a + b, 0) / perDag.get(idag)!.length : null
    kommentarer = kommentarer.reverse().slice(0, 10)
  }

  return (
    <>
      <h1>Puls</h1>
      <p className="undertittel">Hvordan står det til på jobb i dag?</p>

      <section className="kort">
        <h2>Gi din puls</h2>
        {!aktivAnsatt && !erLeder ? (
          <p className="undertittel">Logg på vakt med PIN øverst først, så registreres pulsen din.</p>
        ) : (
          <PulsPicker
            stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))}
            kreverStasjon={!aktivAnsatt}
          />
        )}
      </section>

      {erLeder && (
        <>
          <section className="nokkeltall">
            <div className="kpi">
              <span className="kpi-tall">{snittIdag != null ? `${emojiFor(snittIdag)} ${snittIdag.toFixed(1)}` : '—'}</span>
              <span className="kpi-merke">Snitt i dag</span>
            </div>
            <div className="kpi">
              <span className="kpi-tall">{snittDager.length ? (snittDager.reduce((a, d) => a + d.snitt, 0) / snittDager.length).toFixed(1) : '—'}</span>
              <span className="kpi-merke">Snitt siste 14 dager</span>
            </div>
          </section>

          <section className="kort">
            <h2>Trend (14 dager)</h2>
            {snittDager.length === 0 ? (
              <p className="undertittel">Ingen puls registrert ennå.</p>
            ) : (
              <table className="tabell">
                <thead><tr><th>Dag</th><th>Snitt</th><th>Svar</th></tr></thead>
                <tbody>
                  {snittDager.map((d) => (
                    <tr key={d.dato}>
                      <td>{dag.format(new Date(d.dato))}</td>
                      <td>{emojiFor(d.snitt)} {d.snitt.toFixed(1)}</td>
                      <td>{d.antall}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>

          {kommentarer.length > 0 && (
            <section className="kort">
              <h2>Anonyme kommentarer</h2>
              <ul className="puls-kommentarer">
                {kommentarer.map((k, i) => (
                  <li key={i}>
                    <span className="puls-emoji-liten">{EMOJI[k.humor]}</span>
                    <span>{k.kommentar}</span>
                    <span className="undertittel"> · {datoLang.format(new Date(k.dato))}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </>
  )
}
