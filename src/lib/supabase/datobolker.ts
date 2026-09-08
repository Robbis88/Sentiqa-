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
export const TAK = 1000

/** Under denne blir det flere rundturer enn det er verdt. */
const MINSTE_BOLK = 2

// HVORFOR TJUE DAGER OG IKKE TRETTI.
//
// Produksjonssalget er ~12 000 rader paa et aar, altsaa rundt 33 per dag.
// Tretti dager gir ~990 - rett under taket paa 1000, saa naer at nesten
// hver eneste bolk ville delt seg og gitt DOBBELT saa mange rundturer som
// noedvendig. Riktig svar, men tregere enn det trengte aa vaere.
//
// Tjue dager gir ~660. Marginen er der for at delingen skal vaere
// unntaket, ikke regelen - den finnes for stasjoner som selger mer enn
// snittet, ikke for normaltilfellet.

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
  dagerPerBolk = 20,
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

/**
 * Tar imot en spoerring som IKKE er delt i datobolker, og krever at den
 * er hel.
 *
 * =====================================================================
 * ET TAK MAN IKKE VET OM ER DET FARLIGSTE TAKET
 * =====================================================================
 * PostgREST returnerer tusen rader og sier ingenting. Rutinesida hadde
 * ikke én `.limit()` - og `rutine_utforinger` for dagens vaktdatoer,
 * over alle stasjoner, ligger rundt tusen rader. Naar taket traff, falt
 * Boenes sine avhukinger utenfor, og sida meldte 68 rutiner igjen som
 * folk nettopp hadde gjort ferdig.
 *
 * Det ser ikke ut som en feil. Det ser ut som at ingen har gjort jobben
 * sin.
 *
 * BRUK EN GENEROES `.limit()` OG SEND DEN HIT. Grensen er ikke et
 * oenske om faerre rader - den er et sted aa oppdage at det ble for
 * mange. Kan spoerringen i det hele tatt naa den, mangler den en
 * avgrensning, og da skal den kastes framfor aa svare halvt.
 *
 * Samme fella som `.limit(50000)` (0090, 0166, 0175) og som
 * `hentPerDato` loeser for datoserier - bare med et annet ansikt.
 */
export function maaVaereHele<T>(svar: Svar<T>, hva: string, tak = TAK): T[] {
  if (svar.error) throw new Error(`Kunne ikke lese ${hva}: ${svar.error.message}`)
  const rader = svar.data ?? []

  // =================================================================
  // TAKET ER TUSEN, UANSETT HVA KALLEREN BAD OM
  // =================================================================
  // `supabase/config.toml` setter `max_rows = 1000`. En `.limit(20000)`
  // gir derfor ALDRI mer enn tusen rader - og en sjekk paa
  // `rader.length >= 20000` kan aldri utloeses.
  //
  // Foerste utgave av denne funksjonen gjorde noeyaktig det. Den ble
  // skrevet for aa fange «68 rutiner igjen», og var inert paa hvert
  // eneste kallsted som brukte et generoest tall: 10000 paa rutinene,
  // 20000 paa utfoeringene. En vakt som ikke kan feile ser noeyaktig ut
  // som en vakt som ikke finner noe - og den var min egen, samme dag.
  //
  // `Math.min` gjoer at kalleren kan senke taket, aldri heve det. En
  // `.limit()` over tusen er ikke en grense; den er en kommentar.
  const effektivt = Math.min(tak, TAK)
  if (rader.length >= effektivt) {
    throw new Error(
      `${hva} ga ${rader.length} rader og traff taket paa ${effektivt}`
      + (tak > TAK ? ` (kalleren bad om ${tak}, men PostgREST gir aldri mer enn ${TAK})` : '')
      + '. Svaret kan vaere avkortet, og et avkortet svar ser ut som ekte tall. '
      + 'Avgrens spoerringen, del den i datobolker, eller summer i basen.',
    )
  }
  return rader
}
