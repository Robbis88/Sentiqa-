// =====================================================================
// UKEBRIEF, SLOTT 3 (12:00 UTC mandag) — TYNN INNGANG, INGEN EGEN LOGIKK
// =====================================================================
//
// EKSPERIMENT: omgaaelse av Vercels `invalid_routes`-regresjon, som
// siden 2026-09-15 ser ut til aa avvise flere cron-oppfoeringer med
// samme path. Hele begrunnelsen — inkludert at Vercel selv DOKUMENTERER
// moensteret vi maatte forlate — staar i `../ukebrief-slott-1/route.ts`.
//
// SISTE SJANSE I UKA. Uke 35 ble sendt foerst her, kl. 12:00, etter at
// slott 1 og 2 hadde gaatt uten aa levere. Det er grunnen til at det
// finnes tre og ikke to.
//
// Handleren re-eksporteres. Den er IKKE kopiert: senderegler, datakrav,
// mottakere og logging bor ett sted.
// =====================================================================

export { GET, maxDuration } from '../ukebrief/route'
