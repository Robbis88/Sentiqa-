'use client'
import { useEffect, useState } from 'react'
import { BOK, BOK_SUM } from './demo'
import { useRolig, useSynlig } from './bevegelse'

// =====================================================================
// SIGNAL-HOVEDBOKEN
//
// Alternativet var et diagram med piler fra VÆR, SALG, TRAFIKK … inn i
// en boks som het SENTIQA. Det er tegningen alle bruker, og den viser
// ingenting: den sier at systemet «kobler data», som er en påstand.
//
// Dette er formen tallene faktisk har. `RaaSignal` i lib/signaler.ts er
// en kilde, en måling og en verdi — og hver anbefaling bærer id-en til
// signalet den kommer fra. Linjene tenner én etter én og ender i
// forslaget, fordi det ER rekkefølgen: ingen handling uten et signal.
//
// En hovedbok i fast bredde er dessuten det en driftsleder kjenner
// igjen fra sine egne rapporter. Den ser ut som noe som er regnet ut,
// ikke som noe som er tegnet.
// =====================================================================

export function Signaler() {
  const { ref, synlig } = useSynlig<HTMLDivElement>(0.3)
  const rolig = useRolig()
  const [trinn, setTrinn] = useState(0)
  // Med ro står hele boka tent med en gang. Ellers følger den trappen.
  const tent = rolig ? BOK.length + 1 : trinn

  useEffect(() => {
    if (!synlig || rolig) return
    const t: ReturnType<typeof setTimeout>[] = []
    for (let i = 0; i <= BOK.length; i++) {
      t.push(setTimeout(() => setTrinn(i + 1), 140 * i))
    }
    return () => t.forEach(clearTimeout)
  }, [synlig, rolig])

  return (
    <section className="lp-seksjon">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Hvordan et forslag blir til</p>
        <h2 className="lp-h2">Ingen anbefaling uten et tall bak.</h2>
        <p className="lp-ingress">
          Hvert forslag bærer identiteten til signalet det kommer fra. Klarer ikke systemet
          å knytte en handling til et målt tall, foreslår det ingenting.
        </p>

        <div className="lp-bok" ref={ref}>
          {BOK.map((l, i) => (
            <p key={l.kilde} className={i < tent ? 'lp-bok-linje lp-paa' : 'lp-bok-linje'}>
              <span className="lp-bok-kilde">{l.kilde}</span>
              <span className="lp-bok-tekst">{l.tekst}</span>
              <span className="lp-bok-v">{l.verdi}</span>
            </p>
          ))}
          <p className={tent > BOK.length ? 'lp-bok-sum lp-paa' : 'lp-bok-sum'}>{BOK_SUM}</p>
        </div>
      </div>
    </section>
  )
}
