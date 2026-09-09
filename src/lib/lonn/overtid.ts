import { TIMER_PER_UKE, type Skiftordning } from './tariff'

// =====================================================================
// FINNER OVERTID. BEREGNER DEN IKKE.
//
// Lønnsfila eksporterer hver time som ordinær: lønnsart `2` pluss
// tidsbånd for kveld, lørdag og søndag. Det finnes ingen overtidsart,
// ingen terskel og intet skille mot merarbeid. Målt gjennom
// produksjonsfunksjonene 2026-08-27 ga fire dager 59,50 ordinære timer
// uten at noe reagerte.
//
// HVORFOR DENNE MODULEN IKKE REGNER UT ET KRONEBELØP
//
// Satsen står i Energiavtalen, ikke i koden, og `ai/verktoy.ts` sier det
// allerede rett ut: «Gjett aldri på satser». Et påslag valgt av meg ville
// vært et tall noen fikk utbetalt.
//
// Så denne svarer på det som ER avgjort, og bare det: hvor mange timer
// ligger over alminnelig arbeidstid. Hva de timene koster, og hvilken
// lønnsart de skal på, er en beslutning som hører hjemme hos den som
// kjenner overenskomsten.
//
// GRENSENE ER IKKE GJETTET
//
//   uke   `TIMER_PER_UKE` — Energiavtalen: 37,5 t ordinær, 35,5 t to
//         skift. Står allerede i `tariff.ts`, lest ut av tariffoversikten.
//         Følger skiftordningen, ikke stillingen.
//   dag   9 timer. Arbeidsmiljøloven § 10-4 første ledd, alminnelig
//         arbeidstid. Lov, ikke skjønn — og et gulv: en overenskomst kan
//         være strengere, aldri romsligere.
//
// ---------------------------------------------------------------------
// UKJENT SKIFTORDNING: VI ANTAR ORDINÆR (37,5), OG DET ER ET VALG
//
// Her sto det at «den laveste forsvarlige grensen» velges, og et annet
// sted i fila at vi antar «den strengeste». **Begge beskrev det motsatte
// av koden.** `TIMER_PER_UKE[ordning ?? 'ordinaer']` gir 37,5 — den
// HØYESTE av de fire — og en høyere grense finner FÆRRE timer.
//
// To kommentarer som lyver samme vei er ikke slurv. Det er den formen
// som gjør at en gjennomlesing bekrefter feilen i stedet for å finne
// den.
//
// HVA 37,5 FAKTISK BETYR: vi flagger bare timer som er overtid under
// ENHVER skiftordning. Ingen falske funn — men et to-skift-menneske
// (35,5) får to timer i uka som ikke telles. `antattOrdinaer` settes på
// funnet, og `/lonn` skriver «(skiftordning ikke satt)».
//
// DET ER ET ÅPENT VALG, IKKE EN AVGJORT SAK. Modulen utløser ingen
// utbetaling; den gjør et tall synlig for et menneske. For en DETEKTOR
// er det å finne for lite den dyre feilen — og målingen på Bønes peker
// den veien: Lars snitter 35,5 på krona, altså to-skift-normen.
//
// Å bytte til 35,5 som standard ville funnet mer, og noe av det ville
// vært feil for de som faktisk går ordinær. Valget hører hjemme hos den
// som kjenner overenskomsten, og `overtid-standard.test.ts` binder det
// som står her til det koden gjør.
//
// DEN EKTE FIKSEN ER DATA: `ansatt_avtale` har nesten ingen rader, så
// nesten alle havner i antakelsen. Er ordningen satt, er spørsmålet
// borte.
// =====================================================================

// -------------------------------------------------------------------
// FOER NOEN BYGGER BEREGNINGEN: EN TOLKNING MAA AVKLARES FOERST
//
// Energistasjonsoverenskomsten gir satsene - 50 % kl. 06-21 paa
// virkedager (§ 3.1), 100 % kl. 21-06 og paa soen- og helligdager etter
// ordinaer arbeidstids slutt (§ 3.3) - men to bestemmelser om KOMBINASJON
// peker mot hverandre:
//
//   § 2.6.2  ikke ubekvemstillegg for timer det betales overtid for
//   § 3.9    ikke overtidstillegg for timer som etter § 2.6.1 er
//            ubekvem arbeidstid
//
// En overtidstime kl. 22 paa en onsdag: § 3.3 sier 100 %, § 2.6.1 sier
// kr 22, § 2.6.2 sier at kronene faller bort, § 3.9 sier at prosentene
// gjoer det. Hver av dem peker paa den andre.
//
// Det avgjoer hva ENHVER kvelds- og natteovertidstime koster, og det kan
// ikke leses ut av teksten alene. Stilt som spoersmaal til loenn
// 2026-09-02. Ikke gjett - denne modulen finner timene, den priser dem
// ikke.
// -------------------------------------------------------------------

