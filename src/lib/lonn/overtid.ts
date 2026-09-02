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
// Å FINNE FOR MYE ER TRYGT HER, Å FINNE FOR LITE ER DET IKKE. Denne
// modulen utløser ingen utbetaling; den gjør et tall synlig. Derfor
// velges den laveste forsvarlige grensen når skiftordningen er ukjent,
// og derfor er det verdt å si fra om en uke som såvidt bikker.
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
    const t = timer(minutter)
    if (t <= TIMER_PER_DAG) continue
    const [ansattNr, dato] = noekkel.split('|')
    funn.push({
      ansattNr, slag: 'dag', noekkel: dato,
      timer: t, grense: TIMER_PER_DAG, over: timer(minutter - TIMER_PER_DAG * 60),
    })
  }

  for (const [noekkel, minutter] of perUke) {
    const [ansattNr, mandag] = noekkel.split('|')
    const ordning = skiftordning(ansattNr)
    const grense = TIMER_PER_UKE[ordning ?? 'ordinaer']
    const t = timer(minutter)
    if (t <= grense) continue
    funn.push({
      ansattNr, slag: 'uke', noekkel: mandag,
      timer: t, grense, over: timer(minutter - grense * 60),
      ...(ordning === null ? { antattOrdinaer: true as const } : {}),
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
