// EN MANGLENDE KRONEVERDI SKAL IKKE VELGE ET TILFELDIG HOVEDTILTAK.
//
// =====================================================================
// FEILEN, SLIK DEN FAKTISK SÅ UT
// =====================================================================
//
// `byggMaanedsplan` rangerte tiltakene på kroner i året, og hentet dem
// slik:
//
//     const verdi = (v: Verdi) => kronerIAret(v, siste, d.satser) ?? 0
//
// `kronerIAret` returnerer `null` når kjeden mangler royaltysatser fra
// BP — med vilje, fordi et tall uten satser ville vært bruttofortjeneste
// utgitt for netto. Men `?? 0` gjorde hvert eneste punkt til 0 kroner,
// og da sorterte `sort` en liste der alle var like. En stabil sortering
// beholder da inngangsrekkefølgen, og inngangsrekkefølgen er
// `LOFTESTENGER`-arrayet i `loftestenger.ts`.
//
// I motvind beholdes bare det største tiltaket. Butikksjefen fikk
// altså ÉN ting å gjøre, valgt av rekkefølgen konstantene tilfeldigvis
// står i en fil — og fordi lista da hadde lengde 1, slo heller ikke
// advarselen om urangerte punkter inn.
//
// ---------------------------------------------------------------------
// HVA TESTEN BEVISER
//
//   1. Flere kandidater uten satser → INGEN velges.
//   2. Rekkefølgen i `LOFTESTENGER` avgjør ikke: med satser vinner den
//      som faktisk er størst, også når den står SIST i arrayet.
//   3. Advarselen vises selv når planen ellers ville hatt ett punkt.
//
// Punkt 2 er positivkontrollen. Uten den ville testen vært grønn i en
// motor som aldri velger noe i det hele tatt.
// =====================================================================

import { describe, expect, it } from 'vitest'
import { LOFTESTENGER } from './loftestenger'
import { byggMaanedsplan, type Maanedstall, type Maanedsdata } from './plan'
import type { Satser } from '../royalty'

const SATSER: Satser = { lavSats: 0.1, hoySatsVask: 0.6, pantSats: 0 }

function mnd(over: Partial<Maanedstall> & { maaned: string }): Maanedstall {
  return {
    omsetningKr: 1_000_000, omsetningBudsjettKr: 1_000_000, bruttoKr: 500_000,
    matsalgKr: 400_000, matkastKr: 24_000,
    usynligRestKr: 5_000, usynligMatKr: 4_000,
    avvikAntall: 0, matRader: 9,
    harSvinndata: true, datastatus: 'gruppe',
    personalKr: 300_000, personalBudsjettKr: 300_000,
    paavirkbarDriftKr: 40_000, paavirkbarDriftBudsjettKr: 40_000,
    resultatKr: 50_000,
    ...over,
  }
}

function plan(historikk: Maanedstall[], satser: Satser | null, over: Partial<Maanedsdata> = {}) {
  return byggMaanedsplan({
    stasjonNavn: 'Testeriet', stasjonId: 's1', butikknummer: '4185',
    leverandorer: [], satser, kastsats: { stasjonId: 's1', aar: 2026, andel: 0.06, nivaa: 'avdeling' },
    forbehold: null, historikk, ...over,
  })
}

/**
 * To spaker som begge går feil vei, og et fallende resultat.
 *
 * `personalOver` og `driftOver` er merkostnaden mot budsjett i siste
 * måned; begge vokser lineært fra null. Den som får det STØRSTE tallet
 * er den som faktisk er størst — uavhengig av hvor den står i
 * `LOFTESTENGER`.
 */
function toSpakerFeilVei(personalOver: number, driftOver: number): Maanedstall[] {
  return [0, 1, 2, 3, 4].map((i) => mnd({
    maaned: `2026-0${i + 1}-01`,
    personalKr: 300_000 + (personalOver * i) / 4,
    paavirkbarDriftKr: 40_000 + (driftOver * i) / 4,
    // Resultatet faller → motvind → bare ETT tiltak beholdes.
    resultatKr: 200_000 - i * 30_000,
    // Matkast trygt under budsjett hele veien: 5 % mot 6 %. Da er det
    // ikke en kandidat, og de to spakene er alene om valget.
    matkastKr: 20_000,
  }))
}

