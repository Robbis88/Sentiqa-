// =====================================================================
// UKEBRIEF, SLOTT 1 — TYNN INNGANG, INGEN EGEN LOGIKK
// =====================================================================
//
// EKSPERIMENT, IKKE EN AVGJORT LOESNING. Denne fila finnes for aa teste
// én hypotese: at Vercels `invalid_routes` skyldes at validatoren deres
// siden 2026-09-15 avviser flere cron-oppfoeringer med SAMME path.
//
// ---------------------------------------------------------------------
// HVA SOM SKJEDDE
// ---------------------------------------------------------------------
//
// `vercel.json` hadde tre oppfoeringer mot `/api/cron/ukebrief` med tre
// ulike schedules. Natt til 2026-09-15 begynte hver produksjonsdeploy aa
// feile paa `Deploying outputs...` med `invalid_routes` — ogsaa for en
// commit som var deployet groent kvelden foer. Kode, byggcache og
// betaling er utelukket ved maaling.
//
// ---------------------------------------------------------------------
// KONFIGURASJONEN VAR IKKE FEIL
// ---------------------------------------------------------------------
//
// Vercel DOKUMENTERER flere schedules mot samme path:
// https://vercel.com/docs/cron-jobs/manage-cron-jobs — «Define multiple
// cron schedules for a single API path» — og gir til og med headeren
// `x-vercel-cron-schedule` for aa skille dem inne i handleren.
//
// Blir dette staaende, er det altsaa en OMGAAELSE av en regresjon hos
// Vercel, ikke en retting av noe galt hos oss. Naar de retter den, kan
// de tre filene fjernes og `vercel.json` peke paa `/api/cron/ukebrief`
// igjen — tre ganger, som foer.
//
// ---------------------------------------------------------------------
// HVORFOR TRE SLOTT I DET HELE TATT
// ---------------------------------------------------------------------
//
// Ikke pynt, men maalt i drift: 2026-09-14 sendte slott 1 (05:00 UTC)
// INGENTING fordi ukegrunnlaget var ufullstendig, slott 2 (08:00) sendte
// 5/5, og uke 35 gikk foerst paa slott 3 (12:00). Kollapses de til ett,
// kan ukebriefen stille slutte aa gaa ut de ukene dagsdata kommer sent.
//
// ---------------------------------------------------------------------
// INGEN LOGIKK HER, OG DET ER POENGET
// ---------------------------------------------------------------------
//
// Handleren re-eksporteres fra `/api/cron/ukebrief`. Den er IKKE kopiert:
// senderegler, datakrav, mottakere, autorisasjon og logging bor ett sted
// og endres ett sted. To kopier av en utsendingsregel ville skilt lag.
//
// Originalruta staar uroert og virker fortsatt — den er den som brukes
// manuelt, med `?torrkjor=1` og `?uke=`.
// =====================================================================

export { GET, maxDuration } from '../ukebrief/route'
