// =====================================================================
// Hvem jobber mer enn kontrakten sin — og hva slags papir mangler?
//
// Virke er tydelige: en deltidsansatt som skal kunne ta en ekstravakt
// ved sykdom trenger EN RAMMEAVTALE OM TILKALLING i tillegg til den
// faste avtalen. Uten den kan de ekstra timene senere kreves som overtid.
//
// Men det er to risikoer her, ikke én, og de krever ulikt svar:
//
//   OVERTIDSKRAV      løses av en rammeavtale om tilkalling.
//
//   § 14-4 a          gir rett til stilling tilsvarende det man FAKTISK
//                     har jobbet siste tolv måneder. En rammeavtale
//                     hjelper ikke mot den.
//
// Og en tredje sak som ser ut som den andre, men ikke er det:
//
//   SESONG            en som går 20 % hele året bortsett fra juni, juli
//                     og august jobber ikke «for mye» — hun jobber sommer.
//                     Da er svaret en MIDLERTIDIG AVTALE for perioden,
//                     ikke en større fast stilling.
//
// Å blande de tre gir feil råd. Å øke en fast stilling fordi noen tok
// sommervakter er dyrt hele året; å la være å skrive midlertidig avtale
// er en risiko hver sommer.
// =====================================================================

/** 100 % = 37,5 t/uke ≈ 162,5 t/mnd. */
const TIMER_100 = 162.5

export type Maanedstimer = { maaned: string; timer: number } // 'YYYY-MM'

export type Vurdering =
  | 'ukjent'          // ingen bekreftet kontrakt å måle mot
  | 'ok'              // jobber omtrent det hun skal
  | 'mangler_ramme'   // tar ekstravakter uten rammeavtale
  | 'sesong'          // toppen ligger i en avgrenset periode
  | 'bor_okes'        // jevnt over kontrakten — § 14-4 a

export type Eksponering = {
  ansattNr: string
  navn: string
  kontraktProsent: number | null
  harRammeavtale: boolean
  /** Snitt over de månedene vi har, som stillingsprosent. */
  snittProsent: number
  medianProsent: number
  toppProsent: number
  maaneder: number
  /** Sammenhengende høysesong, når toppen er avgrenset. */
  sesong: { maaneder: number[]; snittProsent: number } | null
  vurdering: Vurdering
  melding: string
}

