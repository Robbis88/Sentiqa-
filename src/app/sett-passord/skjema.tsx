'use client'
import { useActionState } from 'react'
import { settPassord, type SettTilstand } from './handlinger'

export function SettPassordSkjema() {
  const [tilstand, handling, venter] = useActionState<SettTilstand, FormData>(settPassord, undefined)
  return (
    <form action={handling} className="skjema">
      <label className="felt">
        <span>Nytt passord</span>
        <input name="passord" type="password" autoComplete="new-password" required autoFocus minLength={8} />
      </label>
      <label className="felt">
        <span>Gjenta passord</span>
        <input name="passord2" type="password" autoComplete="new-password" required minLength={8} />
      </label>
      {tilstand?.feil ? <p role="alert" className="feil">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter} className="primar">{venter ? 'Lagrer …' : 'Sett passord og logg inn'}</button>
    </form>
  )
}
