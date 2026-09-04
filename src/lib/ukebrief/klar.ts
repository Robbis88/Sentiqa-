// =====================================================================
// ER UKEN FERDIG NOK TIL AA SENDES?
//
// Salgsfila kommer natten etter. Kjoerer utsendingen foer soendagens tall
// har landet, regnes uken paa seks dager — og da er ikke brevet «litt
// ufullstendig», det er FEIL. Omsetningen er for lav, veksten mot i fjor
// er et tall som ikke finnes, og overskriften sier «svak uke» om en uke
// som var normal.
//
// Verre: duplikatsperren gjoer sin jobb. Brevet er registrert som sendt,
// og naar tallene kommer kl. 09.30 sendes ingen ny versjon. Det gale
// tallet blir staaende som ukens brev.
//
// ---------------------------------------------------------------------
// DERFOR VENTER VI, OG DERFOR VENTER VI IKKE FOR LENGE
//
// Gjentatte kjoeringer er trygge — det var nettopp dét den partielle
// unike indeksen var til for. Saa jobben kan gaa flere ganger mandag
// morgen og sende foerst naar uken er hel.
//
// Men en frist maa finnes. Kommer fila aldri, ville butikksjefen sittet
// uten brev uten aa vite hvorfor, og et brev som aldri kommer er verre
// enn et med forbehold: forbeholdet kan hun lese, stillheten kan hun ikke.
//
// ---------------------------------------------------------------------
// HVORFOR SISTE DAG, OG IKKE «ALLE SJU»
//
// Feilen vi venter paa er at fila ikke har kommet ennaa, og den viser
// seg alltid bakerst: soendagen mangler. Et hull midt i uken er noe
// HELT ANNET — en dag som aldri kom — og aa vente paa den ville betydd
// at brevet aldri gikk. Da ville vi ventet evig paa noe som ikke skjer.
// =====================================================================

/**
 * Naar vi gir opp aa vente. Oslo-minutter siden midnatt.
 *
 * 13.00: importen har hatt hele formiddagen, og brevet naar fortsatt
 * butikksjefen paa en mandag. Senere enn dette leses det ikke samme dag.
 */
export const FRIST_MIN = 13 * 60

export type Sendeklar =
  | { send: true; ufullstendig: boolean }
  | { send: false; grunn: 'venter_paa_salgstall' }

export function klarTilSending(opts: {
  /** Siste dato med salg for stasjonen, eller null om uken er helt tom. */
  sisteDagMedSalg: string | null
  /** Soendagen i uken brevet gjelder. */
  sisteDagIUken: string
  /** Minutter siden midnatt, Oslo-tid. */
  naaMinutter: number
}): Sendeklar {
  if (opts.sisteDagMedSalg === opts.sisteDagIUken) return { send: true, ufullstendig: false }
  // Fristen naadd: send likevel, men brevet VET at det er ufullstendig —
  // `hull` staar allerede under «Dette vet vi ikke».
  if (opts.naaMinutter >= FRIST_MIN) return { send: true, ufullstendig: true }
  return { send: false, grunn: 'venter_paa_salgstall' }
}
