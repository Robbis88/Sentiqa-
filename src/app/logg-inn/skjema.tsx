'use client'
import { useActionState, useState } from 'react'
import Link from 'next/link'
import { loggInn, type InnloggingTilstand } from './handlinger'

export function InnloggingSkjema({ retur }: { retur?: string }) {
  const [tilstand, handling, venter] = useActionState<InnloggingTilstand, FormData>(
    loggInn,
    undefined,
  )
  // Adressen følger med til glemt-passord-siden, så den ikke skal tastes
  // to ganger. Den er ikke en hemmelighet — brukeren skrev den nettopp.
  //
  // FELTET ER FORTSATT UKONTROLLERT, med vilje. Et `value` her ville gjort
  // innloggingen avhengig av at React får med seg hver endring — og en
  // passordbehandler som fyller ut feltet uten å utløse en hendelse ville
  // da fått verdien overskrevet av tom state ved neste render. Prisen er
  // at autofyll ikke gir forhåndsutfylling videre. Det er en lenke som
  // mangler et hint, ikke en innlogging som ryker.
  const [epost, settEpost] = useState('')

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
          onChange={(e) => settEpost(e.target.value)}
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

      <button type="submit" disabled={venter} className="primar">
        {venter ? 'Logger inn …' : 'Logg inn'}
      </button>

      {/* STÅR UNDER KNAPPEN, IKKE VED SIDEN AV PASSORDFELTET. Over
          knappen konkurrerer den med det man kom for å gjøre; under
          den er den der først når det man kom for ikke virket. */}
      <p className="undertittel">
        <Link href={epost ? `/logg-inn/glemt?epost=${encodeURIComponent(epost)}` : '/logg-inn/glemt'}>
          Glemt passord?
        </Link>
      </p>
    </form>
  )
}
