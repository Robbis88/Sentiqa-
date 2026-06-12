'use client'
import { useState, useTransition } from 'react'
import { generer } from './handlinger'

export function GenererKnapp() {
  const [venter, start] = useTransition()
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
          })
        }
      >
        {venter ? <><span className="spinner" />Genererer …</> : 'Generer fokuspunkter'}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
