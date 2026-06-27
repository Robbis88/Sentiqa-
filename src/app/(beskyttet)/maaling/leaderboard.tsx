import { kr, tall } from '@/lib/format'
import type { MalekortResultat } from '@/lib/malekort'

const MEDALJE = ['🥇', '🥈', '🥉']

function formater(verdi: number, enhet: string): string {
  if (enhet === 'pst') return `${verdi >= 0 ? '+' : '−'}${Math.abs(verdi).toFixed(1)} %`
  if (enhet === 'antall') return tall.format(Math.round(verdi))
  return kr.format(Math.round(verdi))
}

// Rangering for ett målekort. Gjenbruker .rang-*-stilene fra stasjonsrangering.
export function Leaderboard({ resultat }: { resultat: MalekortResultat }) {
  if (!resultat.klar) return <p className="undertittel">⏳ {resultat.grunn}</p>
  if (resultat.rader.length === 0) return <p className="undertittel">Ingen tall i perioden.</p>

  return (
    <>
      <p className="malekort-periode">{resultat.etikett}</p>
      <ol className="rang-rader">
        {resultat.rader.map((r, i) => (
          <li key={r.stasjonId}>
            <span className="rang-badge">{MEDALJE[i] ?? i + 1}</span>
            <span className="rang-navn">{r.navn}</span>
            <span className="rang-tall">
              <span className="rang-verdi">{formater(r.verdi, resultat.enhet)}</span>
              {r.vekstPst != null && (
                <span className={`rang-avvik ${r.vekstPst >= 0 ? 'gronn' : 'rod'}`}>
                  {r.vekstPst >= 0 ? '▲ +' : '▼ −'}{Math.abs(r.vekstPst).toFixed(1)} % mot i fjor
                </span>
              )}
            </span>
          </li>
        ))}
      </ol>
    </>
  )
}
