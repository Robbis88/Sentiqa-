// Hvem sine timer er lønn, og hvem sine er bare arbeidstid.
//
// =====================================================================
// EN FASTLØNNET STEMPLER OGSÅ
//
// Sandra på Lone står i easy@work-eksporten for august 2026 med 193,50
// timer og en timesats på 285. Ganget ut blir det 57 957 kroner ingen
// har fått utbetalt: hun har fastlønn, og stemplingene hennes er
// arbeidstid, ikke lønnsgrunnlag.
//
// Tas de med, er Lones lønnsandel feil med en fjerdedel av en
// butikksjefslønn — og det ser ikke ut som en feil. Det ser ut som en
// stasjon som bruker for mye folk.
//
// ---------------------------------------------------------------------
// REGELEN FANTES ALLEREDE
//
// `ansatt_avtale.lonnsform` kom i `0099` for nøyaktig dette, men for
// lønnsfila til Visma: «Butikksjefen har fastlønn, Carmen er
// tilkallingsvikar. Begge stempler. Begge jobber. Ingen av dem skal stå
// i fila.» Den var bare aldri anvendt på lønnsKOSTEN.
//
// ---------------------------------------------------------------------
// BARE `fastlonn`, IKKE `tilkalling`
//
// En tilkallingsvikar får betalt for timene sine — de føres bare utenom
// Visma-fila. Kostnaden er ekte, og å fjerne den ville gjort
// lønnskosten for lav. Det er en annen feil, ikke ingen feil.
//
// `null` tas med. Uavklart er ikke det samme som fastlønnet. Lønnsfila
// STOPPER på null, og det er riktig der — den skriver ut penger, og en
// glemt person oppdages først på kontoutskriften. Denne leser bare, og
// å nekte hele stasjonen lønnskost for én uavklart person ville vært en
// større skade enn den avverger.
// =====================================================================

export type MedAnsattnr = { ansattNr: string }

export type Utvalg<T> = {
  /** Linjene som er lønn. */
  beholdt: T[]
  /** Ansattnumrene som ble holdt utenfor, og som faktisk sto i fila. */
  utelatteNr: string[]
  /** Navnene deres, til meldingen. */
  utelatteNavn: string[]
}

/**
 * Deler linjene i dem som er lønn og dem som bare er arbeidstid.
 *
 * `fastlonnede` er ansattnummer → navn, for én stasjon.
 *
 * UTELATELSEN SKAL KUNNE SIES HØYT. Derfor returneres numrene og navnene
 * og ikke bare de beholdte linjene: en person som forsvinner ut av
 * lønnskosten uten et ord ser ut som en person som ikke jobbet. Numrene
 * trengs dessuten til å rydde bort rader som ble lagret før regelen
 * fantes — en `upsert` fjerner ikke det den ikke lenger produserer.
 */
export function utenFastlonn<T extends MedAnsattnr>(
  linjer: T[],
  fastlonnede: Map<string, string>,
): Utvalg<T> {
  const beholdt: T[] = []
  const nr = new Set<string>()
  for (const l of linjer) {
    if (fastlonnede.has(l.ansattNr)) nr.add(l.ansattNr)
    else beholdt.push(l)
  }
  return {
    beholdt,
    utelatteNr: [...nr],
    utelatteNavn: [...nr].map((n) => fastlonnede.get(n)!).sort(),
  }
}
