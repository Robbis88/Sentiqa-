'use client'
import { useKvittering } from '@/components/ui/kvittering'
import type { Kvittering } from '@/lib/kvittering'
import { apneStottevindu, lukkStottevindu } from './handlinger'

// =====================================================================
// Åpner et støttevindu mot én kjede.
//
// BEGRUNNELSEN ER IKKE VALGFRI, og det er ikke en formalitet: den er det
// eneste i raden som forteller kunden hvorfor noen var inne. Feltet er
// påkrevd her, og basen krever det samme (`stotte_tilgang_begrunnelse_ekte`
// i 0196) — for et `required`-attributt er en visning, ikke en grense.
//
// Teksten over feltet sier at kunden ser den. Det er med vilje: den som
// vet at noen leser, skriver noe annet enn den som tror det forsvinner.
// =====================================================================

export function ApneStottevindu({ id, navn }: { id: string; navn: string }) {
  const [tilstand, handling, venter] = useKvittering<Kvittering, FormData>(apneStottevindu, undefined)

  return (
    <form action={handling} className="skjema">
      <input type="hidden" name="id" value={id} />
      <p className="undertittel">
        Åpner tilgang til {navn} i et begrenset vindu. Begrunnelsen og tidspunktet
        vises for kunden i deres egen logg.
      </p>

      <label className="felt">
        <span>Hvorfor (minst 10 tegn — kunden leser denne)</span>
        <textarea
          name="begrunnelse"
          required
          minLength={10}
          rows={3}
          placeholder="F.eks. «Importen fra 09.09 mangler to dager — sjekker inntaksloggen.»"
        />
      </label>

      <label className="felt">
        <span>Varighet</span>
        <select name="timer" defaultValue="1">
          <option value="1">1 time</option>
          <option value="4">4 timer</option>
          <option value="8">8 timer</option>
        </select>
      </label>

      {tilstand?.ok ? <p className="ok" role="status">{tilstand.ok}</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter} className="primar">
        {venter ? 'Åpner …' : 'Åpne støttetilgang'}
      </button>
    </form>
  )
}

/** Lukker et åpent vindu før tiden. Den som er ferdig, skal kunne si det. */
export function LukkStottevindu({ tilgangId }: { tilgangId: string }) {
  const [tilstand, handling, venter] = useKvittering<Kvittering, FormData>(lukkStottevindu, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="tilgang_id" value={tilgangId} />
      <button type="submit" disabled={venter} className="sq-knapp">
        {venter ? 'Lukker …' : 'Lukk nå'}
      </button>
      {tilstand?.feil ? <span className="feil" role="alert">{tilstand.feil}</span> : null}
    </form>
  )
}
