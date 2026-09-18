import { leggTilDager, ukedag, vaerfaktor, type Vaerdag, type VaerKoeff } from '@/lib/produksjonsplan'
import { erHelligdag, fjorHelligdag } from '@/lib/helligdager'

// =====================================================================
// FORVENTET SALG — SANNHETSEIEREN
// =====================================================================
//
// Dom C (2026-09-17): ingen motor eide forventet salg på varenivå.
// `lagProduksjonsplan` identifiserer produktet med `varenavn` og dekker
// bare åtte `PRODUKSJON_KODER`; `lagSalgsprognose` svarer i kroner per
// avdeling, for i morgen alene.
//
// Denne fila svarer på ÉTT spørsmål:
//
//   Hva forventet Sentiqa at denne salgsenheten skulle selge på denne
//   stasjonen denne dagen, basert utelukkende på informasjon som fantes
//   FØR dagen?
//
// ---------------------------------------------------------------------
// IDENTITETEN ER EAN, I DENNE DATAKONTRAKTEN
// ---------------------------------------------------------------------
//
// Målt 2026-09-17 over 223 708 rader: 1 680 av 1 721 varer (97,6 %) har
// ingen `varenr`, og 23 EAN har båret flere navn — «COCA-COLA UTEN
// SUKKE» og «0,5 L COCA-COLA ZERO» er samme EAN.
//
// `ean` er dessuten `not null` og del av primærnøkkelen
// `(retailer_id, stasjon_id, dato, ean)`.
//
// DET GJØR EAN TIL IDENTITETEN I DAGENS DOKUMENTERTE DATAKONTRAKT —
// ikke til en universell forretningssannhet. Én av navneendringene er
// verdt å merke seg: `4001` gikk fra «SORT KAFFE M_S» til «SORT KAFFE
// STOR». Om det er samme vare omdøpt eller to størrelser på gjenbrukt
// EAN, kan ikke avgjøres herfra.
//
// Motoren slår derfor ALDRI sammen to EAN, og splitter aldri én. Den
// regner på den enheten kilden ga den, og navnet følger med som et
// attributt uten å påvirke noe.
//
// ---------------------------------------------------------------------
// INGEN FREMTIDSLEKKASJE — OG DET ER MOTORENS ANSVAR
// ---------------------------------------------------------------------
//
// Kallstedet kan ikke betros å filtrere. `forventetSalg` kaster bort
// hver rad med `dato >= maalDato` selv, før noe regnes. En backtest som
// får med måldagen ville sett strålende ut og vært verdiløs.
//
// ---------------------------------------------------------------------
// «INGEN RAD» ER IKKE «NULL SOLGT»
// ---------------------------------------------------------------------
//
// Målt: 206 av 223 708 rader har `antall = 0`. En vare føres bare når
// den ble solgt. En motor som leser fravær som null etterspørsel, ville
// forutsagt null for alt som ikke gikk i går.
//
// Derfor returnerer motoren `ikke_dekning` — ikke 0 — når grunnlaget
// mangler. `0` er et svar; `ikke_dekning` er ærlighet.
//
// ---------------------------------------------------------------------
// KJENT MANGEL: UTSOLGT-KOMPENSASJON
// ---------------------------------------------------------------------
//
// `ai/vareprognose.ts` (pensjonert 2026-09-17) luket ut dager varen kan
// ha vaert TOM, med begrunnelsen: ellers ser tomme hyller ut som lav
// ettersporsel, og motoren laerer aa foreslaa for lite av det som
// faktisk gaar unna.
//
// Den egenskapen finnes ikke her. Den er IKKE kopiert inn - en formel
// flyttet uten backtest er en tredje sannhet. Skal den bygges, skal den
// bygges her, maales med `backtest.test.ts` og forsvares paa tall.
//
// `finnUtsolgt` i `lib/utsolgt.ts` eier hendelsene og lever videre.
//
// ---------------------------------------------------------------------
// MODELLEN ER IKKE AVGJORT
// ---------------------------------------------------------------------
//
// `basis × værfaktor × trendfaktor` er mønsteret begge dagens motorer
// deler. Det er en KANDIDAT på varenivå, ikke et aksiom. Derfor er
// leddene skrudd av og på med `Modell`, så backtesten kan måle hvilken
// kombinasjon som faktisk holder — i stedet for at vi antar det.
//
// Komponentene er GJENBRUKT, ikke kopiert: `vaerfaktor`, `ukedag` og
// `leggTilDager` importeres fra `produksjonsplan.ts`. To utgaver av
// samme formel ville skilt lag i stillhet.
// =====================================================================

