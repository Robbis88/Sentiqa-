// Hva en time koster, per lønnsart.
//
// =====================================================================
// SATSENE ER MÅLT, IKKE UTLEDET
//
// easy@work har to eksporter som begge dekker lønn, og de svarer på
// hvert sitt spørsmål:
//
//     lønnsarteksporten   timer OG kroner   → `parsere/lonnsart.ts`
//     lønnsgrunnlaget     timer og antall   → `parsere/lonnsgrunnlag.ts`
//
// Lønnsarteksporten er den vi vil ha. Men den finnes bare for tre av
// fem stasjoner, og for de to andre fantes det da ingen lønnskost i det
// hele tatt. Lønnsgrunnlaget finnes for alle fem.
//
// Denne tabellen er broen: den gjør antall om til kroner.
//
// ---------------------------------------------------------------------
// DEN ER LEST UT AV KRONEFILENE, IKKE UT AV OVERENSKOMSTEN
//
// `lonnsart.ts` sto med en skrevet begrunnelse for at dette ikke burde
// gjøres: «å regne kroner av den ville krevd hele satstabellen fra
// Energiavtalen — mulig, men lønnsarteksporten har tallene ferdig, og
// to veier til samme sum er to steder de kan skille lag».
//
// Resonnementet var riktig og premisset var feil. Lønnsarteksporten har
// tallene ferdig for TRE stasjoner. For de to andre var alternativet
// ikke «et litt dårligere tall», men ingen tall.
//
// Og advarselen var mer treffende enn den visste: hadde satsene blitt
// utledet av overenskomsten, ville ÉN av dem vært gal. § 2.6.1 gir
// søndag 18–24 kr 27,50, samme som lørdag. Målt over 170,09 timer i
// tre stasjonsmåneder betaler easy@work kr 28,50 — eksakt, ikke
// omtrent. Lørdagssatsen kommer samtidig ut på 27,50 på øret, så det er
// ikke en lesefeil i målingen.
//
// Satsene under er derfor VEID GJENNOMSNITT av kroner delt på timer i
// lønnsarteksportene for Dale (juli, august 2026) og Bønes (august
// 2026) — 3 422,86 timer timelønn og 1 425,72 timer tillegg. Alle
// tilleggssatsene traff en rund verdi på øret. Det er selve beviset på
// at satsen er en sats og ikke et snitt av mange.
//
// Endrer St1 en sats, skal denne tabellen måles om igjen mot en fersk
// kronefil — ikke justeres etter en PDF. `tilleggssats.test.ts` gjør
// målingen om til en påstand.
// =====================================================================

/** Tillegg som betales med et fast kronebeløp per time. */
export const TILLEGGSSATS: Record<string, number> = {
  1429: 12.00, // hverdag 18-21
  1430: 22.00, // hverdag 21-24
  1431: 32.00, // hverdag 00-06
  1432: 27.50, // lørdag 18-24 — lørdag natt og formiddag har ikke tillegg
  1433: 38.00, // søndag 00-06
  1434: 24.50, // søndag 06-18
  1435: 28.50, // søndag 18-24 — MÅLT. Overenskomsten sier 27,50.
}

/**
 * Lønnsarter som betales som en andel av den ansattes egen timesats.
 *
 * Overtidstillegget var lenge notert som uavklart: «50 % målt til ca.
 * 142 kr/t mot en grunnlønn rundt 195, så grunnlaget er ikke en enkel
 * prosent av timelønna». Det var en sammenblanding av to ansatte.
 * Timene tilhørte én med timesats 285,10, og 142,70 / 285,10 = 0,5006.
 *
 * Målt per linje over 16 overtidslinjer ligger 96 mellom 0,481 og 0,502
 * og 97 mellom 0,996 og 1,006. Spredningen er avrunding: 0,10 timer med
 * beløpet avrundet til øret gir 2 % utslag i satsen alene.
 */
export const ANDEL_AV_TIMESATS: Record<string, number> = {
  2: 1,     // timelønn
  12: 1,    // sykelønn — full lønn, arbeidsgiverperioden
  96: 0.5,  // 50 % overtidstillegg (dag og uke)
  97: 1,    // 100 % overtidstillegg (alle fire variantene)
}

/**
 * Kroner for en linje.
 *
 * KASTER PÅ EN UKJENT LØNNSART. En kolonne vi aldri har sett en verdi i
 * er en kolonne vi ikke kan prise, og en linje som stille blir null
 * kroner ser ut som en rolig måned. Samme innsats som at
 * lønnsartparseren kaster på en rad den ikke forstår.
 */
export function belopFor(lonnsart: string, timer: number, timesats: number): number {
  const fast = TILLEGGSSATS[lonnsart]
  const andel = ANDEL_AV_TIMESATS[lonnsart]
  if (fast === undefined && andel === undefined) {
    throw new Error(
      `Lønnsart ${lonnsart} har ingen sats. Kroner kan ikke regnes av `
      + 'lønnsgrunnlaget før satsen er målt mot en lønnsarteksport.',
    )
  }
  const sats = fast ?? timesats * andel!
  return Math.round(timer * sats * 100) / 100
}