/** Alminnelig arbeidstid per dag, aml. § 10-4 (1). */
export const TIMER_PER_DAG = 9

// ---------------------------------------------------------------------
// LANGE UKER ETTER AVTALE (aml. § 10-5)
//
// Paa hver stasjon finnes ansatte med INDIVIDUELL skriftlig avtale om
// gjennomsnittsberegnet arbeidstid - typisk uke paa / uke av. En slik
// arbeidsuke er sju dager og rundt 53 timer HVER GANG.
//
// Uten dette fyrte varselet paa dem hver maaned. Boenes, august 2026:
// Lars Neteland hadde 39,7 / 40,1 / 15,9 / 53,6 / 8,2 - fire funn, tre
// av dem stoey. **En vakt som roper om det normale blir ikke lest**, og
// da drukner det ene funnet som betyr noe.
//
// HAKEN FJERNER IKKE GRENSEN, DEN BYTTER DEN. § 10-5 setter egne tak,
// og hvilket avhenger av hvem avtalen er inngaatt med:
//
//     individuell avtale        10 t/dag   48 t/uke
//     avtale med fagforening    12,5 t/dag 54 t/uke
//
// **Kelsars avtaler er individuelle** (Robert, 2026-09-06), saa det er
// 10 og 48 som gjelder. Skulle en kjede ha fagforeningsavtale, er det
// konfigurasjon - ikke et tall som skal endres her.
//
// Lars' 53,6 er fortsatt et funn, og et ekte et: mer enn en individuell
// avtale tillater. Fire funn blir til ett.
// ---------------------------------------------------------------------

/** Dagsgrense ved gjennomsnittsberegning, individuell avtale (§ 10-5). */
export const TIMER_PER_DAG_AVTALT = 10
/** Ukegrense ved gjennomsnittsberegning, individuell avtale (§ 10-5). */
/**
 * Ordningen vi antar naar den ikke er satt.
 *
 * Staar som en navngitt konstant og ikke som `?? 'ordinaer'` inne i et
 * uttrykk, av én grunn: da kan `overtid-standard.test.ts` lese den og
 * kreve at teksten oeverst i fila sier det samme. To kommentarer sa det
 * motsatte av koden foer den bindingen fantes.
 */
export const UKJENT_ORDNING: Skiftordning = 'ordinaer'

export const TIMER_PER_UKE_AVTALT = 48

export type Vaktlinje = {
  ansattNr: string
  /** ISO-dato, `YYYY-MM-DD`. */
  dato: string
  minutter: number
}

export type Overtidsfunn = {
  ansattNr: string
  slag: 'dag' | 'uke'
  /** Dagen for et dagsfunn, mandagen for et ukesfunn. Alltid ISO-dato. */
  noekkel: string
  timer: number
  grense: number
  /** Timene over grensen. Alltid > 0. */
  over: number
  /**
   * Skiftordningen var ikke satt, så ukegrensen er antatt ordinær.
   * To skift har 35,5 t og ville gitt et STØRRE avvik — så antakelsen
   * kan skjule timer, aldri finne opp noen.
   */
  antattOrdinaer?: true
  /**
   * Målt mot § 10-5-taket, ikke mot uketimetallet.
   *
   * Står den, har den ansatte individuell avtale om lange uker — og
   * funnet betyr da at uka er over det AVTALEN tillater, ikke at den er
   * over en vanlig uke. Det er to helt ulike beskjeder, og flaten må
   * kunne si hvilken.
   */
  langeUkerAvtalt?: true
}

const MANDAG_FRA_SONDAG = 6

/**
 * Mandagen i uka datoen ligger i.
 *
 * ISO-uke: mandag er første dag. `getUTCDay()` gir 0 for søndag, og en
 * søndag hører til uka som startet seks dager tidligere — ikke til den
 * som begynner i morgen.
 */
export function mandagen(dato: string): string {
  const d = new Date(`${dato}T00:00:00Z`)
  const dag = d.getUTCDay()
  d.setUTCDate(d.getUTCDate() - (dag === 0 ? MANDAG_FRA_SONDAG : dag - 1))
  return d.toISOString().slice(0, 10)
}

const timer = (minutter: number) => Math.round((minutter / 60) * 100) / 100

