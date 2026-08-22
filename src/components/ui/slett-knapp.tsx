'use client'
import { HandlingKnapp } from './handling-knapp'
import type { Kvittering } from '@/lib/kvittering'

// =====================================================================
// Slett, med et svar.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// Han hadde rett, og verre enn saa: `slett()` i bemanning kastet
// resultatet av `.delete()`. Ble raden avvist av RLS, skjedde det
// ingenting - og sida sa ingenting. Da er det umulig aa vite om raden
// er borte eller om knappen ikke virker, og begge deler ser like ut.
//
// SLETTING ER BARE ETT TILFELLE av en handling som maa svare. Formen
// bor i `HandlingKnapp`; denne holder navnet og de valgene sletting
// alltid tar: destruktiv variant, «Sletter …» mens den venter.
// =====================================================================

/** Beholdt navn. Samme type som `Kvittering`. */
export type SlettTilstand = Kvittering

export function SlettKnapp({
  handling,
  id,
  merke = 'Slett',
  hva,
  bekreftelse = 'Slettet',
  sporsmaal,
}: {
  handling: (t: SlettTilstand, fd: FormData) => Promise<SlettTilstand>
  id: string
  merke?: string
  /** Hva som slettes: «kampanjen Sommer». Blir knappens aria-label.
      Uten den heter tjue knapper i en liste det samme. */
  hva?: string
  /** Hva som staar etterpaa. «Slettet» passer sjelden paa alt. */
  bekreftelse?: string
  /** Spoersmaal foer innsending. Kun for det som ikke kan angres. */
  sporsmaal?: string
}) {
  return (
    <HandlingKnapp
      handling={handling}
      felt={{ id }}
      merke={merke}
      hva={hva}
      arbeider="Sletter …"
      bekreftelse={bekreftelse}
      variant="destruktiv"
      sporsmaal={sporsmaal}
    />
  )
}
