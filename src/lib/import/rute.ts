import type { Rapporttype } from '@/lib/parsere/typer'

// =====================================================================
// SKAL FILA PARSES I NETTLESEREN, ELLER SENDES TIL SERVEREN?
//
// Regelen bodde inne i opplasteren som et uttrykk i en if-setning, og
// den var da bare RIKTIG VED ET UHELL:
//
//   BP26 er 26,6 MB og gikk til serveren fordi den er over 12 MB.
//   BP25 er 10,5 MB og falt gjennom til nettleserparseren, som ikke har
//   noen vei for en forretningsplan. Resultatet var «Ukjent/ustøttet
//   filtype» paa en fil systemet kjenner utmerket godt.
//
// En regel som virker fordi tallene tilfeldigvis stemmer, slutter aa
// virke den dagen de ikke gjoer det. Derfor staar den her, ren, og med
// en test som beviser at en BP gaar til serveren UANSETT stoerrelse.
// =====================================================================

/** Over denne gaar alt til serveren. Nettleseren har ikke minne til mer. */
export const FOR_STOR = 12 * 1024 * 1024

/**
 * Typer det ikke finnes noen nettleserparser for.
 *
 * Forretningsplanen er 11-27 MB og full innlasting koster over 2 GB.
 * `gjenkjennRapporttype` kjenner den igjen paa arknavnene alene, men
 * selve lesingen hoerer hjemme paa serveren.
 */
const BARE_SERVER: Rapporttype[] = ['st1_bp']

/**
 * `type` er `undefined` foer fila er lest. Da svarer funksjonen paa det
 * den kan se uten aa aapne den - stoerrelse og filnavn - og kalles paa
 * nytt naar typen er kjent.
 */
export function tilServeren(o: {
  navn: string
  storrelse: number
  type?: Rapporttype
}): boolean {
  if (o.storrelse > FOR_STOR) return true
  // PDF og CSV: nettleserparseren her kan bare xlsx. Slipper man en CSV
  // inn i den, kveles zip-leseren og fila «feiler» uten at noen skjoenner
  // hvorfor. Serveren kan begge deler.
  if (/\.(pdf|csv|txt)$/i.test(o.navn)) return true
  if (o.type && BARE_SERVER.includes(o.type)) return true
  return false
}
