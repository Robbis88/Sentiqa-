'use client'
import { useState, useTransition } from 'react'
import { behandleAlle } from '@/lib/import/behandle'

// Behandler hele 'mottatt'-køen i ett klikk. Feil-isolasjon skjer på server
// (én fil stopper ikke resten); her viser vi bare fremdrift + resultat.
export function BehandleAlleKnapp({ antall }: { antall: number }) {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)
  if (antall === 0) return null
  return (
    <div className="generer">
      <button
        type="button"
        disabled={venter}
        onClick={() =>
          start(async () => {
            setMelding(null)
            const res = await behandleAlle()
            setMelding(`Ferdig: ${res.ok} behandlet${res.feil ? `, ${res.feil} feilet (se status)` : ''}.`)
          })
        }
      >
        {venter ? <><span className="spinner" />Behandler {antall} fil(er) …</> : `Behandle alle (${antall})`}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
