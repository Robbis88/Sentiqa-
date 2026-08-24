'use client'
import { useActionState } from 'react'
import { lastOppSignert, type Tilstand } from './handlinger'

/**
 * Last opp det signerte eksemplaret.
 *
 * Broen til BankID, ikke en erstatning for den: her er det et menneske
 * som bekrefter at papiret finnes, og systemet tar vare på det.
 */
export function SigneringSkjema(
  { kontraktId, iDag, alleredeSignert }:
  { kontraktId: string; iDag: string; alleredeSignert: boolean },
) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(
    lastOppSignert, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <input type="hidden" name="kontrakt_id" value={kontraktId} />
      <div className="sq-skjema-rad">
        <label className="felt sq-smalt">
          {/* Datoen hun faktisk skrev under, ikke datoen du rakk å laste
              opp. De er sjelden den samme, og det er den første som teller. */}
          <span>Signert dato</span>
          <input type="date" name="signert_dato" defaultValue={iDag} max={iDag} required />
        </label>
        <label className="felt">
          <span>Signert dokument (.pdf eller .docx)</span>
          <input type="file" name="fil" accept=".pdf,.docx" required />
        </label>
      </div>
      <div className="knapperad">
        <button type="submit" className="liten primar" disabled={venter}>
          {venter ? 'Laster opp …'
            : alleredeSignert ? 'Erstatt signert eksemplar' : 'Marker som signert'}
        </button>
        {tilstand?.ok && <span className="ok" role="status">{tilstand.ok}.</span>}
        {tilstand?.feil && <span className="feil" role="alert">{tilstand.feil}</span>}
      </div>
    </form>
  )
}
