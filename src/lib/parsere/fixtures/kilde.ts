import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// EKTE FIL NÅR DEN FINNES, FIXTURE ELLERS — OG SUITEN SIER HVILKEN
//
// `eksempelfiler/` er gitignored (ekte kundedata), så testene som leste
// derfra sto med `describe.skipIf(!existsSync(FIL))`. De hoppet over seg
// selv i CI — og lokalt også, siden mappa er tom. Tjueto påstander som
// så grønne ut uten å måle noe.
//
// Nå kjører de alltid. Ligger den ekte fila der, brukes den; ellers
// bygges en arbeidsbok med samme form. Navnet på suiten sier hvilken av
// delene som faktisk kjørte, så et grønt resultat ikke kan misleses.
// =====================================================================

export type Kilde = {
  /** Til `describe`-navnet, så loggen sier hva som ble målt. */
  merke: string
  /** Er dette den ekte rapporten, eller vår etterligning? */
  ekte: boolean
  les: () => Promise<Buffer>
}

/**
 * Fila fra `eksempelfiler/`, eller fixturen.
 *
 * `lagFixture` kalles først når den trengs — å bygge en arbeidsbok koster
 * noen millisekunder, og på en maskin med de ekte filene skal den ikke
 * bygges i det hele tatt.
 */
export function kildeFor(filnavn: string, lagFixture: () => Promise<Buffer>): Kilde {
  const sti = join(process.cwd(), 'eksempelfiler', filnavn)
  if (existsSync(sti)) {
    return { merke: `ekte fil: ${filnavn}`, ekte: true, les: async () => readFileSync(sti) }
  }
  return { merke: 'syntetisk fixture', ekte: false, les: lagFixture }
}
