'use client'
import { useActionState } from 'react'
import { lagreFrist, slettPerson, type Tilstand } from './handlinger'

function Svar({ tilstand }: { tilstand: Tilstand }) {
  if (tilstand?.ok) return <span className="ok" role="status">{tilstand.ok}.</span>
  if (tilstand?.feil) return <span className="feil" role="alert">{tilstand.feil}</span>
  return null
}

export function FristSkjema({ naa }: { naa: number }) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(lagreFrist, undefined)
  return (
    <form action={handling} className="sq-skjema">
      <label className="felt sq-smalt">
        <span>Måneder etter siste aktivitet</span>
        <input type="number" name="maaneder" defaultValue={naa} min={12} max={240} required />
      </label>
      <div className="knapperad">
        <button type="submit" className="liten" disabled={venter}>
          {venter ? 'Lagrer …' : 'Lagre'}
        </button>
        <Svar tilstand={tilstand} />
      </div>
    </form>
  )
}

/**
 * Sletting av én person.
 *
 * Navnet må skrives inn på nytt. Det er ikke pynt: sletting er endelig,
 * og en knapp med «er du sikker?» er noe man klikker bort. Å skrive
 * «Alida Nordmann» er en handling man ikke gjør ved et uhell.
 */
export function SlettSkjema(
  { stasjonId, ansattNr, navn }: { stasjonId: string; ansattNr: string; navn: string },
) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(slettPerson, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <div className="knapperad">
        <input
          name="bekreft"
          aria-label={`Skriv ${navn} for å bekrefte sletting`}
          placeholder={navn}
          style={{ width: '11rem' }}
          disabled={venter}
          required
        />
        <button type="submit" className="liten" disabled={venter}>
          {venter ? 'Sletter …' : 'Slett'}
        </button>
      </div>
      <Svar tilstand={tilstand} />
    </form>
  )
}
