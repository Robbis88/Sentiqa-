'use client'
import { useState, useTransition } from 'react'
import { generer } from './handlinger'

export function AnalyseKnapp() {
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
            setMelding(res.ok ? 'Analyse oppdatert.' : `Kunne ikke kjøre: ${res.grunn}`)
          })
        }
      >
        {venter ? <><span className="spinner" />Analyserer … (Opus, kan ta litt)</> : 'Kjør analyse'}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
