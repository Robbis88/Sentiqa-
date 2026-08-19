// =====================================================================
// Er hun inne eller ute akkurat naa?
//
// Skilt fra avled.ts med vilje: den regner ferdige vakter for lonn,
// denne svarer paa det ene spoersmaalet nettbrettet stiller hver gang
// noen taster nummeret sitt. To ulike spoersmaal, to ulike tester.
// =====================================================================

export type Retning = 'inn' | 'ut'

export type SisteHendelse = { type: Retning; tidspunkt: string } | null

/**
 * Hva et trykk skal foere til.
 *
 * Ingen hendelser, eller sist ute → hun stempler INN.
 * Sist inne → hun stempler UT.
 *
 * Merk at vi ikke ser paa dato. En som stemplet inn 23:30 og trykker
 * igjen 00:30 skal stemple UT, ikke inn paa nytt - vakten er den samme
 * selv om dogn er skiftet.
 */
export function nesteRetning(siste: SisteHendelse): Retning {
  return siste?.type === 'inn' ? 'ut' : 'inn'
}

/**
 * Har vakten staatt aapen mistenkelig lenge?
 *
 * Vi lukker den ikke - se avled.ts for hvorfor vi aldri gjetter en
 * sluttid. Men den som staar der skal faa vite at noe ser galt ut, saa
 * hun kan si fra i stedet for aa stemple ut tolv timer for sent og tro
 * at det gikk bra.
 *
 * Terskelen er hoy med vilje: en lang vakt er lovlig, en glemt
 * utstempling er vanlig, og et varsel som fyrer paa normale vakter blir
 * ignorert naar det gjelder.
 */
export const LANG_VAKT_TIMER = 16

export function harStaattLenge(siste: SisteHendelse, naa: Date): boolean {
  if (siste?.type !== 'inn') return false
  const timer = (naa.getTime() - Date.parse(siste.tidspunkt)) / 3_600_000
  return timer >= LANG_VAKT_TIMER
}
