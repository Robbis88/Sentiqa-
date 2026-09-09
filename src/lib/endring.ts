// =====================================================================
// «−0,0 %» MED RØD NEDPIL
//
// Varden sto slik på målekortet 2026-09-09: en vekst så nær null at
// fortegnet er tilfeldig, tegnet som en nedgang. Rød farge, pil ned,
// minus foran — tre signaler om at noe gikk galt, av et tall som
// egentlig sier «uendret».
//
// Feilen er at RETNINGEN ble bestemt av det uavrundede tallet, mens
// TEKSTEN ble bestemt av det avrundede:
//
//     const opp = p >= 0                        // p = −0,04
//     {opp ? '▲ +' : '▼ −'}{Math.abs(p).toFixed(1)}   →  «▼ −0.0 %»
//
// De to er uenige i akkurat det intervallet der forskjellen ikke
// finnes. Det er samme familie som resten av dette systemet er bygget
// for å nekte: et tall som ser ut som en beskjed det ikke er.
//
// ---------------------------------------------------------------------
// REGELEN: FORTEGNET FØLGER TALLET SOM VISES
//
// Er det avrundede tallet null, er retningen `flat` — ingen pil, ingen
// farge, intet fortegn. Ikke fordi endringen er nøyaktig null, men
// fordi den er mindre enn oppløsningen vi valgte å vise. Da er «0,0 %»
// hele sannheten vi har.
// =====================================================================

export type Retning = 'opp' | 'ned' | 'flat'

export type Endring = {
  retning: Retning
  /** `▲`, `▼` eller tom streng. En pil uten retning er en løgn. */
  pil: string
  /** `+`, `−` (U+2212) eller tom streng. */
  fortegn: string
  /** Tallet uten fortegn, med valgt antall desimaler. */
  tall: string
  /** `gronn` / `rod` / tom. Tom lar flaten arve nøytral farge. */
  farge: string
}

/**
 * Retning og tekst for en prosentendring, avgjort av TALLET SOM VISES.
 *
 * `desimaler` skal være det samme antallet som flaten faktisk viser —
 * ellers gjenoppstår uenigheten mellom retning og tekst et hakk lenger
 * ned.
 */
export function endring(prosent: number, desimaler = 1): Endring {
  const avrundet = Number(prosent.toFixed(desimaler))
  const tall = Math.abs(avrundet).toFixed(desimaler)

  if (avrundet === 0) return { retning: 'flat', pil: '', fortegn: '', tall, farge: '' }
  if (avrundet > 0) return { retning: 'opp', pil: '▲', fortegn: '+', tall, farge: 'gronn' }
  return { retning: 'ned', pil: '▼', fortegn: '−', tall, farge: 'rod' }
}
