import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar } from '@/lib/format'
import type { Analyse } from '@/lib/ai/regnskapsanalyse'
import { AnalyseKnapp } from './generer-knapp'

const STATUS_TEKST: Record<string, string> = { gronn: 'God', gul: 'Følg med', rod: 'Krever tiltak' }

export default async function AnalyseSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til regnskapsanalysen.</p>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('regnskapsanalyser')
    .select('periode, rapport, opprettet_tid')
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string; rapport: Analyse; opprettet_tid: string }>()

  const a = data?.rapport

  return (
    <>
      <h1>Regnskapsanalyse</h1>
      <p className="undertittel">
        {data ? `${manedAar.format(new Date(data.periode))} · eier-analyse` : 'Ingen analyse ennå'}
      </p>

      <AnalyseKnapp />

      {!a ? (
        <section className="kort">
          <p className="undertittel">
            Ingen analyse ennå. Behandle et regnskap og trykk «Kjør analyse».
          </p>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>Sammendrag</h2>
            <p>{a.sammendrag}</p>
          </section>

          <section className="kort">
            <h2>Per stasjon</h2>
            <table className="tabell">
              <thead>
                <tr><th>Stasjon</th><th>Status</th><th>Kommentar</th></tr>
              </thead>
              <tbody>
                {a.perStasjon.map((s, i) => (
                  <tr key={i}>
                    <td>{s.stasjon}</td>
                    <td><span className={`status-pip ${s.status}`}>{STATUS_TEKST[s.status] ?? s.status}</span></td>
                    <td>{s.kommentar}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          {a.rodeFlagg.length > 0 && (
            <section className="kort oppmerksomhet">
              <h2>Røde flagg</h2>
              <ul>{a.rodeFlagg.map((f, i) => <li key={i}>{f}</li>)}</ul>
            </section>
          )}

          <section className="kort">
            <h2>Muligheter</h2>
            <ul className="fokus-liste">{a.muligheter.map((m, i) => <li key={i}>{m}</li>)}</ul>
          </section>

          <section className="kort">
            <h2>Prioriterte tiltak</h2>
            <ol className="tiltak-liste">{a.tiltak.map((t, i) => <li key={i}>{t}</li>)}</ol>
          </section>
        </>
      )}
    </>
  )
}
