'use client'
import { useActionState } from 'react'
import { checkInn, checkUt, type VaktTilstand } from './vakt-handlinger'

// =====================================================================
// Vakt: hvem holder nettbrettet nå.
//
// TO FELTER, IKKE ETT. Nummeret utpeker personen, PIN-en beviser at det
// er henne. Det er samme form som stemplingsskjemaet, og med vilje:
// hun taster de samme to tingene begge steder, og skal ikke måtte lære
// at det ene stedet holder det med PIN.
//
// PIN-FELTET ER MASKERT. Det sto i klartekst i toppstripa — i en butikk,
// ved siden av kolleger og kunder — mens det samme feltet på
// stemplingssida var maskert fra dag én. Feltet ble ikke skrevet av med
// vilje; det ble bare aldri sett på som en hemmelighet, fordi det var en
// identitet.
// =====================================================================

export function Vakt({ aktiv }: { aktiv: { id: string; navn: string } | null }) {
  const [tilstand, handling, venter] = useActionState<VaktTilstand, FormData>(checkInn, undefined)

  if (aktiv) {
    return (
      <div className="vakt">
        <span className="vakt-navn">{aktiv.navn}</span>
        <form action={checkUt}><button type="submit" className="liten primar">Logg av</button></form>
      </div>
    )
  }
  return (
    <form action={handling} className="vakt">
      <input
        name="ansatt_nr"
        inputMode="numeric"
        autoComplete="off"
        maxLength={10}
        placeholder="Nr"
        aria-label="Ansattnummer"
        className="vakt-nr"
      />
      <input
        name="pin"
        type="password"
        inputMode="numeric"
        autoComplete="off"
        maxLength={6}
        placeholder="PIN"
        aria-label="PIN"
        className="vakt-pin"
      />
      <button type="submit" className="liten primar" disabled={venter}>{venter ? '…' : 'Vakt'}</button>
      {tilstand?.feil ? <span className="vakt-feil" role="alert">{tilstand.feil}</span> : null}
    </form>
  )
}
