// =====================================================================
// Tariffsatser — Energiavtalen, gjeldende fra 01.07.2025.
//
// Satsene ligger i tabell med gyldig_fra fordi de endres: overenskomsten
// forhandles, og et oppgjør i august kan gjelde fra 1. april. Da må en
// avsluttet periode kunne regnes om med nye satser, og differansen
// etterbetales. Historiske perioder skal ALLTID beregnes med satsene som
// gjaldt da, aldri med dagens.
//
// Ukentlig arbeidstid følger skiftordningen, ikke stillingen:
//   ordinær   37,5 t/uke
//   to skift  35,5 t/uke
//
// Den som går fast kveld og helg er på to skift og skal ha den høyere
// satsen. Det er ikke et valg per kontrakt — det følger av hvordan
// vaktene faktisk ligger.
//
// KILDE: tariffoversikt datert 01.07.25. Gruppe I (ledende personell) er
// ufullstendig her — bare ansiennitet 0 og 1 var lesbare. Trinn over det
// gir «ukjent», ikke feil svar.
// =====================================================================

// FIRE UKETIMETALL, IKKE TO (§ 2.7.1.1).
//
//   37,5   ordinaer
//   36,5   2-dagskift som verken gaar loerdag aften eller i helligdagsdoegnet
//   35,5   der loven har 38 t/uke
//   33,5   der loven har 36 t/uke
//
// `to_skift` er det gamle navnet paa 35,5-ordningen. Det beholdes fordi det
// staar i basen fra `0096`; aa doepe det om ville betydd aa skrive om rader
// for aa vinne et penere navn.
export type Skiftordning = 'ordinaer' | 'skift_36_5' | 'to_skift' | 'skift_33_5'

export const TIMER_PER_UKE: Record<Skiftordning, number> = {
  ordinaer: 37.5,
  skift_36_5: 36.5,
  to_skift: 35.5,
  skift_33_5: 33.5,
}

export const SKIFTNAVN: Record<Skiftordning, string> = {
  ordinaer: 'ordinær',
  skift_36_5: '36,5 t/uke',
  to_skift: 'to skift',
  skift_33_5: '33,5 t/uke',
}

/**
 * Grunnlønn omregnet til en kortere uke — § 2.7.1.1:
 * `Grunnlønn § 19.2 × 37,5 / uketimetall`.
 *
 * Den som går kortere uke skal ikke tjene mindre for det.
 */
export function omregnet(grunnlonn: number, ordning: Skiftordning): number {
  return Math.round((grunnlonn * 37.5 / TIMER_PER_UKE[ordning]) * 100) / 100
}

/**
 * Ledende personell «skal ligge minst kr 5,- over minstelønnssatsene»
 * (§ 19.2).
 *
 * Den gamle avskriften hadde bare to av sju trinn, og det ene, 190,52, laa
 * UNDER gulvet. En sats under minstelønn meldt som «paa tariff» er den
 * feilen ingen ser før den ansatte gjoer det selv.
 *
 * BRUKES SOM KONTROLL, IKKE SOM GENERATOR. Gruppe I skrives av fra arket
 * (se `LEST`), og testen kontrollerer at hver ordinaersats er
 * butikkpersonell + denne. Aa AVLEDE gruppen ga ett oere for mye paa tre
 * av sju trinn i skiftkolonnen - arkets egen avrunding lar seg ikke
 * gjenskape.
 */
export const LEDENDE_TILLEGG = 5

/**
 * Avtalen har ingen 1-årssats: opprykket går fra 0 år rett til 2 år
 * (§ 19.2). Tariffoversikten hadde likevel to satser der, ett øre fra
 * hverandre, og BEGGE finnes i lønn hos oss.
 *
 * Trinnene beholdes derfor — å fjerne det ene ville gjort to riktig
 * avlønnede ansatte til «mellom to tarifftrinn» — men de MELDES som samme
 * bånd, så systemet slutter å påstå en ansiennitet avtalen ikke kjenner.
 */
export const TRINN_BAND: Record<number, string> = {
  0: '0–1 år', 1: '0–1 år', 2: '2 år', 3: '3 år', 4: '4 år', 5: '5 år', 6: '6 år',
}