/** Salgsenheten. `ean` er nøkkelen; alt annet er attributter. */
export type Salgsenhet = {
  stasjonId: string
  ean: string
}

export type Salgsrad = {
  stasjonId: string
  ean: string
  dato: string
  antall: number
  varegruppeKode: string | null
  varegruppeNavn: string | null
}

/**
 * Hvilke ledd som er med.
 *
 * SOM DATA, IKKE SOM ET VALG. Backtesten kjører alle fire og
 * rapporterer; ingen av dem er utpekt her.
 */
export type Modell = {
  navn: 'basis' | 'basis+trend' | 'basis+vaer' | 'basis+vaer+trend'
  trend: boolean
  vaer: boolean
}

export const MODELLER: readonly Modell[] = [
  { navn: 'basis', trend: false, vaer: false },
  { navn: 'basis+trend', trend: true, vaer: false },
  { navn: 'basis+vaer', trend: false, vaer: true },
  { navn: 'basis+vaer+trend', trend: true, vaer: true },
]

export type Manglergrunn =
  | 'ingen_historikk'
  | 'for_fa_dager'
  | 'ingen_basis'
  | 'ukjent_enhet'
  | 'ugyldig_antall'

export type Forventning =
  | {
    slag: 'beregnet'
    antall: number
    modell: Modell['navn']
    /** Leddene, hver for seg, så et tall kan etterprøves. */
    grunnlag: {
      fjorMedian: number | null
      nyligSnitt: number | null
      basis: number
      trendfaktor: number
      vaerfaktor: number
      /** Dager med salg i vinduet motoren faktisk så. */
      dagerMedSalg: number
    }
  }
  | { slag: 'ikke_dekning'; grunn: Manglergrunn; dagerMedSalg: number }

const median = (xs: number[]): number => {
  if (xs.length === 0) return 0
  const s = [...xs].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}
const snitt = (xs: number[]): number =>
  (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0)

/** Samme grenser som `lagProduksjonsplan`. Flyttet, ikke funnet på. */
const KAMPANJE_HOY = 1.7
const KAMPANJE_LAV = 0.5

export type Forventetinput = {
  enhet: Salgsenhet
  maalDato: string
  /**
   * Alt salg motoren får se. Rader på eller etter `maalDato` KASTES her
   * inne — kallstedet kan ikke betros med den grensen.
   */
  salg: readonly Salgsrad[]
  vaerMaal?: Vaerdag | null
  vaerFjor?: Vaerdag | null
  vaerfolsomhet?: number
  vaerKoeff?: VaerKoeff | null
  modell: Modell
  /**
   * Minste antall dager med salg i vinduet før motoren svarer.
   *
   * INGEN STANDARDVERDI ER «RIKTIG». Tallet settes av kallstedet og
   * skal avgjøres av backtest — dekningsmålingen ga 401 varer med 120+
   * salgsdager (83,6 % av omsetningen) og 1 199 med 10+ (99,4 %), men
   * hvilket nivå som kan FORSVARES er et måleresultat, ikke et valg.
   */
  minstDagerMedSalg: number
}

