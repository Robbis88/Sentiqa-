// Hva en kostnadskode BETYR i St1s regnskapsrapport.
//
// =====================================================================
// EN KODE ER EN ADRESSE, IKKE EN IDENTITET
// =====================================================================
//
// St1 renummererte rapportlinjene i februar 2026. De fleste 63x-kodene
// forskjøv seg med TO, og `627 Renhold-renovasj` ble splittet i to:
//
//   628  var «Leie driftsmidler»      →  betyr nå «Renovasjon»
//   630  var «Utstyr & verktøy»       →  betyr nå «Leie driftsmidler»
//   632  var «Rep & vedlikehold»      →  betyr nå «Utstyr & verktøy»
//   634  var «Pengehåndtering»        →  betyr nå «Rep & vedlikehold»
//   636  var «Kontorrekvisita»        →  betyr nå «Pengehåndtering»
//   637  var «Telefon»                →  betyr nå «Fremmedtj & vakthold»
//   744  var «Kassedifferanse»        →  betyr nå «Forsikringer»
//
// Parseren slo tidligere opp koden alene i en hardkodet tabell. På en fil
// fra før februar 2026 ville hver driftskostnad fått feil navn — i
// stillhet, og med tall som så helt rimelige ut.
//
// **Og det var ikke bare en etikett.** `BUTIKKSJEF_DRIFT_KODER` i
// `regnskap-tilgang.ts` inneholder `628`, og var en RLS-grense fra
// `0192`. På en eldre fil er 628 LEIE DRIFTSMIDLER — en kostnad
// tilgangsregelen holder utenfor. En historisk fil ville altså vist
// butikksjefene leasingkostnaden. Ingen har lastet opp en slik fil ennå.
// Det er flaks, ikke vern.
//
// **Fra `0203` er det vern.** `regnskapslinjer.begrep` bærer betydningen,
// og policyen hvitlister begreper i stedet for tall. Kodelistene lever
// videre for lønnskontiene 501–590, som står stille over skiftet — se
// `regnskap-tilgang.ts`.
//
// ---------------------------------------------------------------------
// LØSNINGEN ER IKKE EN STØRRE TABELL
// ---------------------------------------------------------------------
//
// En tabell med begge epokene ville bare utsatt problemet til neste
// omnummerering, og imens sett like riktig ut.
//
// Identiteten ligger i KONTONUMMERET (4-sifret, 5xxx/6xxx/7xxx). Det står
// stille: 75 av 80 konti peker på samme begrep før og etter februar 2026.
// Men stasjonsarket bærer ikke kontonummeret — bare rapportlinjekoden og
// navnet som står TRYKT ved siden av den, i kolonne 7.
//
// Derfor: **paret (kode, trykt navn) er nøkkelen.** Et ukjent par er ikke
// noe vi gjetter oss ut av — det er et menneske som må ta stilling, og det
// tar ett minutt. En stille feilmerking kan stå i månedsvis.
//
// `slaaOppKonto()` KASTER på ukjent par. Det betyr at en fil fra en epoke
// vi ikke har tatt stilling til blir AVVIST, ikke importert feil. Feiler
// lukket, ikke åpent.
//
// Neste gang St1 flytter linjene skal importen knekke høylytt. Vakten er
// mekanismen, ikke tabellen — se `kontoregister.test.ts`, som mater inn et
// par fra før februar 2026 og krever at det felles.

import { ParserFeil } from './felles'

