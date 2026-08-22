import { revalidatePath } from 'next/cache'

// =====================================================================
// Svaret en handling gir tilbake til den som trykket.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// `maaLykkes` (skriv-svar.ts) er gulvet: den sørger for at en feil ikke
// blir borte. Men den kaster, og en feilside er ikke en kvittering — den
// river brukeren ut av sida og forteller ingenting om hva som virket.
// Denne er nivået over: handlingen svarer med tekst, og knappen viser
// den der den står.
//
// HVORFOR ÉN FUNKSJON OG IKKE TJUE. Sletting finnes 22 steder. Skrives
// kvitteringen på nytt hvert sted, blir den ulik hvert sted, og ett av
// dem blir glemt. Da er det stedet umulig å skille fra de andre uten å
// lese koden.
// =====================================================================

/** `undefined` er starttilstanden: ingenting er forsøkt ennå. */
export type Kvittering = { ok?: string; feil?: string } | undefined

type Svar = {
  error: { message: string; code?: string } | null
  count?: number | null
}

/**
 * Kjører et skriv og svarer med tekst.
 *
 * NULL RADER ER OGSÅ ET SVAR, og det viktigste av dem. `delete ... where
 * id = x` som ikke treffer noen rad er ikke en feil for PostgREST — den
 * er en vellykket operasjon på ingenting. Er raden filtrert bort av RLS,
 * ser det identisk ut med å ha lykkes, og det var nettopp den
 * forvekslingen som gjorde «det går ikke an å lagre» uetterrettelig.
 *
 * Tellingen krever `{ count: 'exact' }` på kallet. Mangler den, er
 * `count` null, og da sier vi det i stedet for å påstå noe vi ikke vet.
 */
export async function kvitter(
  skriv: PromiseLike<Svar>,
  opts: { hva: string; ok: string; oppfrisk?: string[] },
): Promise<Kvittering> {
  const { error, count } = await skriv

  if (error) {
    // Koden skiller de tre vanlige årsakene: 42501 er RLS, 23503 er
    // fremmednøkkel, 23505 er dublett.
    const kode = error.code ? ` [${error.code}]` : ''
    return { feil: `Kunne ikke ${opts.hva}${kode}: ${error.message}` }
  }

  if (count === 0) {
    return {
      feil: `Ingenting å ${opts.hva} — raden finnes ikke, `
        + 'eller du har ikke tilgang til den.',
    }
  }

  for (const sti of opts.oppfrisk ?? []) revalidatePath(sti)
  return { ok: opts.ok }
}
