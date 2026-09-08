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

/**
 * PostgREST-taket. `supabase/config.toml` setter `max_rows = 1000`, og
 * det gjelder uansett hva `.limit()` sier — en `.limit(50000)` er ikke
 * en grense, den er en kommentar.
 */
export const TAK = 1000

export type Leseresultat<T> =
  | {
    rader: T[]
    /**
     * Fylte svaret PostgREST-taket?
     *
     * =================================================================
     * ET AVKORTET SVAR SOM MELDES KOMPLETT ER VERRE ENN INGEN SVAR
     * =================================================================
     * `hent_salg` ba om hittil-i-år for fem stasjoner — over 400 000
     * rader på varenivå — med `.limit(50000)`. Den fikk tusen, og
     * `avkortet` ble regnet ETTER at radene var aggregert ned til åtte.
     * Åtte er mindre enn grensen, så svaret ble merket komplett.
     *
     * Modellen fikk altså omsetningen for de første dagene av året,
     * presentert som årets tall. Det er den verste formen: tallet er
     * troverdig, og ingenting i svaret sier noe annet.
     *
     * Dette flagget settes på RÅ radtall, før aggregering, og gjør
     * `komplett` usann hele veien ut.
     *
     * VALGFRITT, OG DET ER EN AVVEINING. Noen verktøy bygger radene
     * sine selv — de summerer i basen eller krysser to kilder — og der
     * finnes det ikke ett råtall å måle. `undefined` leses som «ikke
     * målt», altså ikke avkortet. Bygger du rader selv OG kan bli
     * avkortet, må du sette den.
     */
    taketTruffet?: boolean
  }
  | Lesefeil

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

  const rader = svar.data ?? []
  return { rader, taketTruffet: rader.length >= TAK }
}

/**
 * Leser flere spørringer og gir opp ved første feil.
 *
 * Brukes av verktøy som krysser to kilder: kan den ene ikke leses, er
 * ikke beregningen halvveis riktig — den er ukjent.
 */
export async function lesAlle<T extends readonly unknown[]>(
  spørringer: { [K in keyof T]: [PromiseLike<SupabaseSvar<T[K]>>, string] },
): Promise<{ rader: { [K in keyof T]: T[K][] }; taketTruffet: boolean } | Lesefeil> {
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
    // ÉN AVKORTET KILDE GJØR HELE KRYSSINGEN AVKORTET. Den som krysser
    // to kilder regner ikke halvveis riktig når den ene er delvis —
    // den regner feil, og med et tall som ser komplett ut.
    taketTruffet: svar.some((s) => (s as { taketTruffet?: boolean }).taketTruffet === true),
  }
}