/** Kanonisk begrep. Dette, ikke koden, er det systemet skal resonnere om. */
export type Kontobegrep =
  | 'faste_lonninger' | 'lonnstillegg' | 'timelonn' | 'sykelonn'
  | 'refundert_sykelonn' | 'palopte_feriepenger' | 'bonus'
  | 'arbeidsgiveravgift_lonn' | 'arbeidsgiveravgift_feriepenger'
  | 'andre_personalkostnader'
  | 'markedsbidrag' | 'royalty' | 'fsa' | 'franchiseavgift'
  | 'renhold' | 'renhold_og_renovasjon' | 'renovasjon' | 'broyting'
  | 'leie_driftsmidler' | 'leie_utstyr_utleie' | 'utstyr_verktoy'
  | 'forbruksmateriell' | 'rep_vedlikehold' | 'data_kortsystem'
  | 'pengehandtering' | 'fremmedtjenester_vakthold' | 'kontorrekvisita'
  | 'telefon'
  | 'bilutgifter' | 'reise_moter_kurs' | 'reklame' | 'diverse'
  | 'forsikringer' | 'erstatning_tyveri' | 'kassedifferanse'
  | 'bank_kortprovisjon' | 'ekstraordinaert' | 'avskrivninger'
  | 'finanskostnader' | 'ikke_driftsrelatert'

export type Kontooppslag = {
  begrep: Kontobegrep
  /** Navnet vi viser. Alltid det kanoniske, aldri det arket tilfeldigvis skrev. */
  navn: string
  /** Hvilken epoke paret hører hjemme i. `null` = uendret over skiftet. */
  epoke: 'for_feb_2026' | 'fra_feb_2026' | null
}

const N: Record<Kontobegrep, string> = {
  faste_lonninger: 'Faste lønninger', lonnstillegg: 'Lønnstillegg',
  timelonn: 'Timelønn', sykelonn: 'Sykelønn',
  refundert_sykelonn: 'Refundert sykelønn',
  palopte_feriepenger: 'Påløpte feriepenger', bonus: 'Bonus',
  arbeidsgiveravgift_lonn: 'Arb.avg av lønn',
  arbeidsgiveravgift_feriepenger: 'Arb.avg av feriepenger',
  andre_personalkostnader: 'Andre personalkostnader',
  markedsbidrag: 'Markedsbidrag', royalty: 'Royalty', fsa: 'FSA',
  franchiseavgift: 'Franchiseavgift',
  renhold: 'Renhold', renhold_og_renovasjon: 'Renhold og renovasjon',
  renovasjon: 'Renovasjon', broyting: 'Brøyting',
  leie_driftsmidler: 'Leie driftsmidler',
  leie_utstyr_utleie: 'Leie utstyr for utleie',
  utstyr_verktoy: 'Utstyr & verktøy', forbruksmateriell: 'Forbruksmateriell',
  rep_vedlikehold: 'Rep & vedlikehold', data_kortsystem: 'Data & kortsystem',
  pengehandtering: 'Pengehåndtering',
  fremmedtjenester_vakthold: 'Fremmedtjenester & vakthold',
  kontorrekvisita: 'Kontorrekvisita', telefon: 'Telefon',
  bilutgifter: 'Bilutgifter', reise_moter_kurs: 'Reise, møter, kurs',
  reklame: 'Reklame', diverse: 'Diverse', forsikringer: 'Forsikringer',
  erstatning_tyveri: 'Erstatning – tyveri', kassedifferanse: 'Kassedifferanse',
  bank_kortprovisjon: 'Bank & kortprovisjon',
  ekstraordinaert: 'Ekstraordinært tap/gevinst', avskrivninger: 'Avskrivninger',
  finanskostnader: 'Finanskostnader', ikke_driftsrelatert: 'Ikke driftsrelatert',
}

/**
 * Normaliserer et trykt linjenavn for oppslag: små bokstaver, norske
 * tegn beholdt, alt annet enn bokstav/tall til én mellomrom.
 *
 * Hvorfor ikke strengere? Fordi arket skriver «Arb.avg av feriep.» ett
 * sted og «Arb.avg av feriepenger» et annet, og «Fremmedtj & vakth» mot
 * «Fremmedtj og vakthold». Vi trenger å tåle skrivevarianter uten å tåle
 * BETYDNINGSFORSKJELLER — derfor er det fortsatt en eksplisitt liste
 * under, ikke fuzzy matching.
 */
