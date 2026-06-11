'use client'
import { useState } from 'react'
import { kr } from '@/lib/format'
import type { VekstMetrikk } from '@/lib/tablethjem'

type Valg = 'samlet' | 'mat'
const VALG: { key: Valg; navn: string }[] = [
  { key: 'samlet', navn: 'Samlet' },
  { key: 'mat', navn: 'Mat' },
]

function Diff({ naa, ifjor }: { naa: number; ifjor: number }) {
  if (ifjor <= 0) return null
  const d = naa - ifjor
  const pst = Math.round((d / ifjor) * 1000) / 10
  const opp = d >= 0
  return (
    <span className={`vekst-diff ${opp ? 'opp' : 'ned'}`}>
      {opp ? '▲' : '▼'} {opp ? '+' : '−'}{Math.abs(pst)} % mot i fjor
    </span>
  )
}

export function VekstKort({ metrikker }: { metrikker: { samlet: VekstMetrikk; mat: VekstMetrikk } }) {
  const [valg, setValg] = useState<Valg>('samlet')
  const m = metrikker[valg]

  return (
    <section className="tablet-seksjon vekst-eng">
      <div className="vekst-eng-topp">
        <h2>📈 Vekst mot i fjor</h2>
        <div className="metrikk-bytte mork">
          {VALG.map((v) => (
            <button key={v.key} type="button" className={`metrikk-knapp ${valg === v.key ? 'aktiv' : ''}`} onClick={() => setValg(v.key)}>
              {v.navn}
            </button>
          ))}
        </div>
      </div>

      {m.streak > 0 && (
        <div className="vekst-streak-badge">🔥 {m.streak} {m.streak === 1 ? 'dag' : 'dager'} på rad over fjoråret!</div>
      )}

      <div className="vekst-tall-rad">
        <div className="vekst-celle">
          <span className="vekst-merke">I dag</span>
          <span className="vekst-tall">{kr.format(m.iDag)}</span>
          <Diff naa={m.iDag} ifjor={m.iFjor} />
        </div>
        <div className="vekst-celle">
          <span className="vekst-merke">Måneden hittil</span>
          <span className="vekst-tall">{kr.format(m.mtd)}</span>
          <Diff naa={m.mtd} ifjor={m.mtdIfjor} />
        </div>
      </div>
    </section>
  )
}
