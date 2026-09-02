// =====================================================================
// POSTGRES-KODENE APPEN FAKTISK REAGERER PÅ
//
// Koder, aldri meldingstekst. `error.message.includes('duplicate')` sto i
// `bekreftLest`, og det er engelsk PostgREST-prosa som kan endres uten
// varsel — blir den det, får brukeren en rå databasefeil i ansiktet på en
// helt normal handling. Kodene er en del av Postgres' kontrakt og endrer
// seg ikke.
//
// Samme skille som tenant-matrisen bygger på (se AGENTS.md): `42501` er en
// sikkerhetsavvisning, `23505` er en domenefeil. Å blande dem er å la en
// kollisjon se ut som et vern.
// =====================================================================

/** unique_violation — raden finnes fra før. */
export const DUBLETT = '23505'

/** insufficient_privilege — RLS eller en manglende rettighet avviste. */
export const AVVIST = '42501'