export type Tariffgruppe = 'I_ledende' | 'II_butikk' | 'IV_under18'

export const GRUPPENAVN: Record<Tariffgruppe, string> = {
  I_ledende: 'I – Ledende personell',
  II_butikk: 'II – Butikkpersonell',
  IV_under18: 'IV – Under 18 år',
}

type Trinn = Record<Skiftordning, number>

export type Tariffbok = {
  gyldigFra: string
  satser: Record<Tariffgruppe, Record<number, Trinn>>
}

// TO KOLONNER ER LEST, TO ER REGNET.
//
// `ordinaer` og `to_skift` staar slik de sto i tariffoversikten datert
// 01.07.25. De roeres ikke: hver eneste sats vi har sett i loenn treffer
// en av dem, og et oere justert her er et oere noen faar utbetalt.
//
// `skift_36_5` og `skift_33_5` sto ikke i oversikten i det hele tatt. De
// regnes etter § 2.7.1.1, som er avtalens egen omregning.
//
// MERK, OG DET ER STILT SOM SPOERSMAAL TIL LOENN: oversikten er ikke
// intern konsistent. § 19.2 pluss kr 7,00 (reguleringen for 2. avtaleaar)
// gir 185,57 · 188,57 · 191,57 · 194,57 · 200,57 · 241,57 - og
// `to_skift`-kolonnen er avledet av NOEYAKTIG de tallene, alle seks. Tre
// av `ordinaer`-verdiene staar likevel med ett oere mer. Vi lar dem staa
// til noen har bekreftet hvilken som gjelder; begge godtas i mellomtiden,
// og trinn 0 og 1 meldes som samme baand.
const LEST: Record<Tariffgruppe, Record<number, { ordinaer: number; to_skift: number }>> = {
  II_butikk: {
    0: { ordinaer: 185.58, to_skift: 196.02 },
    1: { ordinaer: 185.57, to_skift: 196.02 },
    2: { ordinaer: 188.57, to_skift: 199.19 },
    3: { ordinaer: 191.58, to_skift: 202.36 },
    4: { ordinaer: 194.57, to_skift: 205.53 },
    5: { ordinaer: 200.57, to_skift: 211.87 },
    6: { ordinaer: 241.58, to_skift: 255.18 },
  },
  // LEST, IKKE AVLEDET - OG DET ER EN RETTELSE.
  //
  // I foerste omgang ble gruppe I avledet: butikkpersonell + kr 5, og
  // skiftkolonnen regnet om med x 37,5/35,5. Ordinaerkolonnen ble riktig
  // paa alle sju trinn. SKIFTKOLONNEN BLE DET IKKE - trinn 0, 3 og 6 laa
  // ett oere for hoeyt.
  //
  // Grunnen staar i arket selv: det har BEGGE ordinaervariantene (185,58
  // paa trinn 0 og 185,57 paa trinn 1), og skiftkolonnen er regnet fra
  // `.57`-varianten - derfor er den lik for trinn 0 og 1. En formel som
  // starter fra `.58` gir ett oere mer, og arkets egen avrunding lar seg
  // ikke gjenskape.
  //
  // Laerdommen er den samme som `II_butikk` bar fra foer: TRANSKRIBER
  // KILDEN. En avledning som stemmer paa fire av sju trinn ser riktig ut.
  //
  // Kilde: «Tariffoppgjoer 2025», arket Robert sendte 2026-09-02.
  // Sammenhengen holder likevel som KONTROLL: hver ordinaersats er
  // butikkpersonell + kr 5, noeyaktig som § 19.2 sier.
  I_ledende: {
    0: { ordinaer: 190.58, to_skift: 201.31 },
    1: { ordinaer: 190.57, to_skift: 201.31 },
    2: { ordinaer: 193.57, to_skift: 204.48 },
    3: { ordinaer: 196.58, to_skift: 207.64 },
    4: { ordinaer: 199.57, to_skift: 210.81 },
    5: { ordinaer: 205.57, to_skift: 217.15 },
    6: { ordinaer: 246.58, to_skift: 260.46 },
  },
  IV_under18: {
    0: { ordinaer: 143.33, to_skift: 151.41 },
  },
}

