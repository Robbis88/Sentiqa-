import { leggTilDager } from '@/lib/produksjonsplan'

// =====================================================================
// ET ÅR MED SALG, UTEN DYPE OFFSETS
//
// `hentAlle` sider med `.range(side * 1000, ...)`. Det virker, men det
// er både SEKVENSIELT og KVADRATISK:
//
//   * Tolv rundturer etter hverandre. Hver venter på den forrige.
//   * `range(11000, 11999)` tvinger Postgres til å sortere HELE
//     årsmaterialet og så kaste de elleve tusen første. Siste side er
//     den dyreste, og kostnaden vokser med kvadratet av antall sider.
//
// Målt på /produksjonsplan: 30-60 sekunder for én stasjon. Det er ikke
// en treg spørring - det er tolv spørringer som blir tregere for hver.
//
// Her deles perioden i DATOBOLKER i stedet. Hver bolk er sin egen
// spørring med et smalt `between`, som treffer indeksen på (stasjon,
// dato) og aldri hopper over noe. Og de kjøres samtidig.
//
// ---------------------------------------------------------------------
// TAKET MÅ FORTSATT VOKTES
//
// PostgREST kutter på tusen rader uten å si fra. En bolk som treffer
// taket kan være avkortet, og et avkortet år ser ut som en rolig
// periode - ikke som en feil. Derfor: treffer en bolk taket, deles den
// i to og hentes på nytt. Den kan ikke returnere stille avkortet.
//
// Det er samme fella som `.limit(50000)` (0090, 0166, 0175), bare med
// et annet ansikt.
// =====================================================================

/** PostgREST-taket. En bolk som naar det, er mistenkt avkortet. */
const TAK = 1000

/** Under denne blir det flere rundturer enn det er verdt. */
const MINSTE_BOLK = 2

export type Svar<T> = { data: T[] | null; error: { message: string } | null }

/**
 * Henter alle radene i en periode, bolk for bolk, i parallell.
 *
 * `lagQuery` må lage en NY spørring hvert kall — en PostgREST-builder
 * kan ikke kjøres to ganger.
 *
 * KASTER ved feil. Et halvt datasett er verre enn ingen: summene ville
 * sett riktige ut og vært for lave.
 */
export async function hentPerDato<T>(
  lagQuery: (fra: string, til: string) => PromiseLike<Svar<T>>,
  fra: string,
  til: string,
  dagerPerBolk = 30,
): Promise<T[]> {
  if (til < fra) return []

  const bolker: [string, string][] = []
  for (let start = fra; start <= til;) {
    const slutt = minst(leggTilDager(start, dagerPerBolk - 1), til)
    bolker.push([start, slutt])
    start = leggTilDager(slutt, 1)
  }

  const deler = await Promise.all(
    bolker.map(([b0, b1]) => hentBolk(lagQuery, b0, b1, dagerPerBolk)),
  )
  return deler.flat()
}

const minst = (a: string, b: string) => (a < b ? a : b)

/**
 * Én bolk, med deling ved mistenkt avkorting.
 *
 * NØYAKTIG TUSEN RADER ER MISTENKELIG, ikke bevist avkortet - det kan
 * være et tilfeldig sammentreff. Men å behandle det som et treff koster
 * to ekstra spørringer i det sjeldne tilfellet, mens å behandle det som
 * fullstendig koster et stille hull i dataene. Prisen er ikke i nærheten
 * av å være symmetrisk.
 */
async function hentBolk<T>(
  lagQuery: (fra: string, til: string) => PromiseLike<Svar<T>>,
  fra: string,
  til: string,
  dager: number,
): Promise<T[]> {
  const { data, error } = await lagQuery(fra, til)
  if (error) throw new Error(`hentPerDato (${fra}..${til}): ${error.message}`)
  const rader = data ?? []
  if (rader.length < TAK) return rader

  // Én dag som alene fyller taket kan ikke deles mer. Da er det ikke
  // paginering som mangler - det er en spørring uten avgrensning.
  if (dager <= MINSTE_BOLK) {
    throw new Error(
      `hentPerDato: ${fra}..${til} fyller PostgREST-taket på ${TAK} rader `
      + 'og kan ikke deles mindre — spørringen mangler en avgrensning',
    )
  }

  const halv = Math.max(MINSTE_BOLK, Math.ceil(dager / 2))
  return hentPerDato(lagQuery, fra, til, halv)
}
