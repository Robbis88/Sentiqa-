// =====================================================================
// HVOR LANGT TILBAKE MODULENE FAKTISK LESER
//
// Onboardinglista lovet 365 dager timesalg. Bemanningen leser fra
// 1. januar TO AAR tilbake — `${ar - 2}-01-01` — fordi helligdagsfaktorene
// maales per dato, og skjaertorsdag er en dato: ett aar gir hver roed dag
// EN gang, og da er det ingen ting aa sammenligne den med.
//
// Begge tallene var riktige da de ble skrevet. De sto bare hver for seg,
// og da skiller de lag i stillhet: en retailer med 365 dager fikk groent
// paa timesalg mens halve grunnlaget for bemanningsplanen manglet.
//
// Derfor bor vinduet HER, og bare her. Modulen som leser og lista som
// lover, leser samme tall.
// =====================================================================

/**
 * Hvor mange kalenderaar tilbake bemanningens dagsgrunnlag starter.
 *
 * Brukes til å regne startdatoen (`timesalgFra`), ikke som en lengde.
 */
export const TIMESALG_AAR_TILBAKE = 2

/**
 * Startdatoen bemanningen leser timesalg og ansattmåneder fra.
 *
 * 1. januar, ikke «for to år siden»: faktorene sammenlignes per dato
 * gjennom hele kalenderåret, og et vindu som starter midt i året gir
 * halve året én observasjon og halve to.
 */
export function timesalgFra(ar: number): string {
  return `${ar - TIMESALG_AAR_TILBAKE}-01-01`
}

/**
 * Hva onboardinglista skal love for timesalg.
 *
 * To fulle år. Vinduet over er lengre — fra 1. januar to år tilbake til i
 * dag er mellom 730 og 1095 dager — men 730 er det punktet der hver rød
 * dag har vært innom to ganger, og det er kravet faktoren stiller.
 */
export const TIMESALG_ANBEFALTE_DAGER = 365 * TIMESALG_AAR_TILBAKE