// =====================================================================
describe('uten royaltysatser velges ingen av flere kandidater', () => {
  const p = plan(toSpakerFeilVei(60_000, 25_000), null)

  it('planen er i motvind', () => expect(p.dom).toBe('motvind'))

  it('det er faktisk flere enn én kandidat', () => {
    expect(p.rangering.kandidater.length).toBeGreaterThanOrEqual(2)
  })

  it('rangeringen er umulig', () => expect(p.rangering.mulig).toBe(false))

  it('INGEN tiltak er valgt', () => {
    expect(p.punkter.filter((x) => x.slag === 'tiltak')).toHaveLength(0)
  })

  it('merknaden sier hvorfor kroneverdiene mangler', () => {
    expect(p.merknad).toMatch(/royaltysatser/)
  })
})

// =====================================================================
describe('rekkefølgen i LOFTESTENGER avgjør ikke', () => {
  // Kanarifugl: står de to spakene ikke i denne rekkefølgen lenger,
  // måler resten av denne blokken noe annet enn den tror.
  const iRekka = LOFTESTENGER.filter((l) => l.klasse === 'spak').map((l) => l.id)
  it('personal står FØR paavirkbar_drift i arrayet', () => {
    expect(iRekka.indexOf('personal')).toBeLessThan(iRekka.indexOf('paavirkbar_drift'))
  })

  it('med satser vinner den største — også når den står først', () => {
    const p = plan(toSpakerFeilVei(60_000, 25_000), SATSER)
    const valgt = p.punkter.filter((x) => x.slag === 'tiltak')
    expect(valgt).toHaveLength(1)
    expect(valgt[0].loftestang).toBe('personal')
    expect(p.rangering.mulig).toBe(true)
  })

  it('med satser vinner den største — også når den står SIST', () => {
    const p = plan(toSpakerFeilVei(25_000, 60_000), SATSER)
    const valgt = p.punkter.filter((x) => x.slag === 'tiltak')
    expect(valgt).toHaveLength(1)
    expect(valgt[0].loftestang).toBe('paavirkbar_drift')
    expect(p.rangering.mulig).toBe(true)
  })

  it('uten satser velges ingen av dem, uansett hvem som er størst', () => {
    for (const h of [toSpakerFeilVei(60_000, 25_000), toSpakerFeilVei(25_000, 60_000)]) {
      const p = plan(h, null)
      expect(p.punkter.filter((x) => x.slag === 'tiltak')).toHaveLength(0)
      expect(p.rangering.mulig).toBe(false)
    }
  })
})

// =====================================================================
describe('advarselen vises selv når planen ellers har ett punkt', () => {
  // MEDVIND: resultatet stiger, så planen gir en bekreftelse OG et
  // «neste» tiltak. Bekreftelsen er ikke berørt av rangeringen, så
  // `punkter` har lengde 1 uansett — og en flate som talte punkter i
  // stedet for å lese `rangering` ville tidd helt stille.
  const historikk = [0, 1, 2, 3, 4].map((i) => mnd({
    maaned: `2026-0${i + 1}-01`,
    personalKr: 300_000 + i * 15_000,
    paavirkbarDriftKr: 40_000 + i * 6_000,
    resultatKr: 50_000 + i * 30_000,
    // Under kastbudsjettet → bekreftelsen kommer fra matkast.
    matkastKr: 20_000,
  }))
  const p = plan(historikk, null)

  it('planen er i medvind', () => expect(p.dom).toBe('medvind'))

  it('den har nøyaktig ett punkt, og det er en bekreftelse', () => {
    expect(p.punkter).toHaveLength(1)
    expect(p.punkter[0].slag).toBe('bekreftelse')
  })

  it('men rangeringen sier fortsatt at den var umulig', () => {
    expect(p.rangering.mulig).toBe(false)
    expect(p.rangering.kandidater.length).toBeGreaterThanOrEqual(2)
  })
})

// =====================================================================
describe('én enslig kandidat er ikke urangert', () => {
  // Bare drift går feil vei. Da er det ingen sammenligning å gjøre, og
  // «vi kunne ikke rangere» ville vært et falskt forbehold.
  const historikk = [0, 1, 2, 3, 4].map((i) => mnd({
    maaned: `2026-0${i + 1}-01`,
    paavirkbarDriftKr: 40_000 + i * 6_000,
    resultatKr: 200_000 - i * 30_000,
    matkastKr: 20_000,
  }))
  const p = plan(historikk, null)

  it('kandidaten er alene', () => expect(p.rangering.kandidater).toHaveLength(1))
  it('rangeringen er mulig', () => expect(p.rangering.mulig).toBe(true))
  it('og tiltaket vises', () => {
    expect(p.punkter.filter((x) => x.slag === 'tiltak')).toHaveLength(1)
  })
})
