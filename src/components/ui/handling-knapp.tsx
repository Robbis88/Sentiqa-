'use client'
import { useActionState } from 'react'
import { Knapp, type Knappevariant } from './knapp'
import type { Kvittering } from '@/lib/kvittering'

// =====================================================================
// En knapp som svarer.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// ÉN KOMPONENT, IKKE TJUE VARIANTER. Handlinger som endrer noe finnes
// 25 steder. Skrives kvitteringen på nytt hvert sted, blir den ulik
// hvert sted — og ett av dem blir glemt.
//
// FEILEN BLIR STÅENDE, KVITTERINGEN FORSVINNER IKKE AV SEG SELV. En
// bekreftelse som blinker bort er en bekreftelse man rekker å tvile på.
// Neste navigering fjerner den; det holder.
// =====================================================================

export type { Kvittering }

export function HandlingKnapp({
  handling,
  felt,
  merke,
  hva,
  arbeider,
  bekreftelse = 'Utført',
  variant = 'sekundaer',
  sporsmaal,
}: {
  /** Serverhandling som tar (tilstand, formData) og svarer med tekst. */
  handling: (t: Kvittering, fd: FormData) => Promise<Kvittering>
  /** Skjulte felter. `{ id }` er det vanlige. */
  felt?: Record<string, string>
  merke: string
  /** Hva handlingen gjelder. Blir aria-label sammen med merket. */
  hva?: string
  /** Hva knappen sier mens den venter. «Sletter …» */
  arbeider?: string
  /** Hva som står etterpå når handlingen ikke svarer med egen tekst. */
  bekreftelse?: string
  variant?: Knappevariant
  /** Spørsmål i en bekreftelsesdialog. Kun for det som ikke kan angres. */
  sporsmaal?: string
}) {
  const [tilstand, kjor, venter] =
    useActionState<Kvittering, FormData>(handling, undefined)

  return (
    <form
      action={kjor}
      className="sq-slett"
      // BEKREFTELSEN MÅ STOPPE INNSENDINGEN, ikke bare spørre. Uten
      // `preventDefault` kjører handlingen uansett hva man svarer.
      onSubmit={(e) => {
        if (sporsmaal && !window.confirm(sporsmaal)) e.preventDefault()
      }}
    >
      {Object.entries(felt ?? {}).map(([navn, verdi]) => (
        <input key={navn} type="hidden" name={navn} value={verdi} />
      ))}
      <Knapp
        type="submit"
        variant={variant}
        liten
        disabled={venter}
        aria-label={hva ? `${merke} ${hva}` : undefined}
      >
        {venter ? (arbeider ?? `${merke} …`) : merke}
      </Knapp>
      {tilstand?.feil && (
        <span className="sq-slett-feil" role="alert">{tilstand.feil}</span>
      )}
      {tilstand?.ok && (
        <span className="sq-slett-ok" role="status">
          {tilstand.ok === 'ok' ? bekreftelse : tilstand.ok}
        </span>
      )}
    </form>
  )
}
