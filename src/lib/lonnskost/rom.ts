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
export const erDrivstoff = (post: string): boolean => /energi|drivstoff/i.test(post)

/**
 * Er dette en AVDELING, eller en varegruppe under den?
 *
 * ===================================================================
 * ROLLUPEN OG DELENE ER SAMME KRONER.
 *
 * Regnskapet gir begge nivåene som egne rader:
 *
 *     40 CR              10 444 947    <- avdeling
 *     120 Mat             4 926 038    <- varegruppe under CR
 *     140 Kald drikke     1 641 156
 *     ...                 ----------
 *     sum av delene      10 444 946    <- samme krone, en gang til
 *
 * Summeres begge, telles hver krone to ganger. Bruttoen for Dale juli
 * sto med 1 886 352 der den virkelige er 943 176, og lønnsprosenten ble
 * halvparten av den reelle — 23,4 % i stedet for 46,8 %.
 *
 * Verre: feilen traff BARE de avlagte månedene. Den inneværende regnes
 * av de daglige salgstallene, som ikke har rollups. Siden så derfor
 * riktig ut for august og gal for alt før — og det er den vanskeligste
 * formen å oppdage, fordi den ferske måneden bekrefter at alt virker.
 *
 * Tosifret ledetall er avdeling, tresifret er varegruppe under den.
 * ===================================================================
 */
export function erAvdelingsniva(post: string): boolean {
  const m = /^(\d+)\s/.exec(post.trim())
  return m !== null && m[1].length <= 2
}

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
  /**
   * Omsetning. BP-en har den for HELE året, per måned — så formen på
   * marginen trenger ikke læres, den står der. Det som må læres er
   * NIVÅET: treffer stasjonen den marginen BP-en la opp til?
   */
  omsetningKr: number | null
  bruttoKr: number | null
  lonnKr: number | null
}

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
  /**
   * Hvor mye av BP-ens planlagte margin stasjonen treffer. 1,0 = planen.
   * Null naar ingen maaned kan maales - da staar anslaget paa BP-en alene.
   */
  kalibrering: number | null
  /** Svinn utover det normale, som faktisk bet paa rommet. */
  ekstraSvinnKr: number
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
 * Hvor mye av BP-ens planlagte margin stasjonen faktisk treffer.
 *
 * ===================================================================
 * BP-EN ER FORMEN, REGNSKAPET ER NIVÅET.
 *
 * Første utgave lærte hele marginen av regnskapet: sum brutto delt på
 * sum omsetning over seks måneder. Det er et FLATT tall, og det smører
 * juli og januar sammen — mens marginen varierer med varemiksen, og
 * varemiksen varierer med sesongen.
 *
 * BP-en har omsetning og brutto per måned for hele året. Sesongen står
 * altså allerede der, målt av dem som la planen. Det eneste vi ikke vet
 * er om stasjonen faktisk treffer den marginen — og DET er det ene
 * tallet som skal læres, og som blir bedre for hver rapport.
 *
 *     forventet brutto = BP-brutto x (faktisk omsetning / BP-omsetning)
 *     kalibrering      = sum(faktisk brutto) / sum(forventet brutto)
 *
 * 1,0 betyr «treffer planen». Under 1 betyr at marginen er svakere enn
 * BP-en la opp til, og da skal lønnsrommet krympe tilsvarende.
 *
 * `null` når ingen måned kan måles. Å anta 1,0 der ville vært å påstå
 * at planen treffer, uten et eneste tall bak.
 * ===================================================================
 */
export function kalibrering(
  regnskap: Regnskapsmaaned[],
  bp: Bpmaaned[],
  antall = MAANEDER_FOR_MARGIN,
): number | null {
  const bpPer = new Map(bp.map((b) => [b.maaned, b]))
  const brukbare = regnskap
    .filter((m) => tall(m.bruttoKr) !== null && tall(m.omsetningKr) !== null)
    .sort((a, b) => b.maaned.localeCompare(a.maaned))
    .slice(0, antall)

  let faktisk = 0
  let forventet = 0
  for (const m of brukbare) {
    const b = bpPer.get(m.maaned)
    const bpOms = tall(b?.omsetningKr)
    const bpBrutto = tall(b?.bruttoKr)
    if (bpOms === null || bpBrutto === null || bpOms <= 0) continue
    faktisk += m.bruttoKr!
    forventet += bpBrutto * (m.omsetningKr! / bpOms)
  }
  return forventet > 0 ? faktisk / forventet : null
}