const median = (t: number[]) => {
  if (t.length === 0) return 0
  const s = [...t].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

// Hvor mye over medianen en måned må ligge for å regnes som høysesong.
// Under dette er det normal variasjon: en ekstravakt, en sykevikar.
const SESONG_FAKTOR = 1.6
// Og hvor mange prosentpoeng over kontrakten før noe i det hele tatt sies.
// En 20 %-stilling som snitter 23 % er ikke et problem.
const MONN = 8

/**
 * Utgjør månedene én sammenhengende periode?
 *
 * Året er en sirkel: desember og januar henger sammen. En sesong som
 * strekker seg over nyttår ville ellers sett ut som to spredte topper.
 *
 * Returnerer kjeden i rekkefølge, eller null hvis månedene er spredt —
 * spredte topper er ikke sesong, det er en stilling som er for liten.
 * Krever minst to måneder: én enkelt måned er en ekstravakt, og da er
 * rammeavtale riktig svar, ikke en midlertidig ansettelse for én måned.
 *
 * Delt med plandekningen, som stiller samme spørsmål forlengs: skal
 * sommertoppen i planen løses med midlertidige avtaler eller større
 * faste stillinger?
 */
export function sammenhengendeKjede(maaneder: Iterable<number>): number[] | null {
  const hoy = new Set(maaneder)
  if (hoy.size < 2 || hoy.size > 5) return null

  // Start der forrige måned ikke er med.
  const start = [...hoy].find((m) => !hoy.has(m === 1 ? 12 : m - 1))
  if (start === undefined) return null
  const kjede: number[] = []
  let m = start
  while (hoy.has(m) && kjede.length <= 12) {
    kjede.push(m)
    m = m === 12 ? 1 : m + 1
  }
  return kjede.length === hoy.size ? kjede : null
}

/** Månedene som ligger vesentlig over personens egen normal. */
function finnSesong(perMaaned: Map<number, number[]>, normal: number): number[] | null {
  const hoy = new Set<number>()
  for (const [m, verdier] of perMaaned) {
    if (median(verdier) > normal * SESONG_FAKTOR) hoy.add(m)
  }
  return sammenhengendeKjede(hoy)
}

export function vurderEksponering(
  ansatt: { ansattNr: string; navn: string; kontraktProsent: number | null; harRammeavtale: boolean },
  timer: Maanedstimer[],
): Eksponering {
  const verdier = timer.map((t) => (t.timer / TIMER_100) * 100)
  const snitt = verdier.length ? verdier.reduce((a, b) => a + b, 0) / verdier.length : 0
  const med = median(verdier)
  const topp = verdier.length ? Math.max(...verdier) : 0

  const perMaaned = new Map<number, number[]>()
  for (const t of timer) {
    const m = Number(t.maaned.slice(5, 7))
    const liste = perMaaned.get(m) ?? []
    liste.push((t.timer / TIMER_100) * 100)
    perMaaned.set(m, liste)
  }
  const kjede = med > 0 ? finnSesong(perMaaned, med) : null
  const sesong = kjede
    ? {
      maaneder: kjede,
      snittProsent: median(kjede.flatMap((m) => perMaaned.get(m) ?? [])),
    }
    : null

  const felles = {
    ...ansatt,
    snittProsent: Math.round(snitt),
    medianProsent: Math.round(med),
    toppProsent: Math.round(topp),
    maaneder: timer.length,
    sesong,
  }

  if (ansatt.kontraktProsent == null) {
    return {
      ...felles,
      vurdering: 'ukjent',
      melding: `Ingen bekreftet stillingsprosent. Jobber i snitt ${Math.round(snitt)} %.`,
    }
  }
  const k = ansatt.kontraktProsent

  // Sesong først: den forklarer toppen, og krever et annet papir.
  if (sesong && sesong.snittProsent > k + MONN) {
    const navn = sesong.maaneder.map((m) => MND[m - 1])
    return {
      ...felles,
      vurdering: 'sesong',
      melding: `Går ${k} % det meste av året, men ${Math.round(sesong.snittProsent)} % i `
        + `${navn.join(', ')}. Det er sesong, ikke en for liten stilling — skriv en `
        + 'midlertidig avtale for perioden i stedet for å øke den faste.',
    }
  }

  if (snitt > k + MONN) {
    return {
      ...felles,
      vurdering: 'bor_okes',
      melding: `Har jobbet ${Math.round(snitt)} % i snitt over ${timer.length} måneder på `
        + `en ${k} %-kontrakt. Etter aml. § 14-4 a kan hun kreve stilling tilsvarende `
        + 'faktisk arbeidstid. En rammeavtale hjelper ikke mot det.',
    }
  }

  if (!ansatt.harRammeavtale && topp > k + MONN) {
    return {
      ...felles,
      vurdering: 'mangler_ramme',
      melding: `Snittet er greit (${Math.round(snitt)} % mot ${k} %), men enkeltmåneder `
        + `går opp i ${Math.round(topp)} %. Uten rammeavtale om tilkalling kan de `
        + 'ekstravaktene senere kreves som overtid.',
    }
  }

  return {
    ...felles,
    vurdering: 'ok',
    melding: `Jobber ${Math.round(snitt)} % mot ${k} % i kontrakt.`,
  }
}

/** Rekkefølge: det som haster mest først. */
export const ALVOR: Record<Vurdering, number> = {
  bor_okes: 0,
  mangler_ramme: 1,
  sesong: 2,
  ukjent: 3,
  ok: 4,
}
