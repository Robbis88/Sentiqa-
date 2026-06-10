'use client'
import { useState } from 'react'
import { oppdaterVaer } from './handlinger'

export function VaerKnapp() {
  const [venter, setVenter] = useState(false)
  const [melding, setMelding] = useState<string | null>(null)

  function hent() {
    setVenter(true)
    setMelding(null)
    oppdaterVaer()
      .then((r) => setMelding(r.melding))
      .catch(() => setMelding('Noe gikk galt.'))
      .finally(() => setVenter(false))
  }

  return (
    <span className="vaer-knapp">
      <button type="button" className="liten" onClick={hent} disabled={venter}>
        {venter ? 'Henter vær …' : '🌤️ Hent vær nå'}
      </button>
      {melding && <span className="undertittel">{melding}</span>}
    </span>
  )
}
