// Lønnsrommet: hvor mye lønn stasjonen faktisk har råd til.
//
// =====================================================================
// BUDSJETTET ER IKKE EN FAST SUM
//
// BP-en sier «383 285 i lønn for august». Men den sier det under en
// forutsetning: at måneden også leverer 1 201 000 i bruttofortjeneste.
// Kommer det mindre inn, er det mindre å bruke — og et budsjett som
// står stille mens inntekten faller, sier «god margin» akkurat når det
// ikke er det.
//
// Derfor er rommet en ANDEL, ikke et beløp:
//
//     lønnsandel = BP-lønn / BP-brutto
//     lønnsrom   = lønnsandel x faktisk brutto
//
// Svinn trekkes fra brutto, ikke fra rommet: kastet vare er brutto som
// aldri ble til noe. Bruker de mer svinn, krymper rommet av seg selv.
//
// ---------------------------------------------------------------------
// DEN INNEVÆRENDE MÅNEDEN ER HELE POENGET
//
// For en avlagt måned står brutto i regnskapet. Men da er måneden over
// og beslutningen tatt for seks uker siden. Verdien ligger i måneden
// som fortsatt kan påvirkes — og der må brutto ANSLÅS:
//
//     omsetning (daglig)  x  margin (lært av regnskapet)  -  svinn (daglig)
//
// Marginen er det eneste som ikke finnes ferdig, og den er nettopp det
// som blir bedre for hver regnskapsrapport som lastes opp.
// =====================================================================

/**
 * Hvor mange avlagte måneder marginen læres av.
 *
 * Seks er et valg, ikke en sannhet. Færre følger sesongen tettere —
 * julimarginen ligner mer på junis enn på januars. Flere er mer stabilt
 * mot en enkelt skjev måned. Seks er nok til at én rar måned ikke
 * dominerer, og kort nok til at et varig skifte slår gjennom på et
 * halvår.
 */
export const MAANEDER_FOR_MARGIN = 6

/**
 * Er dette drivstoff?
 *
 * DEN FARLIGSTE LINJA I HELE MODULEN. Regnskapets `bruttofortjeneste`
 * per stasjon har én rad per avdelingsrollup, og drivstoff er en av dem.
 * Omsetningen på den andre siden av brøken kommer fra `v_butikksalg`,
 * som holder drivstoff utenfor. Blandes de, deles brutto MED drivstoff
 * på omsetning UTEN — en margin som ikke beskriver noe som finnes.
 *
 * Drivstoff er ~68 % av omsetningen, så feilen ville ikke vært subtil:
 * marginen hadde blitt nesten tre ganger for høy, og lønnsrommet like
 * mye for stort.
 *
 * `AGENTS.md`: det er avdelingsNAVNET som identifiserer drivstoff, ikke
 * koden. Kodeverdien varierer mellom kjeder og er ikke mappet.
 */
export const erDrivstoff = (post: string): boolean => /energi/i.test(post)

export type Maanedsgrunnlag = {
  maaned: string // yyyy-mm
  omsetningKr: number
  svinnKr: number
}

/** Det regnskapet har lukket for en måned. */
export type Regnskapsmaaned = {
  maaned: string
  omsetningKr: number | null
  bruttoKr: number | null
}

/** Hva BP-en lovet for måneden. */
export type Bpmaaned = {
  maaned: string
  bruttoKr: number | null
  lonnKr: number | null
}

export type Marginkilde = 'regnskap' | 'bp' | null

export type Lonnsrom = {
  maaned: string
  /** Faktisk brutto fra regnskapet, eller anslått. Null når ingen av delene. */
  bruttoKr: number | null
  /** Sant når `bruttoKr` er anslått og ikke lest av regnskapet. */
  anslaatt: boolean
  /** BP-lønn delt på BP-brutto. Null når BP mangler. */
  lonnsandel: number | null
  /** Lønnsandelen ganget med faktisk brutto. Null når noe mangler. */
  romKr: number | null
  /** BP-ens eget lønnstall, uendret. Det rommet måles MOT. */
  bpLonnKr: number | null
  /** Marginen som ble brukt til anslaget, og hvor den kom fra. */
  margin: number | null
  marginkilde: Marginkilde
  /**
   * Inngangsverdiene, saa de kan vises ved siden av svaret.
   *
   * Svinnet hoerer med paa loennssida nettopp fordi det krymper rommet.
   * Staar de to tallene paa hver sin flate, ser man aldri koblingen.
   */
  omsetningKr: number
  svinnKr: number
}

const tall = (v: number | null | undefined): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? v : null