function fyllUt(lest: { ordinaer: number; to_skift: number }): Trinn {
  return {
    ordinaer: lest.ordinaer,
    to_skift: lest.to_skift,
    skift_36_5: omregnet(lest.ordinaer, 'skift_36_5'),
    skift_33_5: omregnet(lest.ordinaer, 'skift_33_5'),
  }
}

function byggSatser(): Record<Tariffgruppe, Record<number, Trinn>> {
  const ut = {} as Record<Tariffgruppe, Record<number, Trinn>>
  for (const gruppe of Object.keys(LEST) as Tariffgruppe[]) {
    const trinn: Record<number, Trinn> = {}
    for (const [ans, lest] of Object.entries(LEST[gruppe])) trinn[Number(ans)] = fyllUt(lest)
    ut[gruppe] = trinn
  }
  return ut
}

export const TARIFF_2025_07: Tariffbok = {
  gyldigFra: '2025-07-01',
  satser: byggSatser(),
}

export type Treff = { gruppe: Tariffgruppe; ansiennitet: number; skift: Skiftordning }

/** Alle trinn som matcher satsen eksakt. Tom liste = satsen finnes ikke. */
export function plasserSats(sats: number, bok = TARIFF_2025_07): Treff[] {
  const ut: Treff[] = []
  for (const [gruppe, trinn] of Object.entries(bok.satser) as [Tariffgruppe, Record<number, Trinn>][]) {
    for (const [ans, t] of Object.entries(trinn)) {
      for (const ordning of Object.keys(TIMER_PER_UKE) as Skiftordning[]) {
        if (Math.abs(t[ordning] - sats) < 0.005) {
          ut.push({ gruppe, ansiennitet: Number(ans), skift: ordning })
        }
      }
    }
  }
  return ut
}

export type Satsvurdering =
  | { status: 'tariff'; treff: Treff[]; melding: string }
  | { status: 'under'; melding: string; minstelonn: number }
  | { status: 'over'; melding: string }
  | { status: 'mellom'; melding: string }

/** Laveste voksensats i boka — gulvet for alle over 18. */
function minstelonnVoksen(bok: Tariffbok): number {
  const alle: number[] = []
  for (const [gruppe, trinn] of Object.entries(bok.satser) as [Tariffgruppe, Record<number, Trinn>][]) {
    if (gruppe === 'IV_under18') continue
    for (const t of Object.values(trinn)) {
      for (const o of Object.keys(TIMER_PER_UKE) as Skiftordning[]) alle.push(t[o])
    }
  }
  return Math.min(...alle)
}

/**
 * Vurderer en utbetalt timesats mot tariffen.
 *
 * Ikke for å bestemme hva noen skal ha — ansiennitet og gruppe vet bare
 * butikksjefen. Men en sats som ikke finnes i tabellen er enten en lokal
 * avtale eller en sats som aldri ble justert etter forrige oppgjør, og
 * det siste er en feil ingen ser før den ansatte gjør det selv.
 */
