'use client'
import { useActionState } from 'react'
import { loggInn, type InnloggingTilstand } from './handlinger'

export function InnloggingSkjema({ retur }: { retur?: string }) {
  const [tilstand, handling, venter] = useActionState<InnloggingTilstand, FormData>(
    loggInn,
    undefined,
  )

  return (
    <form action={handling} className="skjema">
      {retur ? <input type="hidden" name="retur" value={retur} /> : null}

      <label className="felt">
        <span>E-post</span>
        <input
          name="epost"
          type="email"
          autoComplete="email"
          required
          autoFocus
          placeholder="navn@firma.no"
        />
      </label>

      <label className="felt">
        <span>Passord</span>
        <input name="passord" type="password" autoComplete="current-password" required />
      </label>

      {tilstand?.feil ? (
        <p role="alert" className="feil">
          {tilstand.feil}
        </p>
      ) : null}

      <button type="submit" disabled={venter}>
        {venter ? 'Logger inn …' : 'Logg inn'}
      </button>
    </form>
  )
}
