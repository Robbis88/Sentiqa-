// =====================================================================
// «HVA BØR JEG VITE NÅ?»
// =====================================================================
//
// Økonomibildet svarer på hva tallene ER. Denne fila svarer på hva du
// bør gjøre noe med — og den DØMMER IKKE PÅ NYTT.
//
// `styringsavvik()` har allerede satt `alvor`, og `byggOkonomibilde`
// har allerede satt `kilde` på hvert felt. Å vurdere de samme tallene
// en gang til her ville gitt to svar på «er dette alvorlig», og det
// ville vært den andre sannheten hele E3 ble bygget for å unngå.
//
// Denne fila OVERSETTER: fra felt og kilder til setninger noen kan
// handle på.
//
// ---------------------------------------------------------------------
// ROLIG SOM STANDARD
// ---------------------------------------------------------------------
//
// En måned der alt er i orden skal gi en TOM liste — ikke «ingen funn»,
// ikke et grønt kort. `Signal` i status.tsx sier det samme: finnes det
// ingenting å si, skal det ikke rendres.
//
// Et varselfelt som alltid står der lærer folk å se forbi det, og da er
// det borte den dagen det betyr noe.
//
// ---------------------------------------------------------------------
// HVER KJENSGJERNING SIES ÉN GANG
// ---------------------------------------------------------------------
//
// Mangler lønnsfila, sier `dekning.lonnsfil` det, og `styringsavvik`
// svarer «Lønnstallet er ikke kommet ennå.» på sitt vis. Det er ÉN
// kjensgjerning med to stemmer.
//
// Regelen: en mangel som dekningen alt forklarer, gjentas ikke av
// avviket. Men et avvik som mangler av en HELT ANNEN grunn — ingen BP,
// et rom på null — skal fortsatt si fra. `vite.test.ts` har begge, og
// den andre er kanarifuglen: uten den kunne denne fila tiet om alt.
// =====================================================================

import type { Okonomibilde, Dekning } from './bilde'

/**
 * Noe som er verdt å vite, med følgen for tallene.
 *
 * `nivaa` er `Signalnivaa` sine ord. Typen importeres ikke — et
 * domenebibliotek skal ikke peke på en UI-komponent. Samme valg som
 * `Alvor` i `lonnskost/rom.ts`.
 */
export type Beskjed = {
  /** Hva som er tilfellet. Én setning, ikke en rapport. */
  tittel: string
  /**
   * Hva det betyr for tallene på skjermen.
   *
   * UTELATES NÅR DET IKKE BETYR NOE. En følge som alltid står der er
   * like lite etterrettelig som en som mangler.
   */
  folge?: string
  nivaa: 'informasjon' | 'mulighet' | 'oppmerksomhet' | 'kritisk'
}

/**
 * Hva en manglende inngang gjør med anslaget.
 *
 * =====================================================================
 * RETNINGEN ER VIKTIGERE ENN MANGELEN
 * =====================================================================
 *
 * «Bilvask uke 39 mangler» er en opplysning om en fil. At anslaget
 * dermed er for LAVT, og lønnsrommet for stramt, er en opplysning om
 * hva du ser på — og det er den som avgjør om du skal handle.
 *
 * De to retningene er ikke like farlige:
 *
 *   for_lavt   varselet er STRENGERE enn virkeligheten. Ubehagelig,
 *              men trygt: handler du på det, handler du for tidlig.
 *
 *   for_hoyt   bildet ser BEDRE ut enn det er. Det er den farlige, for
 *              da ser en måned som skulle vært varslet rolig ut — samme
 *              form som en jobb som returnerer vellykket uten å ha
 *              gjort jobben.
 */
function retningsfolge(retning: Dekning['retningPaaFeil']): string | undefined {
  if (retning === 'for_lavt') {
    return 'Anslaget blir for lavt, så lønnsrommet er strammere enn det egentlig er.'
  }
  if (retning === 'for_hoyt') {
    return 'Anslaget blir for høyt, så bildet ser bedre ut enn det er.'
  }
  return undefined
}

/**
 * Hvilket ledd i avviket som er anslått.
 *
 * SAMME REGEL SOM `bruttogrunn` I bilde.ts: nevner leddene som faktisk
 * er anslag, og bare dem. En setning som alltid sier «noe her er
 * usikkert» forteller ikke hvor man skal se — og da leses den ikke.
 *
 * REGNER INGENTING, LESER BARE KILDENE. De er allerede satt av
 * `byggOkonomibilde`; her oversettes de til norsk.
 */
function anslagsgrunn(bilde: Okonomibilde): string | undefined {
  const ledd: string[] = []
  if (bilde.lonnsrom.kilde !== 'fasit') ledd.push('bruttoen bak rommet er anslått')
  if (bilde.lonn.kilde !== 'fasit') ledd.push('lønnstallet er ikke avstemt ennå')
  if (ledd.length === 0) return undefined
  const stor = `${ledd[0][0].toUpperCase()}${ledd[0].slice(1)}`
  return `${[stor, ...ledd.slice(1)].join(', og ')}. Tallet kan flytte seg når regnskapet kommer.`
}