export function normaliser(s: string): string {
  return s
    .toLowerCase()
    .replace(/^\s*\d+\s+/, '') // arket skriver «627 Renhold» i samme celle
    .replace(/[^\wæøå]+/gu, ' ')
    .trim()
}

type Post = { begrep: Kontobegrep; epoke: Kontooppslag['epoke'] }

/**
 * Registeret. Nøkkel er `kode|normalisert trykt navn`.
 *
 * Hvert par er noen som har TATT STILLING. En ny kombinasjon skal ikke
 * gjettes inn her av en parser — den skal felle, og et menneske skal
 * legge den til med et blikk på hva St1 faktisk mener.
 */
const REGISTER: Record<string, Post> = {}

function reg(kode: string, navn: string, begrep: Kontobegrep, epoke: Kontooppslag['epoke'] = null) {
  REGISTER[`${kode}|${normaliser(navn)}`] = { begrep, epoke }
}

// --- Personal. Uendret over skiftet. ---------------------------------
reg('501', 'Faste lønninger', 'faste_lonninger')
reg('502', 'Lønnstillegg', 'lonnstillegg')
reg('503', 'Timelønn', 'timelonn')
reg('505', 'Sykelønn', 'sykelonn')
reg('506', 'Refundert sykelønn', 'refundert_sykelonn')
reg('508', 'Påløpte feriepenger', 'palopte_feriepenger')
reg('509', 'Bonus', 'bonus')
reg('540', 'Arb.avg av lønn', 'arbeidsgiveravgift_lonn')
reg('541', 'Arb.avg av feriep.', 'arbeidsgiveravgift_feriepenger')
reg('541', 'Arb.avg av feriepenger', 'arbeidsgiveravgift_feriepenger')
reg('590', 'Andre personal', 'andre_personalkostnader')
reg('590', 'Andre personalkostnader', 'andre_personalkostnader')

// --- Kjedeavgifter. Uendret. -----------------------------------------
reg('621', 'Markedsbidrag', 'markedsbidrag')
reg('622', 'Royalty', 'royalty')
reg('623', 'FSA', 'fsa')
reg('624', 'Franchiseavgift', 'franchiseavgift')

// --- Drift, FRA februar 2026 -----------------------------------------
reg('627', 'Renhold', 'renhold', 'fra_feb_2026')
reg('628', 'Renovasjon', 'renovasjon', 'fra_feb_2026')
reg('629', 'Brøyting', 'broyting', 'fra_feb_2026')
reg('630', 'Leie driftsmidler', 'leie_driftsmidler', 'fra_feb_2026')
reg('631', 'Leie utstyr for utleie', 'leie_utstyr_utleie', 'fra_feb_2026')
reg('632', 'Utstyr & verktøy', 'utstyr_verktoy', 'fra_feb_2026')
reg('633', 'Forbruksmateriell', 'forbruksmateriell', 'fra_feb_2026')
reg('634', 'Rep & vedlikehold', 'rep_vedlikehold', 'fra_feb_2026')
reg('635', 'Data & kortsystem', 'data_kortsystem', 'fra_feb_2026')
reg('636', 'Pengehåndtering', 'pengehandtering', 'fra_feb_2026')
reg('637', 'Fremmedtj & vakth', 'fremmedtjenester_vakthold', 'fra_feb_2026')
reg('638', 'Kontorrekvisita', 'kontorrekvisita', 'fra_feb_2026')
reg('639', 'Telefon', 'telefon', 'fra_feb_2026')
reg('740', 'Bilutgifter', 'bilutgifter', 'fra_feb_2026')
reg('741', 'Reise-møter-kurs', 'reise_moter_kurs', 'fra_feb_2026')
reg('742', 'Reklame', 'reklame', 'fra_feb_2026')
reg('743', 'Diverse', 'diverse', 'fra_feb_2026')
reg('744', 'Forsikringer', 'forsikringer', 'fra_feb_2026')
reg('745', 'Erstatn - tyveri', 'erstatning_tyveri', 'fra_feb_2026')
reg('746', 'Kassedifferanse', 'kassedifferanse', 'fra_feb_2026')

