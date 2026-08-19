// =====================================================================
// Pausetrekk.
//
// Dette er ikke en detalj — det er forutsetningen for at avstemmingen
// betyr noe. easy@work Basis Export har egne segmenter for «Betalt tid»,
// «Ubetalt tid» og «Pause», og importen tar bare de betalte med.
// Nettbrettet gir bare inn og ut. Uten en regel her ville hver vakt over
// 5½ time vist et systematisk avvik mot easy@work, og ingen stasjon
// kunne noen gang blitt snudd.
//
// STANDARD ER AT PAUSEN ER BETALT, og det er ikke en forsiktighetsregel.
// Med én til to på jobb kan folk sjelden forlate stasjonen, og da er
// pausen arbeidstid etter aml. § 10-9. En stasjon der de faktisk går
// fra, setter flagget selv.
//
// TALLENE UNDER ER LOVENS MINSTEKRAV, ikke Kelsars praksis. En kjede med
// tariffavtale kan ha andre — derfor står de som navngitte konstanter og
// ikke som tall midt i en beregning. Blir de ulike per kjede, skal de
// bli data, ikke et nytt sted å huske på.
// =====================================================================

/**
 * aml. § 10-9: arbeid over 5½ time gir rett til minst én pause.
 * Er den ubetalt, er det her trekket begynner.
 */
export const PAUSE_TERSKEL_MIN = 5.5 * 60

/**
 * aml. § 10-9: er arbeidsdagen 8 timer eller mer, skal pausene til
 * sammen være minst 30 minutter.
 */
export const PAUSE_MIN = 30

export type Pauseregel = {
  /** Fra `retailers.stempling_pause_betalt`. */
  betalt: boolean
}

/**
 * Minuttene som skal telles for en vakt.
 *
 * Er pausen betalt, er svaret hele vakta. Ellers trekkes pausen fra alt
 * over terskelen.
 *
 * TREKKER ALDRI SÅ MYE AT VAKTA BLIR KORTERE ENN TERSKELEN. En vakt på
 * 5 timer og 40 minutter skal ikke bli til 5 timer og 10 — da ville et
 * kvarters ekstra arbeid gitt tjue minutter mindre betalt, og det er et
 * tall ingen kan forklare til den det gjelder.
 */
export function tellbareMinutter(minutter: number, regel: Pauseregel): number {
  if (regel.betalt) return minutter
  if (minutter <= PAUSE_TERSKEL_MIN) return minutter
  return Math.max(PAUSE_TERSKEL_MIN, minutter - PAUSE_MIN)
}

/** Minuttene som trekkes. `tellbareMinutter` er fasit; dette er til visning. */
export function pausetrekk(minutter: number, regel: Pauseregel): number {
  return minutter - tellbareMinutter(minutter, regel)
}
