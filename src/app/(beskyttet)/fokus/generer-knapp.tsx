'use client'
import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { generer } from './handlinger'

export function GenererKnapp() {
  const [venter, start] = useTransition()
  // Oppdateringen skjer HER, etter at svaret er vist - ikke i
  // serverhandlingen. Se kvitteringsvakt.test.ts.
  const router = useRouter()
  const [melding, setMelding] = useState<string | null>(null)

  return (
    <div className="generer">
      <button
        type="button"
        disabled={venter}
        onClick={() =>
          start(async () => {
            const res = await generer()
            setMelding(
              res.ok
                ? `Genererte ${res.antall} fokuspunkter.`
                : `Kunne ikke generere: ${res.grunn}`,
            )
            router.refresh()
          })
        }
      >
        {venter ? <><span className="spinner" />Genererer …</> : 'Generer fokuspunkter'}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