export function forventetSalg(inn: Forventetinput): Forventning {
  const { enhet, maalDato, modell } = inn

  // ── INGEN FREMTIDSLEKKASJE ──────────────────────────────────────────
  // Strengt mindre enn måldagen. Måldagens egne rader er fasiten, ikke
  // grunnlaget.
  const egne = inn.salg.filter(
    (r) => r.stasjonId === enhet.stasjonId && r.ean === enhet.ean && r.dato < maalDato,
  )
  const dagerMedSalg = new Set(egne.filter((r) => r.antall > 0).map((r) => r.dato)).size

  if (egne.length === 0) return { slag: 'ikke_dekning', grunn: 'ingen_historikk', dagerMedSalg }
  // Uten enhetskolonne kan et desimaltall ikke rundes til «stykker».
  // Null/NaN er heller ikke en observert null. Ingen gjetting i motoren.
  if (egne.some((r) => !Number.isFinite(r.antall))) return { slag: 'ikke_dekning', grunn: 'ugyldig_antall', dagerMedSalg }
  if (egne.some((r) => !Number.isInteger(r.antall))) return { slag: 'ikke_dekning', grunn: 'ukjent_enhet', dagerMedSalg }
  if (dagerMedSalg < inn.minstDagerMedSalg) {
    return { slag: 'ikke_dekning', grunn: 'for_fa_dager', dagerMedSalg }
  }

  // ── FJORÅRSMEDIAN: samme ukedag, fem uker rundt −364 ────────────────
  // Bevegelige helligdager sammenlignes med samme helligdagsrolle, ikke
  // kalenderdatoen året før. Vanlige dager beholder ±2-ukersvinduet.
  const helligdag = erHelligdag(maalDato)
  const fjorBase = fjorHelligdag(maalDato) ?? leggTilDager(maalDato, -364)
  const fjorSett = new Set(helligdag ? [fjorBase] : [-14, -7, 0, 7, 14].map((d) => leggTilDager(fjorBase, d)))
  const fjorPerDag = new Map<string, number>()
  for (const r of egne) {
    if (fjorSett.has(r.dato)) fjorPerDag.set(r.dato, (fjorPerDag.get(r.dato) ?? 0) + r.antall)
  }
  const fjorVerdier = [...fjorPerDag.values()].filter((v) => v > 0)
  let fjorMedian: number | null = fjorVerdier.length ? median(fjorVerdier) : null

  // Kampanje i fjor: matchdagen unormalt høy mot naboukene.
  if (fjorMedian != null) {
    const matchDag = fjorPerDag.get(fjorBase) ?? 0
    const naboer = [-14, -7, 7, 14]
      .map((d) => fjorPerDag.get(leggTilDager(fjorBase, d)) ?? 0).filter((v) => v > 0)
    const naboMed = naboer.length ? median(naboer) : matchDag
    if (matchDag > 0 && naboMed > 0 && matchDag > KAMPANJE_HOY * naboMed) fjorMedian = naboMed
  }

  // ── NYLIG: 28 dager fram til dagen FØR måldagen ─────────────────────
  //
  // `lagProduksjonsplan` regner fra `sisteSalgsdato`, som er et argument
  // kallstedet gir. Her utledes vinduet av måldagen selv — ellers ville
  // en backtest kunne flytte vinduet forbi D og lekke.
  const nyligSlutt = leggTilDager(maalDato, -1)
  const nyligStart = leggTilDager(nyligSlutt, -27)
  const nylig = egne.filter((r) => r.dato >= nyligStart && r.dato <= nyligSlutt)
  const malUkedag = ukedag(maalDato)
  const sammeUkedag = nylig.filter((r) => ukedag(r.dato) === malUkedag).map((r) => r.antall)
  const alleNylig = nylig.map((r) => r.antall)
  const nyligSnitt = sammeUkedag.length >= 2
    ? snitt(sammeUkedag)
    : (alleNylig.length ? snitt(alleNylig) : null)

  // ── BASIS ───────────────────────────────────────────────────────────
  let basis: number
  if (fjorMedian != null && nyligSnitt != null) {
    basis = fjorMedian
    if (nyligSnitt > KAMPANJE_HOY * fjorMedian || nyligSnitt < KAMPANJE_LAV * fjorMedian) {
      basis = 0.5 * fjorMedian + 0.5 * nyligSnitt
    }
  } else if (nyligSnitt != null) {
    basis = nyligSnitt
  } else if (fjorMedian != null) {
    basis = fjorMedian
  } else {
    // Rader finnes, men ingen i noen av vinduene. Ikke null — ukjent.
    return { slag: 'ikke_dekning', grunn: 'ingen_basis', dagerMedSalg }
  }

  // ── TRENDFAKTOR: 28 dager nå mot samme 28 i fjor, for DENNE enheten ──
  //
  // `lagProduksjonsplan` regner trenden over HELE salgsutvalget den får
  // (alle produkter i planen). Her er den per enhet, fordi motoren
  // svarer per enhet — en felles kjedetrend ville vært et annet tall som
  // lignet.
  let trendfaktor = 1
  if (modell.trend) {
    const naa = nylig.reduce((a, r) => a + r.antall, 0)
    const fS = leggTilDager(nyligStart, -364)
    const fE = leggTilDager(nyligSlutt, -364)
    const fjor = egne.filter((r) => r.dato >= fS && r.dato <= fE).reduce((a, r) => a + r.antall, 0)
    if (fjor > 0) trendfaktor = Math.max(0.6, Math.min(1.6, naa / fjor))
  }

  // ── VÆRFAKTOR: gjenbrukt fra produksjonsplanen ──────────────────────
  let vf = 1
  if (modell.vaer) {
    vf = vaerfaktor(
      inn.vaerMaal ?? null, inn.vaerFjor ?? null, inn.vaerfolsomhet ?? 0.5,
      egne.find((r) => r.varegruppeNavn)?.varegruppeNavn ?? '',
      inn.vaerKoeff ?? null,
    )
  }

  return {
    slag: 'beregnet',
    // AVRUNDET, MEN ALDRI UNDER NULL. Et negativt forventet salg finnes
    // ikke, og en faktor kan i prinsippet bli veldig liten.
    antall: Math.max(0, Math.round(basis * trendfaktor * vf)),
    modell: modell.navn,
    grunnlag: {
      fjorMedian: fjorMedian != null ? Math.round(fjorMedian * 10) / 10 : null,
      nyligSnitt: nyligSnitt != null ? Math.round(nyligSnitt * 10) / 10 : null,
      basis: Math.round(basis * 10) / 10,
      trendfaktor: Math.round(trendfaktor * 100) / 100,
      vaerfaktor: Math.round(vf * 100) / 100,
      dagerMedSalg,
    },
  }
}

