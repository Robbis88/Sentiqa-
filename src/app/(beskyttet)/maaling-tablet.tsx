import { kr, tall } from '@/lib/format'
import type { TabletKort } from '@/lib/malekort'

const MEDALJE = ['🥇', '🥈', '🥉']

function formater(verdi: number, enhet?: string): string {
  if (enhet === 'pst') return `${verdi >= 0 ? '+' : '−'}${Math.abs(verdi).toFixed(1)} %`
  if (enhet === 'antall') return tall.format(Math.round(verdi))
  return kr.format(Math.round(verdi))
}

// Motiverende målekort-kort på tablet-hjem. Viser kun egen butikks stilling.
export function MalekortTablet({ kort }: { kort: TabletKort[] }) {
  const klare = kort.filter((k) => k.klar)
  if (klare.length === 0) return null

  return (
    <section className="tablet-seksjon maaling-tablet">
      <h2>🏆 Måling</h2>
      <div className="maaling-tablet-kort">
        {klare.map((k) => {
          const medalje = MEDALJE[(k.rang ?? 1) - 1] ?? `nr ${k.rang}`
          const opp = (k.vekstPst ?? 0) >= 0
          const unna = k.rang && k.rang > 1 && k.topp != null && k.verdi != null ? k.topp - k.verdi : null
          return (
            <div className="maaling-tablet-rad" key={k.navn}>
              <span className="mt-navn">{k.navn}</span>
              <span className="mt-rang">{medalje} <small>av {k.antall}</small></span>
              <span className="mt-verdi">{formater(k.verdi ?? 0, k.enhet)}</span>
              {k.vekstPst != null && (
                <span className={`mt-vekst ${opp ? 'gronn' : 'rod'}`}>
                  {opp ? '🔥 +' : '▼ −'}{Math.abs(k.vekstPst).toFixed(1)} % mot i fjor
                </span>
              )}
              {unna != null && unna > 0 && (
                <span className="mt-unna">{formater(unna, k.enhet)} til 1. plass</span>
              )}
            </div>
          )
        })}
      </div>
    </section>
  )
}
