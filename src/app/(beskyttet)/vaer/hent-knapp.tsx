'use client'
import { useState, useTransition } from 'react'
import { hentVaer } from './handlinger'

export function HentKnapp() {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)

  return (
    <div className="generer">
      <button
        type="button"
        disabled={venter}
        onClick={() =>
          start(async () => {
            const res = await hentVaer()
            setMelding(
              res.ok
                ? `Hentet vær for ${res.stasjoner} stasjon(er) (${res.antall} dager).`
                : `Kunne ikke hente: ${res.grunn}`,
            )
          })
        }
      >
        {venter ? 'Henter vær …' : 'Hent vær'}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
