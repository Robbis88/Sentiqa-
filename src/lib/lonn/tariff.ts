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

export type Skiftordning = 'ordinaer' | 'to_skift'

export const TIMER_PER_UKE: Record<Skiftordning, number> = {
  ordinaer: 37.5,
  to_skift: 35.5,
}

export type Tariffgruppe = 'I_ledende' | 'II_butikk' | 'IV_under18'

export const GRUPPENAVN: Record<Tariffgruppe, string> = {
  I_ledende: 'I – Ledende personell',
  II_butikk: 'II – Butikkpersonell',
  IV_under18: 'IV – Under 18 år',
}

type Trinn = { ordinaer: number; to_skift: number }

export type Tariffbok = {
  gyldigFra: string
  satser: Record<Tariffgruppe, Record<number, Trinn>>
}

export const TARIFF_2025_07: Tariffbok = {
  gyldigFra: '2025-07-01',
  satser: {
    II_butikk: {
      0: { ordinaer: 185.58, to_skift: 196.02 },
      1: { ordinaer: 185.57, to_skift: 196.02 },
      2: { ordinaer: 188.57, to_skift: 199.19 },
      3: { ordinaer: 191.58, to_skift: 202.36 },
      4: { ordinaer: 194.57, to_skift: 205.53 },
      5: { ordinaer: 200.57, to_skift: 211.87 },
      6: { ordinaer: 241.58, to_skift: 255.18 },
    },
    I_ledende: {
      0: { ordinaer: 190.58, to_skift: 201.31 },
      1: { ordinaer: 190.52, to_skift: 201.31 },
    },
    IV_under18: {
      0: { ordinaer: 143.33, to_skift: 151.41 },
    },
  },
}

export type Treff = { gruppe: Tariffgruppe; ansiennitet: number; skift: Skiftordning }

/** Alle trinn som matcher satsen eksakt. Tom liste = satsen finnes ikke. */
export function plasserSats(sats: number, bok = TARIFF_2025_07): Treff[] {
  const ut: Treff[] = []
  for (const [gruppe, trinn] of Object.entries(bok.satser) as [Tariffgruppe, Record<number, Trinn>][]) {
    for (const [ans, t] of Object.entries(trinn)) {
      if (Math.abs(t.ordinaer - sats) < 0.005) {
        ut.push({ gruppe, ansiennitet: Number(ans), skift: 'ordinaer' })
      }
      if (Math.abs(t.to_skift - sats) < 0.005) {
        ut.push({ gruppe, ansiennitet: Number(ans), skift: 'to_skift' })
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
    for (const t of Object.values(trinn)) alle.push(t.ordinaer, t.to_skift)
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
      melding: `${GRUPPENAVN[t.gruppe]}, ansiennitet ${t.ansiennitet}`
        + `${t.skift === 'to_skift' ? ', to skift' : ''}`,
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

  const tak = Math.max(...Object.values(bok.satser.II_butikk).map((t) => t.to_skift))
  if (sats > tak) return { status: 'over', melding: 'Over høyeste tariffsats — lokal avtale.' }
  return {
    status: 'mellom',
    melding: 'Mellom to tarifftrinn. Enten en lokal avtale, eller en sats som '
      + 'ikke ble justert ved forrige oppgjør.',
  }
}
