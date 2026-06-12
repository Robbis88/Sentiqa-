'use client'
import { useFormStatus } from 'react-dom'

// Submit-knapp som viser spinner + «Behandler …» mens server-handlingen kjører
// (regnskap utløser tung AI-analyse → kan ta litt tid).
export function BehandleKnapp({ tekst }: { tekst: string }) {
  const { pending } = useFormStatus()
  return (
    <button type="submit" className="liten" disabled={pending}>
      {pending ? <><span className="spinner" />Behandler …</> : tekst}
    </button>
  )
}
