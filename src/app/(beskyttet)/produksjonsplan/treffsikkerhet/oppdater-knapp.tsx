'use client'
import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { oppdaterTreffsikkerhet } from './handlinger'

// Kjører backtesten på nytt på forespørsel. Tung jobb (kjører motorene over ~60
// dager × alle stasjoner) — derfor tydelig «kjører»-tilstand.
export function OppdaterKnapp() {
  const [venter, start] = useTransition()
  // Oppdateringen skjer HER, etter at svaret er vist - ikke i
  // serverhandlingen. Se kvitteringsvakt.test.ts.
  const router = useRouter()
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
          router.refresh()
        })}
      >
        {venter ? 'Kjører backtest…' : '↻ Oppdater treffsikkerhet'}
      </button>
      {melding && <span className="undertittel">{melding}</span>}
    </div>
  )
}
