// =====================================================================
// Pause er en HENDELSE, aldri en beregning.
//
// PRODUKTBESLUTNING, Robert 2026-08-28:
//
//   All tid mellom inn- og utstempling er betalt arbeidstid. Ingen
//   automatisk pause trekkes. En ubetalt pause reduserer arbeidstiden
//   kun når pausen faktisk er registrert ved at den ansatte trykker.
//
// Nettbrettet har én pauseknapp. Ett trykk er 30 minutter. Ingen andre
// lengder kan velges, og uten et trykk trekkes ingenting.
//
// ---------------------------------------------------------------------
// HVA SOM STO HER FØR, OG HVORFOR DET MÅTTE UT
//
// Fram til nå trakk systemet 30 minutter automatisk av hver vakt over
// 5,5 time, hvis kjeden hadde slått av `stempling_pause_betalt`.
// Trekket ble skrevet til kolonnen `minutter` — som lønnsfila ikke
// leser. Den regnet klokketimer fra `fra_tid` til `til_tid` på nytt, så
// trekket nådde aldri fram til Visma.
//
// Verre: avstemmingen på /lonn sammenligner `minutter` fra begge
// kilder. Med trekket på ble nettbrettets `minutter` lik easy@works
// sum, avstemmingen viste null avvik, og fila betalte likevel pausen.
// Innstillingen som fikk kildene til å se like ut, var den som skjulte
// at fila ikke var det.
//
// Den nye regelen fjerner divergensen ved roten i stedet for å rette
// den: trekkes ingenting automatisk, er det ingenting å miste på veien.
// Og pausen som FAKTISK er registrert bæres som et intervall, ikke som
// et fratrukket tall — så både timelønn og tillegg kan utelate nøyaktig
// de samme minuttene.
//
// Samme prinsipp som `avledVakter` alt hviler på: systemet gjetter
// aldri. En sluttid vi ikke har, lukkes ikke. En pause vi ikke har
// sett, trekkes ikke.
// =====================================================================

/** Fast lengde på én registrert pause. Ingen andre lengder kan velges. */
export const PAUSE_MINUTTER = 30

const MIN = 60_000

export type Pausevindu = { fra: Date; til: Date; minutter: number }

/**
 * Vinduet én registrert pause faktisk dekker i en vakt.
 *
 * KLEMMES MOT SLUTTIDEN. Trykker hun pause 14:50 og stempler ut 15:00,
 * er pausen ti minutter, ikke tretti. Uten klemmen ville vakta blitt
 * tjue minutter kortere enn den var — og et negativt timetall er ikke
 * et tall noen kan forklare til den det gjelder.
 *
 * Returnerer null når pausen ikke gir noe å trekke: den ligger utenfor
 * vakta, eller den ble trykket i samme øyeblikk som utstemplingen.
 */
export function pausevindu(
  vaktStart: Date,
  vaktSlutt: Date,
  trykket: Date,
): Pausevindu | null {
  const fraMs = trykket.getTime()
  const sluttMs = vaktSlutt.getTime()
  // Utenfor vakta i det hele tatt. Skal ikke skje - avledningen kobler
  // pausen til den aapne vakta - men en feilsortert hendelse skal ikke
  // gi et negativt trekk.
  if (fraMs < vaktStart.getTime() || fraMs >= sluttMs) return null

  const tilMs = Math.min(fraMs + PAUSE_MINUTTER * MIN, sluttMs)
  const minutter = Math.round((tilMs - fraMs) / MIN)
  if (minutter <= 0) return null

  return { fra: new Date(fraMs), til: new Date(tilMs), minutter }
}
