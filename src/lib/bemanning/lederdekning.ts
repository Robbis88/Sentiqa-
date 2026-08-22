// =====================================================================
// Lederdekning: leses fra faste vakter, ikke fra et eget skjema.
//
// St1 trekker ett årsverk (1695 t) fra timebudsjettet fordi de antar at
// butikksjefen går på fastlønn og dekker sitt eget arbeid. Om den
// antakelsen holder, står allerede i `bemanning_fast_vakt.timelonnet` —
// 0086 definerer den ordrett:
//
//   true  = vakten er bundet, men belaster timerammen
//   false = fastlønn, dekker gulvet uten å koste rammen
//
// REGELEN, UTEN NAVNEGJENKJENNING: har stasjonen faste vakter, men
// ingen av dem er fastlønnet, legges årsverket/12 tilbake i rammen.
// Vi trenger ikke vite hvilken rad som er butikksjefen — `navn` er
// fritekst, og å koble på den ville vært samme feil som å koble ansatte
// på navn.
//
// FORKASTET: et eget skjema (`bemanning_lederdekning`, 0118–0120) som
// spurte om det samme på nytt, med fire kontroller per måned. Det
// motsa til og med seg selv på skjermen. Robert: «hvorfor gjøre det så
// veldig vanskelig … dette skal 50–100 retailere onboarde seg selv på.»
//
// Regnestykket bor i `v_timeregnskap` (0121). Her ligger bare tallet
// skjermen trenger.
// =====================================================================

/**
 * Ett årsverk, slik St1 regner det.
 *
 * Står i `0082`: «Timene St1 trekker fra for butikksjefens fastlønn
 * (1695 = ett årsverk).» Viewet bruker samme tall som reserve når
 * `bemanning_aar.fast_arsverk_timer` ikke er satt — og det er den
 * normale tilstanden, siden ingenting i produktet setter den i dag.
 *
 * SQL kan ikke importere fra TypeScript, så tallet står to steder.
 * Testen under leser begge og feller hvis de går fra hverandre.
 */
export const ARSVERK_TIMER = 1695

/** Timene som legges tilbake i en måned uten fastlønnet fast vakt. */
export function timerPerManed(arsverkTimer: number): number {
  return Math.round((arsverkTimer / 12) * 100) / 100
}

/** Norsk desimaltegn. 141.25 → «141,25». */
export function timetall(v: number): string {
  return String(v).replace('.', ',')
}