export function vurderSats(sats: number, bok = TARIFF_2025_07): Satsvurdering {
  const treff = plasserSats(sats, bok)
  if (treff.length > 0) {
    const t = treff[0]
    return {
      status: 'tariff',
      treff,
      // BAANDET, IKKE TRINNET. Avtalen har ingen 1-aarssats, saa «ansiennitet
      // 1» var et tall systemet fant paa. Se TRINN_BAND.
      melding: `${GRUPPENAVN[t.gruppe]}, ${TRINN_BAND[t.ansiennitet] ?? `ansiennitet ${t.ansiennitet}`}`
        + `${t.skift === 'ordinaer' ? '' : `, ${SKIFTNAVN[t.skift]}`}`,
    }
  }

  const gulv = minstelonnVoksen(bok)
  const under18 = bok.satser.IV_under18[0]
  if (sats < gulv) {
    // Kan være en lovlig ungdomssats — men da skal den treffe den tabellen,
    // og det gjorde den ikke.
    return {
      status: 'under',
      minstelonn: gulv,
      melding: sats > under18.to_skift
        ? `Under minstelønn for voksne (${gulv.toFixed(2)}), og over ungdomssatsen `
          + `(${under18.to_skift.toFixed(2)}). Sjekk alder og at satsen er justert.`
        : `Under minstelønn (${gulv.toFixed(2)}).`,
    }
  }

  // Taket er hoeyeste sats i den korteste uka - der omregningen loefter mest.
  const tak = Math.max(...Object.values(bok.satser.II_butikk).map((t) => t.skift_33_5))
  if (sats > tak) return { status: 'over', melding: 'Over høyeste tariffsats — lokal avtale.' }
  return {
    status: 'mellom',
    melding: 'Mellom to tarifftrinn. Enten en lokal avtale, eller en sats som '
      + 'ikke ble justert ved forrige oppgjør.',
  }
}

// =====================================================================
// SATSEN RØPER ORDNINGEN
//
// Robert, 2026-09-02: «nesten alle jobber to skift utenom butikksjefer».
// Står `skiftordning` tomt på dem, gjør systemet to feil samtidig:
//
//   overtid       ukegrensen blir 37,5 i stedet for 35,5, og detektoren
//                 UNDER-rapporterer — den retningen antakelsen aldri
//                 skulle ta (se `overtid.ts`)
//   tariff        satsen sammenlignes mot ordinærkolonnen, så en riktig
//                 avlønnet 2-skift-ansatt ser ut som «over tariff»
//
// Men vi trenger ikke spørre: TIMESATSEN VET DET ALLEREDE. Ingen sats i
// arket finnes i begge kolonnene, og nærmeste avstand mellom en ordinær
// og en skiftsats er 4 øre. Treffer satsen bare i skiftkolonnen, går
// personen to skift — uansett hva feltet sier.
//
// DEN PÅSTÅR IKKE NOE NÅR DEN IKKE VET. Ingen tarifftreff (lokal avtale,
// sats som aldri ble justert) gir null. Treff i begge kolonnene ville
// også gitt null — det finnes bare ikke i denne boka, og testen holder
// den forutsetningen i live.
// =====================================================================

export type Skiftavvik = {
  /** `ikke_satt`: feltet er tomt. `motsier`: feltet sier noe annet enn satsen. */
  slag: 'ikke_satt' | 'motsier'
  /** Ordningen satsen peker på. */
  antydet: Skiftordning
  registrert: Skiftordning | null
  melding: string
}

/**
 * Sier fra når timesatsen og den registrerte skiftordningen ikke henger sammen.
 *
 * Null når det ikke er noe å si: satsen stemmer med feltet, satsen finnes
 * ikke i tariffen, eller den er tvetydig.
 */
export function vurderSkiftordning(
  sats: number,
  registrert: Skiftordning | null,
  bok = TARIFF_2025_07,
): Skiftavvik | null {
  const treff = plasserSats(sats, bok)
  if (treff.length === 0) return null

  const ordninger = [...new Set(treff.map((t) => t.skift))]
  // Tvetydig sats: da vet vi ikke, og da sier vi ingenting.
  if (ordninger.length !== 1) return null

  const antydet = ordninger[0]
  if (registrert === antydet) return null

  const navn = SKIFTNAVN[antydet]
  return registrert === null
    ? {
        slag: 'ikke_satt', antydet, registrert,
        // Norsk desimaltegn. `${TIMER_PER_UKE.ordinaer}` gir «37.5», og et
        // punktum i en loennstekst leser som en skrivefeil.
        melding: `Timesatsen er ${navn}-satsen, men arbeidstid er ikke satt. `
          + `Overtidsgrensen regnes som ${SKIFTNAVN.ordinaer} til den er det.`,
      }
    : {
        slag: 'motsier', antydet, registrert,
        melding: `Timesatsen er ${navn}-satsen, men arbeidstid står som `
          + `${SKIFTNAVN[registrert]}. Én av dem er feil.`,
      }
}
