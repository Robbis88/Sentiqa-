// =====================================================================
// UKEBRIEF, SLOTT 2 (08:00 UTC mandag) — TYNN INNGANG, INGEN EGEN LOGIKK
// =====================================================================
//
// EKSPERIMENT: omgaaelse av Vercels `invalid_routes`-regresjon, som
// siden 2026-09-15 ser ut til aa avvise flere cron-oppfoeringer med
// samme path. Hele begrunnelsen — inkludert at Vercel selv DOKUMENTERER
// moensteret vi maatte forlate — staar i `../ukebrief-slott-1/route.ts`.
//
// Dette er slottet som faktisk leverte 5/5 den 2026-09-14, da slott 1
// sendte ingenting fordi ukegrunnlaget var ufullstendig.
//
// Handleren re-eksporteres. Den er IKKE kopiert: senderegler, datakrav,
// mottakere og logging bor ett sted.
// =====================================================================

export { GET, maxDuration } from '../ukebrief/route'
