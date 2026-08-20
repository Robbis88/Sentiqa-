// =====================================================================
// Hvilken stasjon ser jeg på?
//
// Ti sider spurte om det hver for seg. Butikksjefen med én stasjon svarte
// på det samme spørsmålet ti ganger, og fikk aldri et annet svar.
//
// Nå velges det ett sted og huskes. Reglene under er hele mekanikken, og
// rekkefølgen er den viktige delen:
//
//   1  URL-en vinner alltid. En delt lenke skal vise det den lovet,
//      uansett hva mottakeren valgte sist.
//   2  Så det man valgte sist.
//   3  Så det fornuftige: én stasjon for butikksjefen, hele porteføljen
//      for eieren der siden tåler det.
//
// Snur man 1 og 2, blir dyplenker upålitelige — og det oppdages ikke før
// noen sender en lenke til feil tall.
// =====================================================================

export type Stasjon = { id: string; navn: string; butikknummer?: string }

/** `null` betyr «alle stasjoner samlet», og er en gyldig verdi — ikke et tomt valg. */
export type Valg = string | null

export function velgStasjon(
  alle: Stasjon[],
  opts: {
    fraUrl?: string | null
    fraHukommelse?: string | null
    /** Tåler siden å vise alle stasjoner samlet? De færreste gjør det. */
    tillatAlle?: boolean
  } = {},
): Valg {
  const { fraUrl, fraHukommelse, tillatAlle = false } = opts
  if (alle.length === 0) return null

  const finnes = (id: string | null | undefined) =>
    id != null && alle.some((s) => s.id === id)

  // «alle» er et eksplisitt valg, ikke fravær av et valg.
  if (fraUrl === 'alle') return tillatAlle ? null : alle[0].id
  if (finnes(fraUrl)) return fraUrl!

  if (fraHukommelse === 'alle') return tillatAlle ? null : alle[0].id
  // En husket stasjon som ikke finnes lenger — slettet, eller en bruker
  // som byttet kjede — skal falle tilbake, ikke gi tom side.
  if (finnes(fraHukommelse)) return fraHukommelse!

  return tillatAlle ? null : alle[0].id
}

/** Skal velgeren i det hele tatt vises? */
export function visVelger(alle: Stasjon[], tillatAlle: boolean): boolean {
  // Én stasjon og ingen porteføljevisning er ikke et valg. Å vise en
  // nedtrekksliste med ett alternativ er å be om en beslutning som ikke
  // finnes.
  return alle.length > 1 || (alle.length === 1 && tillatAlle)
}

/**
 * «Alle stasjoner», skrevet ned ett sted.
 *
 * TRE TILSTANDER SOM IKKE ER DEN SAMME, og som ble blandet før:
 *
 *   'alle'      Brukeren har VALGT å se stasjonene samlet.
 *   undefined   Ingenting er valgt ennå — førstegangsbrukeren.
 *   ''          Fantes i URL-er og betydde begge deler.
 *
 * Derfor en sentinel med et navn, ikke tom streng og ikke `null` på veien
 * gjennom en informasjonskapsel. `null` er domeneverdien inne i koden;
 * 'alle' er serialiseringen ut mot URL og kapsel. Oversettelsen skjer i
 * `tilLagring` og `fraLagring`, og ingen andre steder.
 */
export const ALLE = 'alle'

/** Domeneverdi → URL/informasjonskapsel. */
export const tilLagring = (valg: Valg): string => valg ?? ALLE

/** URL/informasjonskapsel → domeneverdi. Tom streng er «ikke valgt». */
export const fraLagring = (raa: string | null | undefined): string | null =>
  raa == null || raa === '' ? null : raa

/**
 * Rutene som tåler at flere stasjoner summeres.
 *
 * STANDARDEN ER «KREVER ÉN STASJON», og det er med vilje: en ny side som
 * glemmer å ta stilling får den trygge oppførselen. Å summere noe som
 * ikke kan summeres gir et tall som ser riktig ut og er feil —
 * produksjonsplanen for «alle stasjoner» er ikke en plan noen kan bake
 * etter.
 *
 * Lista er sidens EVNE, ikke brukerens rettighet. Rettigheten kommer fra
 * RLS og fra hvor mange stasjoner brukeren faktisk har.
 */
export const TAALER_AGGREGAT = new Set([
  '/oversikt',   // eierens portefølje — hele poenget med forsiden hans
  '/salg',
  '/svinn',
  '/timesalg',
  '/kasserer',
  '/regnskap',   // admin-grenen summerer kjeden; butikksjef-grenen har én
])

export const sidenTaalerAggregat = (sti: string): boolean =>
  TAALER_AGGREGAT.has(sti.replace(/\/+$/, '') || '/')

/**
 * Stasjonen URL-en ber om — uansett hvilket navn parameteren har.
 *
 * To parametre finnes i systemet, og begge skal fortsette å virke:
 *
 *   ?stasjon=<uuid>      de fleste sidene
 *   ?stasjon=alle        eksplisitt aggregat
 *   ?butikknummer=4177   /produksjonsplan, /regnskap, /utsolgt
 *
 * Butikknummeret oversettes til id her, slik at ALT annet i systemet kan
 * forholde seg til id-er. Uten den oversettelsen måtte appskallet kjenne
 * hver sides parameternavn — og da ville skallet og siden før eller
 * siden svart forskjellig på det samme spørsmålet.
 *
 * Ukjent verdi gir `undefined`, ikke et kast: en delt lenke med en
 * stasjon mottakeren ikke har tilgang til skal falle tilbake pent, ikke
 * feile. Det er også vernet mot at en URL kan skrive noe ugyldig inn i
 * det huskede valget.
 */
export function stasjonFraUrl(
  sok: URLSearchParams,
  stasjoner: Stasjon[],
): string | undefined {
  const stasjon = sok.get('stasjon')
  if (stasjon === ALLE) return ALLE
  if (stasjon && stasjoner.some((s) => s.id === stasjon)) return stasjon

  const nr = sok.get('butikknummer')
  if (nr) {
    const treff = stasjoner.find((s) => s.butikknummer === nr)
    if (treff) return treff.id
  }
  return undefined
}

/** Navnet slik det vises: «9467 Bønes», eller bare navnet om nummer mangler. */
export const stasjonsnavn = (s: Stasjon) =>
  (s.butikknummer ? `${s.butikknummer} ${s.navn}` : s.navn)
