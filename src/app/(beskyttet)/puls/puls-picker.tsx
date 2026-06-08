'use client'
import { useState } from 'react'
import { useActionState } from 'react'
import { giPuls, type PulsTilstand } from './handlinger'

const FJES = [
  { v: 1, e: '😣', t: 'Tungt' },
  { v: 2, e: '🙁', t: 'Så som så' },
  { v: 3, e: '😐', t: 'Greit' },
  { v: 4, e: '🙂', t: 'Bra' },
  { v: 5, e: '😄', t: 'Topp' },
]

export function PulsPicker({
  stasjoner,
  kreverStasjon,
}: {
  stasjoner: { id: string; navn: string }[]
  kreverStasjon: boolean
}) {
  const [valgt, setValgt] = useState<number | null>(null)
  const [tilstand, handling, venter] = useActionState<PulsTilstand, FormData>(giPuls, undefined)

  if (tilstand?.ok) {
    return <p className="ok puls-takk">Takk! Pulsen din er registrert. 💙</p>
  }

  return (
    <form action={handling} className="puls-form">
      <input type="hidden" name="humor" value={valgt ?? ''} />
      <div className="puls-faces">
        {FJES.map((f) => (
          <button
            type="button"
            key={f.v}
            className={`puls-face ${valgt === f.v ? 'valgt' : ''}`}
            onClick={() => setValgt(f.v)}
            aria-label={f.t}
          >
            <span className="puls-emoji">{f.e}</span>
            <span className="puls-tekst">{f.t}</span>
          </button>
        ))}
      </div>

      {kreverStasjon && (
        <select name="stasjon_id" required defaultValue={stasjoner.length === 1 ? stasjoner[0].id : ''}>
          {stasjoner.length !== 1 && <option value="" disabled>Velg stasjon …</option>}
          {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
        </select>
      )}

      <textarea name="kommentar" rows={2} placeholder="Valgfri kommentar (anonym for ledelsen)" />
      <button type="submit" disabled={venter || !valgt}>{venter ? 'Sender …' : 'Send puls'}</button>
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
