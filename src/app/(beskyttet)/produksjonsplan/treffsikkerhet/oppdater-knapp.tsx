'use client'
import { useState, useTransition } from 'react'
import { oppdaterTreffsikkerhet } from './handlinger'

// Kjører backtesten på nytt på forespørsel. Tung jobb (kjører motorene over ~60
// dager × alle stasjoner) — derfor tydelig «kjører»-tilstand.
export function OppdaterKnapp() {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
      <button
        type="button"
        disabled={venter}
        onClick={() => start(async () => {
          setMelding(null)
          const r = await oppdaterTreffsikkerhet()
          setMelding(r.ok ? `✓ Oppdatert for ${r.stasjoner} stasjon(er).` : `Feil: ${r.feil}`)
        })}
      >
        {venter ? 'Kjører backtest…' : '↻ Oppdater treffsikkerhet'}
      </button>
      {melding && <span className="undertittel">{melding}</span>}
    </div>
  )
}
