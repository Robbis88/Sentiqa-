'use client'
import { useActionState } from 'react'
import { settStemplingskilde, type OvergangSvar } from './overgang'

// =====================================================================
// Å snu en stasjon over til stempling — eller tilbake.
//
// Knappen står i avstemmingskortet og ingen andre steder. Det er der man
// ser tallene som avgjør, og en knapp som flytter lønnsgrunnlaget for en
// hel stasjon skal ikke kunne trykkes uten dem foran seg.
//
// Veien TILBAKE er alltid åpen og har ingen vilkår. En nødbrems med
// betingelser er ingen nødbrems.
// =====================================================================

type Props = {
  stasjonId: string
  naavaerende: 'import' | 'tablet'
  ar: number
  maned: number
  /** Er avstemmingen ren? Sjekkes på nytt i handlingen. */
  klar: boolean
}

export function ByttKilde({ stasjonId, naavaerende, ar, maned, klar }: Props) {
  const [svar, handling, venter] =
    useActionState<OvergangSvar, FormData>(settStemplingskilde, undefined)

  const tilTablet = naavaerende === 'import'

  return (
    <form action={handling} className="rutine-form">
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="til" value={tilTablet ? 'tablet' : 'import'} />
      <input type="hidden" name="ar" value={ar} />
      <input type="hidden" name="maned" value={maned} />

      <button
        type="submit"
        className={tilTablet ? 'sq-knapp primar' : 'sq-knapp'}
        disabled={venter || (tilTablet && !klar)}
      >
        {venter
          ? 'Lagrer …'
          : tilTablet
            ? 'Sett stasjonen over til stempling'
            : 'Tilbake til easy@work'}
      </button>

      {tilTablet && !klar && (
        <span className="undertittel">
          Krever at avstemmingen er ren for måneden du ser på.
        </span>
      )}
      {!tilTablet && (
        <span className="undertittel">
          Timene fra stemplingen blir stående, men telles ikke.
        </span>
      )}
      {svar?.feil ? <span className="feil">{svar.feil}</span> : null}
      {svar?.ok ? <span className="ok">Lagret. Timene er regnet om.</span> : null}
    </form>
  )
}