// --- Drift, FØR februar 2026 -----------------------------------------
// Fram til `0203` var disse registrert bare for å kunne KJENNES IGJEN og
// avvises med en forståelig beskjed. Nå importeres de: raden bærer
// `begrep`, og tilgangsgrensen leser begrepet i stedet for tallet — så
// «628 Leie driftsmidler» fra 2025 blir leasing, ikke renovasjon.
reg('627', 'Renhold-renovasj', 'renhold_og_renovasjon', 'for_feb_2026')
reg('628', 'Leie driftsmidler', 'leie_driftsmidler', 'for_feb_2026')
reg('629', 'Leie utstyr for utleie', 'leie_utstyr_utleie', 'for_feb_2026')
reg('630', 'Utstyr & verktøy', 'utstyr_verktoy', 'for_feb_2026')
reg('631', 'Forbruksmateriell', 'forbruksmateriell', 'for_feb_2026')
reg('632', 'Rep & vedlikehold', 'rep_vedlikehold', 'for_feb_2026')
reg('633', 'Data & kortsystem', 'data_kortsystem', 'for_feb_2026')
reg('634', 'Pengehåndtering', 'pengehandtering', 'for_feb_2026')
reg('635', 'Fremmedtj & vakth', 'fremmedtjenester_vakthold', 'for_feb_2026')
reg('636', 'Kontorrekvisita', 'kontorrekvisita', 'for_feb_2026')
reg('637', 'Telefon', 'telefon', 'for_feb_2026')
// 738 og 743 kom fra januarfila 2026-09-12. De sto ikke her fordi
// registeret ble bygget av det jeg kunne SE i filene jeg hadde - og de
// var alle fra februar og senere. Navnet er identiteten i begge:
// «Bilutgifter» og «Erstatn - tyveri» staar ordrett slik ogsaa i dagens
// skjema, paa 740 og 745. Forskyvningen paa to stemmer.
reg('738', 'Bilutgifter', 'bilutgifter', 'for_feb_2026')
reg('739', 'Reise-møter-kurs', 'reise_moter_kurs', 'for_feb_2026')
reg('740', 'Reklame', 'reklame', 'for_feb_2026')
reg('741', 'Diverse', 'diverse', 'for_feb_2026')
reg('742', 'Forsikringer', 'forsikringer', 'for_feb_2026')
reg('743', 'Erstatn - tyveri', 'erstatning_tyveri', 'for_feb_2026')
reg('744', 'Kassedifferanse', 'kassedifferanse', 'for_feb_2026')

// --- Under driftsresultatet. Uendret. --------------------------------
reg('771', 'Bank & kortprov', 'bank_kortprovisjon')
reg('780', 'Ekstraord tap/gev.', 'ekstraordinaert')
reg('790', 'Avskrivninger', 'avskrivninger')
reg('810', 'Fin. utgifter', 'finanskostnader')
reg('840', 'Ikke driftsrelat. innt/kostn', 'ikke_driftsrelatert')

/**
 * Som `slaaOppKonto`, men svarer `null` i stedet for å kaste.
 *
 * ER BARE TRYGG DER BEGREPET IKKE ER EN GRENSE. Clusterarket bærer hele
 * kjeden, og de radene har `stasjon_id = null` — policyen slipper aldri
 * en butikksjef til dem uansett hva `begrep` sier. Der er «vi kjente
 * ikke igjen paret» et akseptabelt svar.
 *
 * På stasjonsarkene er det motsatt: der ER begrepet grensen, og et
 * ukjent par skal felle importen. Bruk `slaaOppKonto` der.
 */
export function slaaOppKontoOm(kode: string, trykt: string): Kontooppslag | null {
  const nkl = normaliser(trykt)
  const post = nkl ? REGISTER[`${kode}|${nkl}`] : undefined
  if (!post) return null
  return { begrep: post.begrep, navn: N[post.begrep], epoke: post.epoke }
}

