// Hvilken vei går det?
//
// =====================================================================
// RETNING ER ET BEDRE MÅL ENN NIVÅ
// =====================================================================
//
// Sentiqa rangerer stasjoner på nivå. En butikk med 8 % matkast som kom
// fra 12 % vinner; en med 6 % som kom fra 4 % taper — og på nivå ser den
// andre best ut.
//
// På Kelsars sju første måneder i 2026 snur rangeringen helt:
//
//   på nivå (resultat hittil)      på retning (januar → juli)
//   1. Dale        −287 286        1. Dale        +225 737
//   2. Lone          26 389        2. Bønes        −33 105
//   3. Bønes        309 282        3. Varden       −42 136
//   4. Laguneparken 320 315        4. Lone         −53 903
//   5. Varden       323 576        5. Laguneparken −135 287
//
// Dale er sist på nivå og først på retning: resultatet gikk fra −162 491
// i januar til +63 246 i juli. Laguneparken er motsatt — fjerde best på
// året, sist på retning. Ingen som leser årstallet ser det.
//
// ---------------------------------------------------------------------
// HVORDAN DEN MÅLES
//
// Fortegnet på den lineære trenden over perioden, pluss hvor mange
// måneder på rad den har gått samme vei.
//
// «Flat» er ikke fravær av bevegelse — det er bevegelse som er liten mot
// hvor mye tallet svinger. Uten det ville en stasjon med 200 000 i
// månedssvingninger fått «retning» av 3 000 kroners drift, og en plan
// bygget på støy er verre enn ingen plan: den lærer folk at systemet
// gjetter.
//
// ---------------------------------------------------------------------
// HVA SOM ER «BRA» AVHENGER AV LØFTESTANGEN
//
// Omsetning opp er bra. Matkast opp er ikke. Derfor bærer hver
// løftestang sin egen `god`-retning, og `retning()` sier bare hvilken vei
// det går — ikke om det er godt. Å blande de to er hvordan et system
// ender med å gratulere noen med at svinnet stiger.

export type Vei = 'opp' | 'ned' | 'flat'

export type Kurs = {
  vei: Vei
  /** Måneder på rad samme vei, inkludert den siste. Minst 1. */
  paaRad: number
  /** Endring over hele perioden, av trendlinja — ikke første mot siste. */
  endring: number
  /** Hvor mye tallet svinger. Grunnlaget for at noe kalles flatt. */
  spenn: number
}

/**
 * Minste antall målinger for at retning skal bety noe.
 *
 * To punkter er en strek, ikke en retning: enhver enkeltmåned ville satt
 * kursen. Tre er det minste som kan si noe om at det holder seg.
 */
export const MINST_MAALINGER = 3

/**
 * Hvor stor del av svingningen bevegelsen må utgjøre før den er en
 * retning og ikke støy.
 *
 * 12 % er valgt, ikke utledet. Det er lavt nok til å fange en jevn drift
 * over et halvår, og høyt nok til at én rar måned ikke setter kursen.
 */
export const STOYGRENSE = 0.12

/**
 * Retningen i en serie. Eldste først.
 *
 * `null` når serien er for kort — og det er et annet svar enn «flat».
 * En plan som ikke kan vite retningen skal si det, ikke gjette den.
 */
export function retning(serie: readonly number[]): Kurs | null {
  const n = serie.length
  if (n < MINST_MAALINGER) return null

  // Minste kvadraters stigningstall. Bruker hele serien, ikke første mot
  // siste: to ytterpunkter lar én rar måned bestemme alt.
  let sx = 0, sy = 0, sxy = 0, sxx = 0
  for (let i = 0; i < n; i++) {
    sx += i; sy += serie[i]; sxy += i * serie[i]; sxx += i * i
  }
  const nevner = n * sxx - sx * sx
  const stigning = nevner === 0 ? 0 : (n * sxy - sx * sy) / nevner
  const endring = stigning * (n - 1)

  const spenn = Math.max(...serie) - Math.min(...serie)
  const flat = spenn === 0 || Math.abs(endring) < spenn * STOYGRENSE

  // Måneder på rad samme vei, bakfra. Teller bevegelsen mellom punkter,
  // ikke punktene selv: `paaRad = 3` betyr tre steg i samme retning.
  let paaRad = 1
  for (let j = n - 1; j > 0; j--) {
    const dette = serie[j] - serie[j - 1]
    if (dette === 0) break
    if (j === n - 1) { paaRad = 1; continue }
    const forrige = serie[j] - serie[j - 1]
    const etter = serie[j + 1] - serie[j]
    if ((forrige > 0) !== (etter > 0)) break
    paaRad++
  }

  return {
    vei: flat ? 'flat' : stigning > 0 ? 'opp' : 'ned',
    paaRad,
    endring,
    spenn,
  }
}

/**
 * Er retningen god for denne løftestangen?
 *
 * `god` er veien som er ønsket: `'opp'` for omsetning, `'ned'` for
 * matkast. Flat er verken bra eller dårlig — den er fravær av nyhet, og
 * skal ikke bli til ros.
 */
export function erBra(k: Kurs, god: 'opp' | 'ned'): boolean {
  return k.vei !== 'flat' && k.vei === god
}

export function erIlle(k: Kurs, god: 'opp' | 'ned'): boolean {
  return k.vei !== 'flat' && k.vei !== god
}
