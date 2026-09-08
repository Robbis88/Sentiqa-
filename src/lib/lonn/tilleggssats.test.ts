import { describe, expect, it } from 'vitest'
import { ANDEL_AV_TIMESATS, TILLEGGSSATS, belopFor } from './tilleggssats'

// =====================================================================
// MÅLINGEN GJORT OM TIL EN PÅSTAND
//
// Satsene er lest ut av lønnsarteksportene for Dale (juli, august 2026)
// og Bønes (august 2026) — kroner delt på timer, veid over alle linjer:
//
//     1429  hverdag 18-21     434,65 t     5 215,80 kr    12,00
//     1430  hverdag 21-24     275,17 t     6 053,57 kr    22,00
//     1431  hverdag 00-06      64,56 t     2 065,81 kr    32,00
//     1432  lørdag            113,06 t     3 108,83 kr    27,50
//     1433  søndag 00-06        5,10 t       193,59 kr    37,96 *
//     1434  søndag 06-18      363,14 t     8 897,05 kr    24,50
//     1435  søndag 18-24      170,09 t     4 847,51 kr    28,50
//
//     * fem timer er for lite til at avrunding forsvinner. 37,96 er
//       38,00 minus tre linjers øreavrunding, og det er den eneste
//       satsen som ikke traff en rund verdi eksakt.
//
// At seks av sju traff en rund verdi PÅ ØRET er selve beviset for at
// dette er satser og ikke gjennomsnitt.
// =====================================================================

describe('TILLEGGSSATS', () => {
  it('holder de sju tilleggene fra Energiavtalen § 2.6.1', () => {
    expect(Object.keys(TILLEGGSSATS).sort()).toEqual(
      ['1429', '1430', '1431', '1432', '1433', '1434', '1435'],
    )
  })

  // =================================================================
  // DEN ENE SOM IKKE ER SOM AVTALEN SIER
  // =================================================================
  // § 2.6.1 gir lørdag 18-24 og søndag 18-24 samme sats, kr 27,50.
  // Lørdag kommer ut på 27,50 på øret over 113 timer; søndag på 28,50
  // over 170. Begge er målt i samme filer med samme metode, så det er
  // ikke en lesefeil i målingen — easy@work betaler en krone mer på
  // søndag enn overenskomsten jeg leste sier.
  //
  // Denne testen er grunnen til at satsene ikke kan «ryddes opp» til å
  // stemme med PDF-en av en som ser to like tillegg med ulik sats. Skal
  // den endres, skal den måles om igjen mot en fersk kronefil.
  it('gir søndag 18–24 én krone mer enn lørdag — målt, ikke utledet', () => {
    expect(TILLEGGSSATS['1432']).toBe(27.50)
    expect(TILLEGGSSATS['1435']).toBe(28.50)
  })

  it('regner tillegg som kroner per time, uavhengig av timesatsen', () => {
    // 6 timer hverdag 21-24 er 132 kroner enten den ansatte tjener 185
    // eller 285 i timen.
    expect(belopFor('1430', 6, 185.58)).toBe(132)
    expect(belopFor('1430', 6, 285.10)).toBe(132)
  })
})

describe('ANDEL_AV_TIMESATS', () => {
  it('betaler timelønn og sykelønn med egen sats', () => {
    expect(belopFor('2', 7.5, 257.00)).toBe(1927.50)
    expect(belopFor('12', 7.5, 257.00)).toBe(1927.50)
  })

  // OVERTIDEN VAR NOTERT SOM UAVKLART, og notatet var en
  // sammenblanding: «50 % målt til ca. 142 kr/t mot en grunnlønn rundt
  // 195». Timene tilhørte en ansatt med timesats 285,10, ikke 195.
  // 142,70 / 285,10 = 0,5006.
  it('betaler overtidstillegg som en andel av egen timesats', () => {
    expect(belopFor('96', 1, 285.10)).toBeCloseTo(142.55, 2)
    expect(belopFor('97', 1, 285.10)).toBeCloseTo(285.10, 2)
    expect(ANDEL_AV_TIMESATS['96']).toBe(0.5)
    expect(ANDEL_AV_TIMESATS['97']).toBe(1)
  })
})

// =====================================================================
// KANARIFUGLEN
//
// Vakten som teller på satsene er verdiløs hvis `belopFor` stille gir 0
// for noe den ikke kjenner. Da ville en ny kolonne i eksporten blitt
// null kroner, og null kroner ser ut som en rolig måned.
// =====================================================================
describe('kanarifugl', () => {
  it('kaster på en lønnsart uten sats, i stedet for å gi null kroner', () => {
    expect(() => belopFor('1436', 10, 200)).toThrow(/ingen sats/)
  })

  it('gir ikke null i stillhet for en kode som ligner', () => {
    // '96 ' med mellomrom er ikke '96'. En oppslagstabell som normaliserer
    // for mye ville skjult at koden kom feil ut av parseren.
    expect(() => belopFor('96 ', 10, 200)).toThrow()
  })
})