/**
 * Bruttomarginen lært av de avlagte månedene.
 *
 * SUM OVER SUM, IKKE SNITT AV BRØKER. En måned med lav omsetning skal
 * ikke telle like mye som en med høy — snittet av tolv prosenttall gir
 * en januar samme vekt som en juli, og det er ikke slik marginen
 * oppfører seg. Summen av brutto delt på summen av omsetning er den
 * marginen kjeden faktisk hadde i perioden.
 *
 * Null når ingen avlagt måned har begge tallene. Å gjette en margin
 * ville gjort et hull til et tall.
 */
export function laertMargin(
  regnskap: Regnskapsmaaned[],
  antall = MAANEDER_FOR_MARGIN,
): number | null {
  const brukbare = regnskap
    .filter((m) => tall(m.omsetningKr) !== null && tall(m.bruttoKr) !== null)
    .filter((m) => m.omsetningKr! > 0)
    .sort((a, b) => b.maaned.localeCompare(a.maaned))
    .slice(0, antall)

  if (brukbare.length === 0) return null
  const brutto = brukbare.reduce((a, m) => a + m.bruttoKr!, 0)
  const omsetning = brukbare.reduce((a, m) => a + m.omsetningKr!, 0)
  return omsetning > 0 ? brutto / omsetning : null
}

/**
 * BP-ens egen margin, som reserve for en kjede uten avlagt regnskap.
 *
 * EN NY RETAILER SKAL IKKE STÅ UTEN SVAR. Uten denne ville lønnsrommet
 * krevd et halvår med regnskap før det virket i det hele tatt, og det
 * ville vært et nytt onboardingkrav i praksis om ikke i ord. BP-ens
 * margin er kjedens egen forventning — dårligere enn målt historikk,
 * men langt bedre enn ingenting, og den byttes ut av seg selv så snart
 * den første rapporten er inne.
 */
export function bpMargin(bp: Bpmaaned[], grunnlag: Maanedsgrunnlag[]): number | null {
  const perMaaned = new Map(grunnlag.map((g) => [g.maaned, g]))
  let brutto = 0
  let omsetning = 0
  for (const b of bp) {
    const g = perMaaned.get(b.maaned)
    if (tall(b.bruttoKr) === null || !g || g.omsetningKr <= 0) continue
    brutto += b.bruttoKr!
    omsetning += g.omsetningKr
  }
  return omsetning > 0 ? brutto / omsetning : null
}

/**
 * Bygger lønnsrommet per måned.
 *
 * `regnskap` er de avlagte månedene, `grunnlag` de daglige tallene
 * (omsetning og svinn), `bp` det kjeden lovet. Rekkefølgen ut følger
 * `bp` og `grunnlag` samlet — nyeste først.
 */
export function byggLonnsrom(
  regnskap: Regnskapsmaaned[],
  grunnlag: Maanedsgrunnlag[],
  bp: Bpmaaned[],
): Lonnsrom[] {
  const margin = laertMargin(regnskap) ?? bpMargin(bp, grunnlag)
  const marginkilde: Marginkilde = laertMargin(regnskap) !== null
    ? 'regnskap'
    : margin !== null ? 'bp' : null

  const regnPer = new Map(regnskap.map((m) => [m.maaned, m]))
  const grunnPer = new Map(grunnlag.map((m) => [m.maaned, m]))
  const bpPer = new Map(bp.map((m) => [m.maaned, m]))

  const maaneder = [...new Set([
    ...regnskap.map((m) => m.maaned),
    ...grunnlag.map((m) => m.maaned),
    ...bp.map((m) => m.maaned),
  ])].sort((a, b) => b.localeCompare(a))

  return maaneder.map((maaned) => {
    const b = bpPer.get(maaned)
    const bpBrutto = tall(b?.bruttoKr)
    const bpLonn = tall(b?.lonnKr)

    // REGNSKAPET VINNER OVER ANSLAGET. Er måneden avlagt, finnes brutto,
    // og et anslag ved siden av fasiten ville bare vært støy.
    const faktisk = tall(regnPer.get(maaned)?.bruttoKr)
    const g = grunnPer.get(maaned)
    const anslag = faktisk === null && margin !== null && g && g.omsetningKr > 0
      // SVINNET TREKKES FRA BRUTTO, ikke fra rommet. Kastet vare er
      // brutto som aldri ble til noe.
      ? g.omsetningKr * margin - g.svinnKr
      : null

    const bruttoKr = faktisk ?? anslag
    const lonnsandel = bpBrutto !== null && bpBrutto > 0 && bpLonn !== null
      ? bpLonn / bpBrutto
      : null

    return {
      maaned,
      bruttoKr,
      anslaatt: faktisk === null && anslag !== null,
      lonnsandel,
      romKr: lonnsandel !== null && bruttoKr !== null ? lonnsandel * bruttoKr : null,
      bpLonnKr: bpLonn,
      margin,
      marginkilde,
      omsetningKr: g?.omsetningKr ?? 0,
      svinnKr: g?.svinnKr ?? 0,
    }
  })
}
