// =====================================================================
// Sykefraværsreserven: den skal være KJEDENS, ikke stasjonens.
//
// St1s timeramme fordeles etter to fradrag før butikksjefen ser den:
// 3 % sikkerhet og en reserve for sykefravær. Robert, 2026-08-21:
//
//   «De 3 % som holdes av er marginer som aldri skal deles ut, heller
//    ikke historisk sykefravær. De skal holdes tilbake som retailer sin
//    sikkerhet … men stasjoner med lite sykefravær skal ikke bli
//    straffet. Derfor 3 % og gjennomsnitt sykelønn skal trekkes fra.
//    Sykelønn finner du i regnskapet.»
//
// FØR: `max(stasjonens egen sats, kjedens snitt)`. En stasjon med høyt
// fravær fikk trukket MER, altså mindre å planlegge med — og det er
// dobbelt straff: den har allerede færre hender på jobb.
//
// NÅ: kjedens snitt for alle. Fradraget er eierens margin, og en margin
// skal ikke variere med hvem som er syk. Variasjonen i sykefravær vises
// der den hører hjemme — i timeregnskapet, som et forbruk — i stedet
// for å bli gjemt i en større avkortning.
//
// TALLET KOMMER FRA REGNSKAPET, ikke fra et anslag: sykelønnskontiene
// mot lønnskontiene, siste tolv måneder.
// =====================================================================

/** Lønn som belaster rammen. `503` er timelønn, resten faste tillegg. */
export const LONNSKONTI = ['501', '502', '503', '508', '540', '541'] as const

/** Refundert og arbeidsgiverperiode. Det er dette som ikke ble arbeid. */
export const SYKEKONTI = ['505', '506'] as const

export type Regnskapsrad = { stasjon_id: string; kode: string; regnskap: number | null }

/**
 * Kjedens sykefraværssats i prosent av lønn.
 *
 * ETT TALL FOR ALLE STASJONER. Det er hele poenget: to stasjoner med
 * ulikt sykefravær skal få like stor avkortning, slik at forskjellen
 * mellom dem blir synlig i resultatet i stedet for å bli utlignet i
 * rammen.
 *
 * Ingen lønn i grunnlaget → 0. Ikke et anslag, ikke en standardsats:
 * en reserve vi ikke har grunnlag for å ta, tar vi ikke.
 */
export function kjedensSykesats(rader: Regnskapsrad[]): number {
  let lonn = 0
  let syke = 0
  for (const r of rader) {
    const v = r.regnskap ?? 0
    if ((SYKEKONTI as readonly string[]).includes(r.kode)) syke += v
    else lonn += v
  }
  return lonn > 0 ? (syke / lonn) * 100 : 0
}