/**
 * Hvor stor andel av omsetningen som normalt går i svinn.
 *
 * ===================================================================
 * SVINNET KAN IKKE TREKKES FRA TO GANGER.
 *
 * Regnskapets bruttofortjeneste er ALLEREDE fratrukket svinn — kastet
 * vare er varekost uten et salg bak seg. Målt på Lone: teoretisk minus
 * faktisk brutto var 157 842, og kast pluss usynlig svinn 156 493.
 *
 * Første utgave regnet `omsetning x margin - svinn`, der marginen var
 * lært av regnskapet. Den hadde altså normalt svinn bakt inn, og så ble
 * svinnet trukket fra en gang til. På Dale august ga det et lønnsrom
 * ~7 700 kroner for lite.
 *
 * Kalibreringen bærer det normale svinnet. Det som skal bite er
 * AVVIKET: kaster de som vanlig, er alt med fra før; kaster de mer enn
 * vanlig, er brutto dårligere enn planen tilsier, og rommet krymper.
 * ===================================================================
 */
export function normalSvinnandel(
  grunnlag: Maanedsgrunnlag[],
  lukkede: Set<string>,
  antall = MAANEDER_FOR_MARGIN,
): number | null {
  const brukbare = grunnlag
    .filter((g) => lukkede.has(g.maaned) && g.omsetningKr > 0)
    .sort((a, b) => b.maaned.localeCompare(a.maaned))
    .slice(0, antall)

  if (brukbare.length === 0) return null
  const svinn = brukbare.reduce((a, g) => a + g.svinnKr, 0)
  const omsetning = brukbare.reduce((a, g) => a + g.omsetningKr, 0)
  return omsetning > 0 ? svinn / omsetning : null
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
  const lukkede = new Set(
    regnskap.filter((m) => tall(m.bruttoKr) !== null).map((m) => m.maaned),
  )
  const kal = kalibrering(regnskap, bp)
  const svinnandel = normalSvinnandel(grunnlag, lukkede)

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
    const bpOms = tall(b?.omsetningKr)
    const bpLonn = tall(b?.lonnKr)
    const g = grunnPer.get(maaned)

    // REGNSKAPET VINNER OVER ANSLAGET. Er måneden avlagt, finnes brutto,
    // og et anslag ved siden av fasiten ville bare vært støy.
    const faktisk = tall(regnPer.get(maaned)?.bruttoKr)

    // SVINN UTOVER DET NORMALE. Det normale ligger allerede i
    // kalibreringen, fordi regnskapets brutto er fratrukket svinn.
    // Uten `max(0, …)` ville en uvanlig ren måned GITT ekstra rom, og
    // det er ikke det samme: et lavt svinn er allerede fanget når
    // måneden lukkes, og å forskuttere det ville vært å låne av seg selv.
    const ekstraSvinnKr = g && svinnandel !== null
      ? Math.max(0, g.svinnKr - svinnandel * g.omsetningKr)
      : 0

    const anslag = faktisk === null && g && bpBrutto !== null && bpOms !== null && bpOms > 0
      ? bpBrutto * (g.omsetningKr / bpOms) * (kal ?? 1) - ekstraSvinnKr
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
      kalibrering: kal,
      ekstraSvinnKr: faktisk === null ? ekstraSvinnKr : 0,
      omsetningKr: g?.omsetningKr ?? 0,
      svinnKr: g?.svinnKr ?? 0,
    }
  })
}

/**
 * Hvilke måneder tabellen skal ha rader for.
 *
 * ===================================================================
 * UNIONEN, IKKE BARE REGNSKAPETS MÅNEDER.
 *
 * `byggLonnskost` hopper over en måned som verken er avlagt eller har
 * BP-linjer, og flaten itererte den lista. En måned med BARE
 * easy@work-data ble dermed usynlig: fila var lastet opp, raden fantes
 * ikke, og skjermen så ut som om ingenting var kommet inn.
 *
 * Det er den farligste formen for feil her — et fravær som ser ut som
 * en tom måned. Bønes august traff den: eksporten var inne, men
 * stasjonen manglet BP-rader for måneden.
 *
 * Nyeste først, som ellers på flaten.
 * ===================================================================
 */
export function maanedsrader(
  fraRegnskap: readonly { maaned: string }[],
  fraEasyatwork: readonly { maaned: string }[],
  fraRom: readonly { maaned: string; romKr: number | null }[],
): string[] {
  return [...new Set([
    ...fraRegnskap.map((m) => m.maaned),
    ...fraEasyatwork.map((m) => m.maaned),
    ...fraRom.filter((r) => r.romKr !== null).map((r) => r.maaned),
  ])].sort((a, b) => b.localeCompare(a))
}
