import 'server-only'

// =====================================================================
// POSTGREST KUTTER I STILLHET
//
// Taket er tusen rader. Ber du om flere, faar du tusen - uten feil, uten
// advarsel, uten noe i svaret som sier at det var mer.
//
// For en LISTE er det en visningsfeil. For et REGNESTYKKE er det verre:
// `v_salg_per_avdeling_dag` gir en rad per (stasjon, dag, avdeling), og
// et motpartsvindu for hele kjeden er over halvannet tusen. Medianen
// ville da vaert regnet av de tusen foerste - et tilfeldig utvalg som
// ser ut som et fullstendig ett, og et budsjett bygget paa det ville
// vaert feil uten at noe pekte paa hvorfor.
//
// Derfor sider vi. `hentAlle` henter til den faar mindre enn en full
// side, og bygger spoerringen paa nytt hver gang - en PostgREST-builder
// kan ikke kjoeres to ganger.
// =====================================================================

/** PostgREST-taket. Blir det hevet i Supabase, er dette fortsatt trygt. */
const SIDE = 1000

/**
 * Alle radene, uansett hvor mange.
 *
 * `lagQuery` maa lage en NY builder hvert kall. Gjenbrukes den samme,
 * legger `.range()` seg oppaa forrige og resultatet blir tomt fra andre
 * runde - en feil som ser ut som «det finnes ikke flere rader».
 *
 * KASTER ved feil. Et halvt datasett er verre enn ingen side: summene
 * ville sett riktige ut og vaert for lave.
 */
export async function hentAlle<T>(
  lagQuery: () => {
    range: (fra: number, til: number) => PromiseLike<{ data: T[] | null; error: { message: string } | null }>
  },
  maksSider = 20,
): Promise<T[]> {
  const ut: T[] = []
  for (let side = 0; side < maksSider; side++) {
    const { data, error } = await lagQuery().range(side * SIDE, (side + 1) * SIDE - 1)
    if (error) throw new Error(`hentAlle: ${error.message}`)
    const rader = data ?? []
    ut.push(...rader)
    if (rader.length < SIDE) return ut
  }
  // Tjue sider er tjue tusen rader. Naar vi er her, er det ikke lenger
  // en stor spoerring - det er en spoerring uten filter.
  throw new Error(`hentAlle: over ${maksSider * SIDE} rader — spørringen mangler en avgrensning`)
}
