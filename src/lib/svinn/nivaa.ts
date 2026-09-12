// =====================================================================
// NIVÅ OG ANALYSEOMRÅDE — ÉN REGEL, ETT STED
// =====================================================================
//
// Regnskapsrapportens svinnark har tre nivåer og flere BLOKKER, og de to
// er ikke det samme. Målt på Kelsars sju månedsfiler, 42 ark — og tallene
// står i TO kolonner med vilje, for de svarer på to spørsmål:
//
//                                   i arket   lagres
//   ProdGr3  13 varegrupper per ark      546      546   ← SANNHETSRADENE
//   Prod     butikk (12010 …)          2 304    1 445
//   Prod     drivstoff/CR (1490 …)       462      141   (133 + 8 ukjent)
//   ProdGr1  blokkoverskrifter            84        0   (bare kontekst)
//
// Differansen er rader der ALT er null. 139 av grupperadene er slik, og
// de lagres likevel: «Dale har ingen bilvask» er et svar, og uten raden
// kan ingen skille det fra «ingen data om bilvask». 859 butikkprodukter
// er slik, og de hoppes over — grupperaden eier totalen, og en nullrad
// under den forklarer ingenting.
//
// Tidligere sto det 2 346 og 420 her. Det var samme ark, men talt UTEN
// nullfilteret og før drivstoffregelen ble rettet, og tallene kunne
// derfor ikke avstemmes mot noe som lå i basen. Kommentarblokken i
// migrasjon 0208 bærer de gamle tallene; den er kjørt og endres aldri.
//
// **Gruppen eier totalen. Produktradene forklarer den.** Produktradene
// summerer eksakt til gruppen for mat i alle 35 stasjonsmåneder — men
// ingen analyse får summere begge nivåer, for da dobles alt.
//
// ---------------------------------------------------------------------
// ANALYSEOMRÅDET UTLEDES AV ARKET SELV, IKKE AV ANTALL SIFFER
//
// Robert, 2026-09-12: «Firesifrede rader skal ikke fjernes bare fordi de
// har fire sifre. De skal fjernes fordi de tilhører drivstoff/CR.»
//
// Riktig. Kodelengden er et KONTROLLSIGNAL for dagens format, ikke en
// forretningsregel — St1 kan innføre en femsifret drivstoffkode i morgen.
//
// Den stabile regelen ligger i arkets egen struktur: **de 13 `ProdGr3`-
// kodene definerer butikkens univers.** En produktrad hører til butikken
// når de tre første sifrene i koden er en gruppe som finnes på SAMME ark
// i SAMME måned. `12010 → 120 Mat` ✓. `1490 → 149`, som ikke er noen
// gruppe ✗.
//
// Det utelukker drivstoff av seg selv, og det utelukker også en ny
// firesifret butikkode hvis St1 skulle innføre en — den ville da ikke
// matche en gruppe, og havne som `ukjent` i stedet for å bli regnet med
// i stillhet.
//
// ---------------------------------------------------------------------
// UKJENT ER EN EGEN TILSTAND, IKKE EN AVRUNDING TIL NULL
//
// En rad vi ikke kan plassere lagres som `ukjent` og BLOKKERES fra
// analysen. Den slettes ikke: en rad som forsvinner er en rad ingen kan
// etterprøve, og «vi vet ikke hva dette er» er et annet svar enn «dette
// finnes ikke».
// =====================================================================

/** Nivået raden ligger på i rapporten. Normalisert. */
export type Nivaa = 'gruppe' | 'produkt'

/** Hvilken del av driften raden hører til. */
export type Analyseomraade = 'butikk' | 'drivstoff' | 'ukjent'

/** Rapportens egne typebetegnelser, slik de står i kolonne 2. */
export const TYPE_GRUPPE = 'ProdGr3'
export const TYPE_PRODUKT = 'Prod'
export const TYPE_BLOKK = 'ProdGr1'

export function nivaaFraType(type: string): Nivaa | null {
  const t = type.trim()
  if (t === TYPE_GRUPPE) return 'gruppe'
  if (t === TYPE_PRODUKT) return 'produkt'
  return null
}

/**
 * Gruppekoden en produktkode hører til: de tre første sifrene.
 *
 * `null` når koden er kortere enn tre siffer eller ikke er tall.
 */
export function gruppekodeFor(kode: string): string | null {
  const k = kode.trim()
  if (!/^\d{3,}$/.test(k)) return null
  return k.slice(0, 3)
}