/**
 * Dagene og ukene som ligger over alminnelig arbeidstid.
 *
 * `skiftordning` slår opp den ansattes ordning. Returnerer den null, er
 * ordningen ikke satt, og ukegrensen antas ordinær — se `antattOrdinaer`.
 *
 * VIKTIG OM UKER SOM KRYSSER MÅNEDSSKIFTET: summen blir bare riktig hvis
 * KALLEREN sender hele uker. Får denne bare månedens dager, teller en uke
 * som starter i forrige måned for lite — og da UTEBLIR et funn som burde
 * vært der. Feilen går altså i den farlige retningen, og det er kallerens
 * ansvar å hente et vindu som dekker hele uker.
 */
export function finnOvertid(
  linjer: Vaktlinje[],
  skiftordning: (ansattNr: string) => Skiftordning | null,
  /**
   * Har den ansatte individuell avtale om lange uker (§ 10-5)?
   *
   * Utelates den, er svaret nei for alle — den strengeste grensen, og
   * det trygge svaret for en ansatt ingen har tatt stilling til.
   */
  langeUkerAvtalt: (ansattNr: string) => boolean = () => false,
): Overtidsfunn[] {
  const perDag = new Map<string, number>()
  const perUke = new Map<string, number>()

  for (const l of linjer) {
    if (!(l.minutter > 0)) continue
    const dag = `${l.ansattNr}|${l.dato}`
    perDag.set(dag, (perDag.get(dag) ?? 0) + l.minutter)
    const uke = `${l.ansattNr}|${mandagen(l.dato)}`
    perUke.set(uke, (perUke.get(uke) ?? 0) + l.minutter)
  }

  const funn: Overtidsfunn[] = []

  for (const [noekkel, minutter] of perDag) {
    const [ansattNr, dato] = noekkel.split('|')
    // § 10-5 hever dagsgrensen til 10 for den som har avtalen. Loven
    // gjelder fortsatt — det er bare et annet ledd av den.
    const grense = langeUkerAvtalt(ansattNr) ? TIMER_PER_DAG_AVTALT : TIMER_PER_DAG
    const t = timer(minutter)
    if (t <= grense) continue
    funn.push({
      ansattNr, slag: 'dag', noekkel: dato,
      timer: t, grense, over: timer(minutter - grense * 60),
    })
  }

  for (const [noekkel, minutter] of perUke) {
    const [ansattNr, mandag] = noekkel.split('|')
    const avtalt = langeUkerAvtalt(ansattNr)
    const ordning = skiftordning(ansattNr)
    // AVTALEN SLÅR SKIFTORDNINGEN. Uke på / uke av gir sju arbeidsdager,
    // og da er 35,5 eller 37,5 ikke grensen som gjelder — men 48 er.
    const grense = avtalt ? TIMER_PER_UKE_AVTALT : TIMER_PER_UKE[ordning ?? UKJENT_ORDNING]
    const t = timer(minutter)
    if (t <= grense) continue
    funn.push({
      ansattNr, slag: 'uke', noekkel: mandag,
      timer: t, grense, over: timer(minutter - grense * 60),
      // `antattOrdinaer` betyr «skiftordningen er ukjent, vi antok
      // ORDINÆR (37,5)» — den grensen som gir færrest funn, ikke den
      // strengeste. Se toppen av fila: det er et valg, ikke en
      // selvfølge. Med avtalen brukes ikke skiftordningen i det hele
      // tatt, så forbeholdet ville vært misvisende.
      ...(ordning === null && !avtalt ? { antattOrdinaer: true as const } : {}),
      ...(avtalt ? { langeUkerAvtalt: true as const } : {}),
    })
  }

  // Verste først, så en liste som må kortes ned beholder det som betyr
  // mest. Deretter fast rekkefølge, ellers flakser den mellom kjøringer.
  return funn.sort((a, b) =>
    b.over - a.over
    || a.ansattNr.localeCompare(b.ansattNr)
    || a.noekkel.localeCompare(b.noekkel))
}

/** Vinduet som dekker hele ISO-uker rundt en måned. Se advarselen over. */
export function heleUkerRundt(ar: number, maned: number): { fra: string; til: string } {
  const mm = String(maned).padStart(2, '0')
  const sisteDag = new Date(Date.UTC(ar, maned, 0)).getUTCDate()
  const fra = mandagen(`${ar}-${mm}-01`)
  const sisteMandag = new Date(`${mandagen(`${ar}-${mm}-${sisteDag}`)}T00:00:00Z`)
  sisteMandag.setUTCDate(sisteMandag.getUTCDate() + 6)
  return { fra, til: sisteMandag.toISOString().slice(0, 10) }
}
