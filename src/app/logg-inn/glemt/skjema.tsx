'use client'
import { useActionState } from 'react'
import Link from 'next/link'
import { sendGlemtLenke, type GlemtTilstand } from './handlinger'

export function GlemtSkjema({ epost }: { epost?: string }) {
  const [tilstand, handling, venter] = useActionState<GlemtTilstand, FormData>(
    sendGlemtLenke,
    undefined,
  )

  // KVITTERINGEN ERSTATTER SKJEMAET. Står feltet igjen under en melding
  // om at lenken er sendt, er det neste man gjør å trykke en gang til —
  // og da er man i ratebegrensningen som gjør at den FØRSTE lenken var
  // den siste som kom fram.
  // `.skjema` er en flex-spalte med luft mellom barna, ikke noe
  // skjema-spesifikt. Uten den klistret kvitteringen og veien tilbake
  // seg til hverandre, og de to leste som én blokk tekst.
  if (tilstand?.ok) {
    return (
      <div className="skjema">
        <p className="ok" role="status">{tilstand.ok}</p>
        <p className="undertittel"><Link href="/logg-inn">Tilbake til innlogging</Link></p>
      </div>
    )
  }

  return (
    <form action={handling} className="skjema">
      <label className="felt">
        <span>E-post</span>
        <input
          name="epost"
          type="email"
          autoComplete="email"
          required
          autoFocus
          defaultValue={epost}
          placeholder="navn@firma.no"
        />
      </label>

      {tilstand?.feil ? <p role="alert" className="feil">{tilstand.feil}</p> : null}

      <button type="submit" disabled={venter} className="primar">
        {venter ? 'Sender …' : 'Send meg en lenke'}
      </button>
      <p className="undertittel"><Link href="/logg-inn">Tilbake til innlogging</Link></p>
    </form>
  )
}