/**
 * Blokkoverskrifter som markerer drivstoff og CR-totalen.
 *
 * Målt i Kelsars ark: `10 Drivstoff`, `40 CR`, `10 Drivstoff volum
 * Totalt`. Brukes til å skille «vet at dette er drivstoff» fra «vet
 * ikke hva dette er» — begge blokkeres, men de er ikke samme funn.
 *
 * `\bcr\b` og ikke `^\s*40\s+cr`: blokknavnet bygges som «kode navn»,
 * altså `40 40 CR`, og den forankrede varianten traff derfor ingenting.
 * Den var grønn i enhetstesten og blind i arket — samme form som en
 * vakt som slutter å se.
 */
const DRIVSTOFFBLOKK = /drivstoff|\bcr\b/i

export function erDrivstoffblokk(blokknavn: string): boolean {
  return DRIVSTOFFBLOKK.test(blokknavn.trim())
}

export type Omraadeopts = {
  /** Kodene til `ProdGr3`-radene på SAMME ark. Butikkens univers. */
  gruppekoder: ReadonlySet<string>
  /** Navnet på siste `ProdGr1` over raden, om noen. */
  blokk: string
  /**
   * Inneholder denne `ProdGr1`-blokken noen `ProdGr3`-grupper?
   *
   * DETTE ER FORSKJELLEN PÅ «VET IKKE» OG «VET AT DET ER DRIVSTOFF».
   *
   * Blokknavnet alene kan ikke bære regelen: `10 Drivstoff` er
   * overskriften over ALLE de 13 butikkgruppene i arket. En ren
   * produktblokk UTEN grupper er derimot en drivstoff-/CR-oppstilling,
   * og det er en strukturell forskjell, ikke en formulering.
   *
   * Målt: `1490 Diesel` m.fl. ligger i en ren produktblokk → drivstoff.
   * `99910 UKJENT` (72 kr salg på 4177) ligger i en blokk MED grupper,
   * og er St1s egen uklassifiserte varegruppe — ikke drivstoff, men
   * ukjent. Begge blokkeres fra analysen; de er ikke samme funn.
   */
  blokkHarGrupper: boolean
}

/**
 * Hvor raden hører hjemme.
 *
 * Gruppene er butikk per definisjon — de ER universet. For produktrader
 * avgjør gruppekoden, og bare den; blokkoverskriften brukes til å skille
 * drivstoff fra ukjent, aldri til å slippe noe inn.
 */
export function analyseomraade(
  nivaa: Nivaa,
  kode: string,
  o: Omraadeopts,
): Analyseomraade {
  if (nivaa === 'gruppe') return 'butikk'
  const g = gruppekodeFor(kode)
  if (g && o.gruppekoder.has(g)) return 'butikk'
  // Drivstoff bare naar beviset er entydig: en REN produktblokk, uten
  // grupper, med drivstoff- eller CR-overskrift. Ellers vet vi ikke,
  // og da skal raden si «ukjent» og ikke laane en merkelapp.
  if (!o.blokkHarGrupper && erDrivstoffblokk(o.blokk)) return 'drivstoff'
  return 'ukjent'
}

/**
 * Bare `butikk` går inn i svinn- og bruttofortjenesteanalysen.
 *
 * Egen funksjon og ikke en `=== 'butikk'` spredt rundt: da finnes
 * regelen ett sted, og et nytt område kan ikke slippe inn ved at noen
 * glemmer å utvide et filter.
 */
export function iButikkanalysen(omraade: Analyseomraade): boolean {
  return omraade === 'butikk'
}

/**
 * Avrundingstoleransen for at importert og kontrollberegnet usynlig
 * svinn skal regnes som samme tall.
 *
 * Målt: identiteten `teoretisk − faktisk − kast = usynlig` holder med
 * `diff = 0` i alle 35 stasjonsmåneder, altså til øret i arkets egne
 * tall. 0,50 kr gir rom for flyttallsstøy uten å slippe gjennom en ekte
 * uoverensstemmelse.
 */
export const KONTROLL_TOLERANSE_KR = 0.5

export type Avviksstatus = 'ok' | 'avvik'

/**
 * Stemmer arkets usynlig-kolonne med identiteten?
 *
 * BEGGE TALL BEVARES. Importert verdi er St1s eget; kontrollberegningen
 * er vår. Erstatter vi den ene med den andre, mister vi sporet tilbake
 * til rapporten — og da kan vi ikke svare på hvem som regnet feil.
 */
export function kontrollerUsynlig(
  teoretiskKr: number,
  faktiskBfKr: number,
  synligKastKr: number,
  importertUsynligKr: number,
): { kontrollKr: number; status: Avviksstatus } {
  const kontrollKr = Math.round((teoretiskKr - faktiskBfKr - synligKastKr) * 100) / 100
  const status: Avviksstatus =
    Math.abs(kontrollKr - importertUsynligKr) <= KONTROLL_TOLERANSE_KR ? 'ok' : 'avvik'
  return { kontrollKr, status }
}
