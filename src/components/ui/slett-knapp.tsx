'use client'
import { useActionState } from 'react'
import { Knapp } from './knapp'

// =====================================================================
// Slett, med et svar.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// Han hadde rett, og verre enn som så: `slett()` i bemanning kastet
// resultatet av `.delete()`. Ble raden avvist av RLS, skjedde det
// ingenting — og siden sa ingenting. Da er det umulig å vite om raden
// er borte eller om knappen ikke virker, og begge deler ser like ut.
//
// ÉN KOMPONENT, IKKE 22 VARIANTER. Sletting finnes 22 steder i appen.
// Skrives kvitteringen på nytt hvert sted, blir den ulik hvert sted —
// og en av dem blir glemt.
//
// FEILEN BLIR STÅENDE, KVITTERINGEN FORSVINNER IKKE AV SEG SELV.
// En bekreftelse som blinker bort er en bekreftelse man rekker å tvile
// på. Neste navigering fjerner den; det holder.
// =====================================================================

export type SlettTilstand = { ok?: string; feil?: string } | undefined

export function SlettKnapp({
  handling,
  id,
  merke = 'Slett',
  bekreftelse = 'Slettet',
}: {
  /** Serverhandling som tar (tilstand, formData) og svarer. */
  handling: (t: SlettTilstand, fd: FormData) => Promise<SlettTilstand>
  id: string
  merke?: string
  /** Hva som står etterpå. «Slettet» passer sjelden på alt. */
  bekreftelse?: string
}) {
  const [tilstand, kjor, venter] =
    useActionState<SlettTilstand, FormData>(handling, undefined)

  return (
    <form action={kjor} className="sq-slett">
      <input type="hidden" name="id" value={id} />
      <Knapp type="submit" variant="destruktiv" liten disabled={venter}>
        {venter ? 'Sletter …' : merke}
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
