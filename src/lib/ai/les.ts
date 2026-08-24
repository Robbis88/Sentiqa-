// =====================================================================
// Ett sted som leser fra basen for AI-en, og som aldri mister feilen.
//
// PORT 0: hvert eneste leseverktøy skrev `const { data } = await ...`.
// `error` ble aldri destrukturert. En RLS-blokkering, en statement
// timeout, et view som ikke finnes og «null rader» ga identisk `[]`.
//
// Regelen er nå: ingen Supabase-feil kan bli til en tom liste. Enten
// kommer det rader, eller så kommer det en feil med årsak.
// =====================================================================

/** Postgres/PostgREST-koder som betyr «kilden finnes ikke», ikke «tomt». */
const MANGLER_KILDE = new Set([
  '42P01', // undefined_table — view/tabell droppet eller migrasjon ikke kjørt
  '42703', // undefined_column — kolonne fjernet under føttene på oss
  '42883', // undefined_function
  'PGRST202', // funksjon ikke i skjema-cachen
  'PGRST205', // tabell ikke i skjema-cachen
])

/** Koder som betyr at spørringen ble avbrutt — svaret er ukjent, ikke tomt. */
const AVBRUTT = new Set([
  '57014', // query_canceled (statement timeout — se AGENTS.md om RLS-ytelse)
  '53300', // too_many_connections
])

export type Lesefeil = {
  feil: string
  manglerKilde: boolean
  avbrutt: boolean
  kode?: string
}

export type Leseresultat<T> = { rader: T[] } | Lesefeil

export function erLesefeil<T>(r: Leseresultat<T>): r is Lesefeil {
  return (r as Lesefeil).feil !== undefined
}

type SupabaseSvar<T> = { data: T[] | null; error: { message: string; code?: string } | null }

/**
 * Kjører en spørring og skiller feil fra fravær.
 *
 * Merk at «rader: []» fortsatt er et gyldig utfall — det betyr at
 * spørringen gikk bra og ingen rader matchet. Det er `byggSvar` som
 * avgjør om det skal leses som `ingen_registrering` eller `malt_null`;
 * her handler det bare om at forskjellen overlever turen hit.
 */
export async function les<T>(
  spørring: PromiseLike<SupabaseSvar<T>>,
  hva: string,
): Promise<Leseresultat<T>> {
  let svar: SupabaseSvar<T>
  try {
    svar = await spørring
  } catch (e) {
    return {
      feil: `Oppslaget mot ${hva} kastet: ${e instanceof Error ? e.message : String(e)}`,
      manglerKilde: false,
      avbrutt: false,
    }
  }

  if (svar.error) {
    const kode = svar.error.code
    const manglerKilde = kode != null && MANGLER_KILDE.has(kode)
    const avbrutt = kode != null && AVBRUTT.has(kode)
    return {
      feil: manglerKilde
        ? `Kilden ${hva} finnes ikke i databasen (${kode}). `
          + 'Migrasjonen er sannsynligvis ikke kjørt. Dette er IKKE det '
          + 'samme som at det ikke finnes data.'
        : avbrutt
          ? `Oppslaget mot ${hva} ble avbrutt (${kode}). Svaret er ukjent.`
          : `Oppslaget mot ${hva} feilet: ${svar.error.message}`,
      manglerKilde,
      avbrutt,
      kode,
    }
  }

  return { rader: svar.data ?? [] }
}

/**
 * Leser flere spørringer og gir opp ved første feil.
 *
 * Brukes av verktøy som krysser to kilder: kan den ene ikke leses, er
 * ikke beregningen halvveis riktig — den er ukjent.
 */
export async function lesAlle<T extends readonly unknown[]>(
  spørringer: { [K in keyof T]: [PromiseLike<SupabaseSvar<T[K]>>, string] },
): Promise<{ rader: { [K in keyof T]: T[K][] } } | Lesefeil> {
  const svar = await Promise.all(
    (spørringer as [PromiseLike<SupabaseSvar<unknown>>, string][]).map(([q, hva]) =>
      les(q, hva),
    ),
  )
  for (const s of svar) if (erLesefeil(s)) return s
  return {
    rader: svar.map((s) => (s as { rader: unknown[] }).rader) as {
      [K in keyof T]: T[K][]
    },
  }
}
