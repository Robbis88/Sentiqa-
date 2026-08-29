'use client'
import { useKvittering } from '@/components/ui/kvittering'

import { bekreftLest, type Tilstand } from './handlinger'

/**
 * Bekreftelsen er IKKE et samtykke.
 *
 * Samtykke er sjelden gyldig i arbeidsforhold — den ansatte står ikke
 * fritt til å si nei. Dette dokumenterer at informasjonen er gitt, slik
 * aml. § 9-2 andre ledd krever, og teksten sier det rett ut. Å kalle det
 * samtykke ville gitt et inntrykk av valgfrihet som ikke finnes.
 */
export function BekreftSkjema({ versjon }: { versjon: string }) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(
    bekreftLest, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="versjon" value={versjon} />
      <div className="knapperad">
        <button type="submit" className="sq-knapp primar" disabled={venter}>
          {venter ? 'Lagrer …' : 'Jeg har lest dette'}
        </button>
        {tilstand?.ok && <span className="ok" role="status">{tilstand.ok}.</span>}
        {tilstand?.feil && <span className="feil" role="alert">{tilstand.feil}</span>}
      </div>
    </form>
  )
}
