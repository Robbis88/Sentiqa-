// =====================================================================
// Visma-lønnsfila, byte for byte.
//
// Formatet er lest ut av fila easy@work leverer til Azets i dag. Det er
// ikke dokumentert noe sted vi har tilgang til, så hver detalj her er
// målt, ikke antatt:
//
//   0;0;1009;2;0;9.00;0;0;0;0;"4185";" ";" ";" ";" ";" ";0
//
// 17 felt, semikolon, ingen overskriftsrad, CRLF, UTF-8 MED BOM.
//
// Tre detaljer som er lette å ta feil av, og som alle ville brutt
// importen:
//
//   · felt 5 og 7–10 er «0», ikke «0.00»
//   · felt 12–16 er «" "» — sitert MELLOMROM, ikke tomt felt
//   · felt 17 er «0», ikke tomt
//
// Og desimalskilletegnet er PUNKTUM. Åpnes fila i norsk Excel og lagres,
// blir 9.00 til 9,00 og fila er ødelagt. Derfor lastes den ned — aldri
// åpnes.
// =====================================================================

import type { Lonnslinje } from './tidsband'

const FELT = 17
const TOM = '" "' // sitert mellomrom, ikke tomt felt

/**
 * Bygger fila for ÉN stasjon. Kostnadsstedet er butikknummeret, og
 * hentingen hos Azets forventer én fil per regnskap.
 */
export function byggVismafil(linjer: Lonnslinje[], kostnadssted: string): string {
  const rader = linjer.map((l) => {
    const felt = new Array<string>(FELT).fill('0')
    felt[2] = l.ansattNr
    felt[3] = l.lonnsart
    felt[5] = l.antall.toFixed(2) // punktum, alltid to desimaler
    felt[10] = `"${kostnadssted}"`
    for (let i = 11; i <= 15; i++) felt[i] = TOM
    return felt.join(';')
  })
  // CRLF på hver linje, også den siste.
  return rader.map((r) => `${r}\r\n`).join('')
}

/** UTF-8 med BOM. Uten den leser Visma første felt feil. */
export function medBom(innhold: string): Uint8Array {
  const kropp = new TextEncoder().encode(innhold)
  const ut = new Uint8Array(kropp.length + 3)
  ut.set([0xef, 0xbb, 0xbf], 0)
  ut.set(kropp, 3)
  return ut
}

/**
 * Filnavn. Stasjon og periode må stå i navnet — ellers vet ikke
 * hentingen hos Azets hva den plukker opp.
 *
 * MERK: mønsteret her er vårt eget inntil vi har sett hva easy@work
 * faktisk kaller filene sine. Det må bekreftes før første ekte levering.
 */
export function vismaFilnavn(kostnadssted: string, ar: number, maned: number): string {
  return `lonn_${kostnadssted}_${ar}-${String(maned).padStart(2, '0')}.csv`
}
