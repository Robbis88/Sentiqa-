// =====================================================================
// Lederdekning: hva eieren har valgt å legge tilbake i rammen.
//
// St1 trekker ett årsverk fra timebudsjettet fordi de antar at
// butikksjefen går på fastlønn. Holder ikke antakelsen, KAN eieren
// legge timer tilbake — men det er en beslutning, ikke en konsekvens.
//
// TO SPØRSMÅL, OG DE KAN VÆRE UENIGE:
//
//   fastlonnet      Var det en fastlønnet butikksjef på plass? Et faktum.
//   timer_tilbake   Hva eieren valgte å gi. NULL = ingenting.
//
// Bjørn på Laguneparken er hele grunnen til skillet: fastlønnet, men i
// pappaperm til august. «Nei» er sant — og med automatikk ville
// stasjonen fått 953 timer tilbake og gått fra +154 til −799, uten at
// noen hadde tatt stilling til om det faktisk gikk med timelønnede til
// å dekke ham.
//
// Regnestykket bor i `v_timeregnskap` (0120). Her ligger bare det
// skjermen trenger.
// =====================================================================

/**
 * Ett årsverk, slik St1 regner det.
 *
 * Står i `0082`: «Timene St1 trekker fra for butikksjefens fastlønn
 * (1695 = ett årsverk).» Brukes bare til å regne ut FORSLAGET som vises
 * som tekst — aldri til å fylle inn et felt.
 */
export const ARSVERK_TIMER = 1695

/** De tre tilstandene lederdekningen kan ha. «Ukjent» er ikke «nei». */
export type Dekning = 'fastlonnet' | 'ikke_fastlonnet' | 'ukjent'

export const MANEDER = [
  'Januar', 'Februar', 'Mars', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Desember',
] as const

/**
 * FORSLAGET for en hel måned — aldri en tildeling.
 *
 * 1695/12 = 141,25. Desimalen beholdes: en halv måned er 70,63, og et
 * avrundet forslag inviterer til et avrundet valg.
 *
 * Tallet vises som TEKST ved siden av feltet og fylles aldri inn.
 * Eieren må skrive det selv. Det er hele forskjellen på et forslag og
 * en automatikk — og den forskjellen er grunnen til at 0119 ble rettet.
 */
export function forslagHelManed(arsverkTimer: number): number {
  return Math.round((arsverkTimer / 12) * 100) / 100
}

/** Norsk desimaltegn. 141.25 → «141,25». */
export function timetall(v: number): string {
  return String(v).replace('.', ',')
}

/**
 * Setningen om hva raden faktisk gjør, i klartekst.
 *
 * MÅ SI BEGGE DELER. «Ingen fastlønnet butikksjef. Ingen timer lagt
 * tilbake.» er en helt gyldig — og vanlig — tilstand: lederen var i
 * permisjon, men ingen timelønnet dekket henne. Sier setningen bare det
 * første, leses faktumet som en tildeling.
 */
export function forklarDekning(d: Dekning, timerTilbake: number | null): string {
  const gitt = timerTilbake
    ? `Rammen er økt med ${timetall(timerTilbake)} timer.`
    : 'Ingen timer lagt tilbake.'

  if (d === 'fastlonnet') return `Fastlønnet butikksjef på plass. ${gitt}`
  if (d === 'ikke_fastlonnet') return `Ingen fastlønnet butikksjef. ${gitt}`
  return `Ikke tatt stilling til lederdekning. ${gitt}`
}

/**
 * Hvor mange måneder som mangler et svar på lederdekning.
 *
 * Tallet står på siden fordi en delvis utfylt konfigurasjon ser
 * nøyaktig ut som en ferdig — helt til noen lurer på hvorfor en stasjon
 * ligger over.
 */
export function uavklarte(
  rader: { fastlonnet: boolean | null }[],
  maanederIAr: number,
): number {
  return Math.max(0, maanederIAr - rader.filter((r) => r.fastlonnet !== null).length)
}

/**
 * Normaliserer et innskrevet timetall.
 *
 * 0 OG TOMT ER DET SAMME, og begge blir `null`. Databasen har en skranke
 * som forbyr 0 nettopp derfor: «ingenting» skal ha én representasjon, så
 * en spørring etter `is null` ikke bommer på halvparten.
 */
export function normaliserTimer(rå: string): number | null {
  const n = Number(rå.replace(',', '.'))
  if (!Number.isFinite(n) || n <= 0) return null
  // Et årsverk er 1695 timer. Over 300 i én måned er en tastefeil, ikke
  // en beslutning — og den ville doblet rammen.
  if (n > 300) return null
  return Math.round(n * 100) / 100
}
