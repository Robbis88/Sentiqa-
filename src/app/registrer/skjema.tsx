'use client'
import Link from 'next/link'
import { useActionState } from 'react'
import { registrer, type RegTilstand } from './handlinger'

// =====================================================================
// INGEN PASSORDFELT, OG DET ER POENGET
//
// Her sto det ett. Da satte serveren `email_confirm: true` og logget
// deg rett inn — altså markerte adressen som bekreftet uten å sende
// noe. Man kunne registrere seg på en adresse man ikke eier, og «glemt
// passord» gikk da til den ekte eieren.
//
// Nå kommer bekreftelsen på e-post, og passordet settes bak lenken i
// den. Ett felt mindre å fylle ut er ikke gevinsten — beviset er:
// du eier adressen fordi du fikk brevet.
//
// KVITTERINGEN ERSTATTER SKJEMAET når det har gått. En innsending som
// bare tømmer feltene ser ut som en som feilet, og neste handling blir
// å sende inn på nytt.
// =====================================================================

export function RegistrerSkjema() {
  const [tilstand, handling, venter] = useActionState<RegTilstand, FormData>(registrer, undefined)

  if (tilstand?.ok) {
    return (
      <div className="skjema" role="status">
        <h2>Sjekk e-posten din</h2>
        <p>{tilstand.ok}</p>
        <p className="dempet">
          Fant du den ikke? Se i søppelposten — den kommer fra Supabase på
          vegne av Sentiqa.
        </p>
      </div>
    )
  }

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

      <label className="felt-avkrysning">
        <input type="checkbox" name="dpa" value="ja" required />
        <span>
          Jeg har lest og godtar <Link href="/databehandleravtale" target="_blank">databehandleravtalen</Link> og{' '}
          <Link href="/personvern" target="_blank">personvernerklæringen</Link>.
        </span>
      </label>

      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}

      <p className="dempet">
        Vi sender en lenke til e-posten din for å bekrefte adressen. Passordet
        setter du der.
      </p>

      <button type="submit" disabled={venter} className="primar">
        {venter ? 'Oppretter …' : 'Opprett konto'}
      </button>
    </form>
  )
}
