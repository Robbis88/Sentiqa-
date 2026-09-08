'use client'
import type { ReactNode } from 'react'
import { useFormStatus } from 'react-dom'

// =====================================================================
// RUTINEN SOM KREVER BILDE
//
// Robert: «samtidig så tuller bilder seg veldig. de må oppdatere
// nettleseren når det kreves bilde?»
//
// To feil, og begge var mine fra forrige runde.
//
// ---------------------------------------------------------------------
// 1. `required` PÅ ET USYNLIG FELT STOPPER HELE SKJEMAET
//
// Filfeltet ble gjemt så hele raden kunne være trykkflaten. Men det
// beholdt `required` — og et ugyldig felt nettleseren ikke kan vise,
// kan den heller ikke klage på. Chrome og Safari nekter da å sende
// skjemaet og skriver «an invalid form control is not focusable» i en
// konsoll ingen har åpen.
//
// Resultatet: du trykker «Lagre bilde», og ingenting skjer. Ikke en
// feilmelding, ikke en endring. Da laster man siden på nytt.
//
// Kravet er flyttet til serveren, som kan svare. Tom innsending er
// dessuten ikke en feil — det er en avbrutt handling.
//
// ---------------------------------------------------------------------
// 2. TO TRYKK DER ETT HOLDER
//
// Åpne kamera, ta bildet, og så finne en knapp. Skjemaet sender seg
// selv når bildet er valgt — `requestSubmit` og ikke `submit`, så
// React-handlingen kjøres i stedet for en vanlig postback.
//
// Knappen står igjen som synlig utvei. Den er ufarlig: utføringen
// lagres med `onConflict: rutine_id,dato`, så to innsendinger blir én
// rad.
// =====================================================================

/**
 * «Lagrer …» mens bildet går opp.
 *
 * ET BILDE ER TREGT NOK TIL AT STILLHET LESES SOM AT DET IKKE VIRKET.
 * Må ligge inne i `<form>` — `useFormStatus` leser nærmeste skjema over
 * seg, og utenfor er den alltid `false`.
 */
function Lagrer() {
  const { pending } = useFormStatus()
  if (!pending) return null
  return <span className="tr-lagrer" role="status">Lagrer bildet …</span>
}

export function BildeRad({
  handling, felt, kropp, etikett, lagreOrd,
}: {
  handling: (fd: FormData) => void | Promise<void>
  felt: ReactNode
  kropp: ReactNode
  etikett: string
  lagreOrd: string
}) {
  return (
    <form action={handling} className="tr-form">
      {felt}
      <label className="tr-trykk">
        {kropp}
        <input
          type="file"
          name="bilde"
          accept="image/*"
          capture="environment"
          className="tr-fil"
          aria-label={etikett}
          onChange={(e) => {
            if (e.currentTarget.files?.length) e.currentTarget.form?.requestSubmit()
          }}
        />
      </label>
      <span className="tr-bunn">
        <Lagrer />
        <button type="submit" className="sq-knapp tr-lagre">{lagreOrd}</button>
      </span>
    </form>
  )
}
