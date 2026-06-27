'use client'
import Link from 'next/link'
import { useActionState } from 'react'
import { registrer, type RegTilstand } from './handlinger'

export function RegistrerSkjema() {
  const [tilstand, handling, venter] = useActionState<RegTilstand, FormData>(registrer, undefined)

  return (
    <form action={handling} className="skjema">
      <label className="felt">
        <span>Firmanavn</span>
        <input name="firma" placeholder="Kelsar Bil AS" required autoFocus />
      </label>
      <label className="felt">
        <span>Organisasjonsnummer</span>
        <input name="org_nr" inputMode="numeric" placeholder="123456789" required />
      </label>
      <label className="felt">
        <span>Ditt navn</span>
        <input name="fullt_navn" placeholder="Robert" required />
      </label>
      <label className="felt">
        <span>E-post</span>
        <input name="epost" type="email" autoComplete="email" placeholder="navn@firma.no" required />
      </label>
      <label className="felt">
        <span>Passord (min. 8 tegn)</span>
        <input name="passord" type="password" autoComplete="new-password" required />
      </label>

      <label className="felt-avkrysning">
        <input type="checkbox" name="dpa" value="ja" required />
        <span>
          Jeg har lest og godtar <Link href="/databehandleravtale" target="_blank">databehandleravtalen</Link> og{' '}
          <Link href="/personvern" target="_blank">personvernerklæringen</Link>.
        </span>
      </label>

      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}

      <button type="submit" disabled={venter}>{venter ? 'Oppretter …' : 'Opprett konto'}</button>
    </form>
  )
}
