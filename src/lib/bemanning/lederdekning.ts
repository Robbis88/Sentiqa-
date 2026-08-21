// =====================================================================
// Lederdekning: er det en fastlønnet butikksjef på plass?
//
// St1 trekker ett årsverk fra timebudsjettet FORDI de antar at
// butikksjefen går på fastlønn. Holder ikke antakelsen — timelønn,
// permisjon, vikariat, vakanse — må arbeidet hennes gjøres av
// timelønnede, fra en ramme som ikke er dimensjonert for det.
//
// Regnestykket bor i `v_timeregnskap` (0119). Her ligger bare det
// skjermen trenger for å stille spørsmålet og lese svaret.
// =====================================================================

/**
 * Ett årsverk, slik St1 regner det.
 *
 * Står i `0082`: «Timene St1 trekker fra for butikksjefens fastlønn
 * (1695 = ett årsverk).» Brukes som FORSLAG i skjemaet, aldri som en
 * antakelse i beregningen — der leses `bemanning_aar.fast_arsverk_timer`,
 * og er den 0, blir justeringen 0. En innstilling som feiler stille er
 * verre enn en som mangler.
 */
export const ARSVERK_TIMER = 1695

/** De tre tilstandene en måned kan ha. «Ukjent» er ikke «nei». */
export type Dekning = 'fastlonnet' | 'ikke_fastlonnet' | 'ukjent'

export const MANEDER = [
  'Januar', 'Februar', 'Mars', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Desember',
] as const

/**
 * Setningen om hva haken faktisk gjør, i klartekst.
 *
 * IKKE «ja/nei». Den som setter haken om et halvt år skal se
 * konsekvensen, ikke gjette den — det er forskjellen på en innstilling
 * man tør røre og en man lar være.
 */
export function forklarDekning(d: Dekning, timerPerManed: number): string {
  if (d === 'fastlonnet') {
    return 'Fastlønnet butikksjef på plass. St1s fratrekk er riktig, '
      + 'rammen står som den er.'
  }
  if (d === 'ikke_fastlonnet') {
    return timerPerManed > 0
      ? `Ingen fastlønnet butikksjef. Rammen økes med ${timerPerManed} timer `
        + 'denne måneden.'
      : 'Ingen fastlønnet butikksjef — men årsverket er ikke satt, '
        + 'så rammen økes ikke. Sett det øverst.'
  }
  return 'Ikke tatt stilling. Rammen står urørt, og måneden telles som uavklart.'
}

/**
 * Hvor mange måneder som mangler et svar.
 *
 * Tallet står på siden fordi en delvis utfylt konfigurasjon ser
 * nøyaktig ut som en ferdig en — helt til noen lurer på hvorfor en
 * stasjon ligger over.
 */
export function uavklarte(
  rader: { fastlonnet: boolean | null }[],
  maanederIAr: number,
): number {
  return Math.max(0, maanederIAr - rader.filter((r) => r.fastlonnet !== null).length)
}

/** Timene én måned uten fastlønnet leder legger til rammen. */
export function justeringPerManed(arsverkTimer: number): number {
  return Math.round(arsverkTimer / 12)
}