// ---------------------------------------------------------------------
// AGGREGERING ER IKKE AVGJORT — OG FELLA ER SKREVET NED
// ---------------------------------------------------------------------
//
// «Vare → varegruppe → avdeling → stasjon» er målet, men det er IKKE
// bevist at høyere nivå trygt kan summeres fra varenivå.
//
// Målt: varer med 120+ salgsdager dekker 83,6 % av omsetningen. De
// øvrige 16 % ligger i en lang hale motoren sannsynligvis må svare
// `ikke_dekning` på. Summerer man da bare de prognostiserbare, får
// varegruppen SYSTEMATISK for lavt tall — og det ser ut som en prognose.
//
// `aggreger` gjør derfor to ting den ikke trenger å gjøre for å regne:
// den teller hvor mange enheter som falt ut, og hvor stor andel av
// historisk volum de utgjorde. Uten de to tallene kan ingen avgjøre om
// summen er brukbar.
//
// DEN SKJULER ALDRI EN MANGEL SOM NULL.

export type Aggregat = {
  antall: number
  /** Enheter motoren kunne forsvare. */
  medDekning: number
  /** Enheter den ikke kunne. Aldri talt som null. */
  utenDekning: number
  /**
   * Hvor stor andel av historisk volum de manglende utgjorde, 0–1.
   *
   * ER DETTE HØYT, ER SUMMEN IKKE EN PROGNOSE for nivået over. Den er
   * en delsum av det motoren tilfeldigvis mestrer.
   */
  manglendeVolumandel: number
}

export function aggreger(
  deler: readonly { forventning: Forventning; historiskVolum: number }[],
): Aggregat {
  let antall = 0
  let medDekning = 0
  let utenDekning = 0
  let volumMed = 0
  let volumUten = 0
  for (const d of deler) {
    if (d.forventning.slag === 'beregnet') {
      antall += d.forventning.antall
      medDekning++
      volumMed += d.historiskVolum
    } else {
      utenDekning++
      volumUten += d.historiskVolum
    }
  }
  const tot = volumMed + volumUten
  return {
    antall,
    medDekning,
    utenDekning,
    manglendeVolumandel: tot > 0 ? volumUten / tot : 0,
  }
}