/** Alle registrerte par. Kun for tester og verktøy. */
export function registrertePar(): Array<{ kode: string; navn: string } & Post> {
  return Object.entries(REGISTER).map(([n, p]) => {
    const i = n.indexOf('|')
    return { kode: n.slice(0, i), navn: n.slice(i + 1), ...p }
  })
}

/**
 * Slår opp hva koden betyr, gitt navnet som står trykt ved siden av den.
 *
 * KASTER på ukjent par — St1 har flyttet noe ingen har tatt stilling til.
 * Det er fortsatt hele poenget: en stille feilmerking kan stå i månedsvis.
 *
 * =====================================================================
 * DEN GAMLE EPOKEN AVVISES IKKE LENGER (0203)
 * =====================================================================
 *
 * Fram til `0203` kastet denne på et par fra før februar 2026, og
 * begrunnelsen sto her: resten av systemet — inkludert
 * `BUTIKKSJEF_DRIFT_KODER`, som er en RLS-grense siden `0192` —
 * resonnerte om RÅ KODER. En gammel fil ville lagt rader i basen der
 * `628` betyr leasing mens policyen tror den betyr renovasjon.
 *
 * Det stemte, og prisen var at januar 2026 og alt eldre ikke kunne
 * lastes opp i det hele tatt.
 *
 * `0203` flyttet grensen dit den hører hjemme: `regnskapslinjer` bærer
 * nå `begrep`, og policyen hvitlister begreper, ikke tall. Da er en
 * gammel fil ikke lenger farlig — den er bare gammel, og registeret vet
 * nøyaktig hva hver linje var.
 *
 * `epoke` følger med ut, så den som bryr seg kan spørre.
 */
export function slaaOppKonto(kode: string, trykt: string): Kontooppslag {
  const nkl = normaliser(trykt)
  if (!nkl) {
    throw new ParserFeil(
      `Regnskap: kostnadslinje ${kode} mangler navn i arket. Kan ikke avgjøre hva koden betyr.`,
    )
  }
  const post = REGISTER[`${kode}|${nkl}`]
  if (!post) {
    // NAVNET ER IDENTITETEN. Kjenner vi det samme navnet paa en ANNEN
    // kode, er dette nesten alltid den samme linja fra et annet skjema -
    // og da er beskjeden verdt mye mer enn «ukjent».
    //
    // Uten dette koster hver manglende linje en ny opplasting: januar
    // 2026 felte foerst paa `743 Erstatn - tyveri`, og `738 Bilutgifter`
    // laa rett bak den. To runder for noe som kunne vaert sagt i én.
    //
    // Det er fortsatt et menneske som tar stilling. Forskjellen er at
    // beskjeden peker paa hvor man skal se.
    const andre = Object.entries(REGISTER)
      .filter(([n]) => n.endsWith(`|${nkl}`) && !n.startsWith(`${kode}|`))
      .map(([n, p]) => `${n.slice(0, n.indexOf('|'))} (${p.begrep})`)
      // Sortert, ikke i innsettingsrekkefølge: beskjeden skal lese likt
      // hver gang, og lavest kode først er den eldste epoken — altså
      // som regel den man leter etter.
      .sort()
    const spor = andre.length > 0
      ? ` Samme navn staar paa ${andre.join(', ')} — se om det er den samme linja ` +
        `fra et annet skjema.`
      : ''
    throw new ParserFeil(
      `Regnskap: ukjent kostnadslinje «${kode} ${trykt.trim()}». ` +
        `St1 har trolig endret rapportlinjene igjen.${spor} ` +
        `Legg paret inn i src/lib/parsere/kontoregister.ts etter å ha sjekket hva det betyr — ` +
        `ikke gjett ut fra koden alene.`,
    )
  }
  return { begrep: post.begrep, navn: N[post.begrep], epoke: post.epoke }
}