/**
 * Er denne mangelen allerede forklart av dekningen?
 *
 * Brukes til å la være å si det samme to ganger. Se toppkommentaren.
 */
function forklartAvDekningen(mangler: string, dekning: Dekning): boolean {
  if (!dekning.lonnsfil && /lønnstallet|lønnsfila/i.test(mangler)) return true
  return false
}

/**
 * Hva som er verdt å vite om denne stasjonen, denne måneden.
 *
 * REKKEFØLGEN ER PRIORITET. Det som krever handling står først, det som
 * bare forklarer står sist. Flaten skal kunne rendre lista rett ned
 * uten å sortere — utleder den sin egen rekkefølge, har vi to meninger
 * om hva som haster.
 *
 * TAR ET FERDIG BILDE. Ingen IO, ingen henting: da kan hver regel prøves
 * med en fikstur. Samme form som `byggOkonomibilde` og `byggLonnsrom`.
 */
export function hvaBoerJegViteNaa(bilde: Okonomibilde): Beskjed[] {
  const ut: Beskjed[] = []
  const { dekning } = bilde
  // AVVIKET LIGGER NESTET. `bilde.styringsavvik` er et `Avviksfelt` —
  // dommen under `.avvik`, kilden ved siden av. Her sto en
  // destrukturering som leste FELTET som om det var dommen: `mangler`
  // ble `undefined`, `!== null` ble sant bestandig, og fila svarte
  // «kan ikke regnes» på hver eneste måned — også de helt avstemte.
  const avvik = bilde.styringsavvik.avvik

  // --- 1. AVVIKET, når det lot seg regne og betyr noe. ---------------
  //
  // `alvor` er E2 sin dom. Den gjentas ikke — den oversettes.
  //
  // ET ANSLÅTT AVVIK ER IKKE ET MÅLT AVVIK. Står lønna over rommet på et
  // anslag, er det fortsatt verdt å vite, men det er ikke det samme som
  // at det har skjedd. Ordet «ligger an til» bærer den forskjellen, og
  // uten det ville en prognose blitt lest som en fasit.
  //
  // KILDEN AVGJØR, IKKE `rom.anslaatt`. Avviksfeltets `kilde` ER lov 2:
  // den svakeste av rommets og lønnas. `rom.anslaatt` kjenner bare
  // bruttoen, så en avlagt brutto målt mot et easy@work-anslag ville
  // stått som «gikk over rommet» — en fasitsetning om et anslag.
  if (avvik.mangler === null && avvik.alvor !== 'normal') {
    const anslag = bilde.styringsavvik.kilde !== 'fasit'
    ut.push({
      tittel: anslag
        ? 'Lønna ligger an til å gå over rommet denne måneden.'
        : 'Lønna gikk over rommet denne måneden.',
      folge: anslag ? anslagsgrunn(bilde) : undefined,
      nivaa: avvik.alvor === 'handling' ? 'kritisk' : 'oppmerksomhet',
    })
  }

  // --- 2. DET SOM IKKE ER KOMMET INN, og hva det gjør. ---------------
  //
  // MANGLENE FØRST, RETNINGEN ETTERPÅ. Lista er klartekst fra
  // dekningen; retningen er den ene setningen som sier hva de gjør med
  // tallet. Å gjenta retningen per mangel ville vært fire like linjer.
  if (dekning.mangler.length > 0) {
    ut.push({
      tittel: dekning.mangler.length === 1
        ? `${dekning.mangler[0]} mangler.`
        : `Det mangler data: ${dekning.mangler.join(', ')}.`,
      folge: retningsfolge(dekning.retningPaaFeil),
      // `for_hoyt` er den farlige retningen, og den skal se annerledes
      // ut enn en mangel som bare gjør oss for forsiktige.
      nivaa: dekning.retningPaaFeil === 'for_hoyt' ? 'oppmerksomhet' : 'informasjon',
    })
  }

  // --- 3. AVVIKET LOT SEG IKKE REGNE, av en grunn dekningen ikke sa. -
  //
  // KANARIFUGLEN FOR HELE FILA. Uten dette leddet kunne `vite.ts` tiet
  // om et bilde uten BP — der det verken finnes rom eller avvik — og en
  // tom liste ville betydd «alt i orden».
  if (avvik.mangler !== null && !forklartAvDekningen(avvik.mangler, dekning)) {
    ut.push({
      tittel: 'Styringsavviket kan ikke regnes.',
      folge: avvik.mangler,
      nivaa: 'informasjon',
    })
  }

  // --- 4. LØNNSFILA, når den er hele grunnen. ------------------------
  //
  // Står her og ikke i 3, fordi den har en VEI VIDERE: fila kommer
  // dagen etter måneden. Det er en annen beskjed enn «BP mangler», som
  // krever at noen gjør noe.
  if (!dekning.lonnsfil) {
    ut.push({
      tittel: 'Lønnsfila er ikke kommet for denne måneden.',
      folge: 'Uten den finnes det ingen lønn å måle mot rommet.',
      nivaa: 'informasjon',
    })
  }

  return ut
}
