// =====================================================================
// En skrivende handling skal ikke kunne svelge feilen sin.
//
// PERMANENT KONTRAKT, satt av Robert 2026-08-21:
//
//   «Ingen skrivende serverhandling på denne flaten skal kunne returnere
//    som om alt gikk bra dersom Supabase faktisk returnerte en feil.»
//
// Bakgrunnen: `settDekning` returnerte `void` og ignorerte `{ error }`.
// En avvist lagring så nøyaktig ut som en vellykket — knappen ble
// trykket, siden lastet, ingenting hadde skjedd. Robert meldte «det går
// ikke an å lagre», og hadde ingenting å gå på. Feilsøkingen ble
// gjetting i stedet for observasjon.
//
// HVORFOR KASTE, OG IKKE BARE LOGGE. En logg leses av den som allerede
// vet at noe er galt. Den som trykker på knappen får fortsatt et grønt
// bilde av noe som ikke skjedde. Å kaste er den svakeste formen som
// likevel er sann: brukeren ser at det gikk galt, og feilteksten sier
// hva. Vil man ha en pen kvittering i stedet, tar handlingen imot
// `{ error }` selv og svarer med tekst — det er BEDRE enn dette, ikke
// noe dette erstatter.
//
// GRENSEN: RLS som stopper en rad gir ofte `error: null` og null rader,
// ikke en feil. Da fanger ikke denne noe. Se `antallEllerFeil` for de
// stedene der det å treffe en rad ER poenget.
// =====================================================================

/** Formen PostgREST svarer med. Vi trenger bare feilen og antallet. */
export type Skrivesvar = {
  error: { message: string; code?: string; details?: string | null } | null
  count?: number | null
}

/**
 * Kaster hvis skrivingen feilet. Returnerer svaret ellers.
 *
 * `hva` skal si hva som ble forsøkt, med ord brukeren kjenner igjen:
 * «slette lenke», ikke «delete on lenker». Teksten havner foran øynene
 * på den som trykket.
 */
export function maaLykkes<T extends Skrivesvar>(svar: T, hva: string): T {
  if (svar.error) {
    // Koden er med fordi den skiller de tre vanlige årsakene fra
    // hverandre uten at noen må gjette: 42501 er RLS, 23503 er en
    // fremmednøkkel, 23505 er en dublett.
    const kode = svar.error.code ? ` [${svar.error.code}]` : ''
    throw new Error(`Klarte ikke ${hva}${kode}: ${svar.error.message}`)
  }
  return svar
}

/**
 * Som `maaLykkes`, men krever også at minst én rad ble truffet.
 *
 * FOR DE STEDENE DER STILLHETEN ER FEILEN. En `update ... where id = x`
 * som ikke treffer noen rad er ikke en feil for PostgREST — den er en
 * vellykket operasjon på null rader. Er raden filtrert bort av RLS,
 * eller finnes id-en ikke, ser det identisk ut med å ha lykkes.
 *
 * Krever `{ count: 'exact' }` på kallet. Uten det er `count` null, og da
 * kastes det — en stille `count: null` ville gjort denne til pynt.
 */
export function traffEnRad<T extends Skrivesvar>(svar: T, hva: string): T {
  maaLykkes(svar, hva)
  if (svar.count == null) {
    throw new Error(
      `Kan ikke bekrefte at «${hva}» traff noe: kallet mangler `
      + "{ count: 'exact' }.",
    )
  }
  if (svar.count === 0) {
    throw new Error(
      `Ingen rader ble endret da vi forsøkte å ${hva}. `
      + 'Enten finnes ikke raden, eller så har du ikke tilgang til den.',
    )
  }
  return svar
}

/**
 * Samme kontrakt for en bunke skriv som gikk parallelt.
 *
 * DRAG-AND-DROP-REKKEFØLGE er den typiske: tolv `update`-kall sendes med
 * `Promise.all`, og feiler ett av dem, har lista fått en rekkefølge som
 * ikke finnes noe sted. Uten denne ville hele bunken sett vellykket ut
 * så lenge Promise-en løste seg — og det gjør den også når PostgREST
 * svarer med en feil i hvert eneste svar.
 *
 * Feiler flere, meldes den første. Årsaken er nesten alltid den samme.
 */
export function alleMaaLykkes<T extends Skrivesvar>(svar: T[], hva: string): T[] {
  for (const s of svar) maaLykkes(s, hva)
  return svar
}
