// Manglende svinndata skal aldri bli 0 kroner.
//
// =====================================================================
// FEM PERFEKTE MÅNEDER SOM ALDRI BLE MÅLT
// =====================================================================
//
// `v_kurs_maanedstall` gjorde `coalesce(matkast_kr, 0)`, og joinen mot
// svinn er en `left join` der regnskapet avgjør om måneden finnes.
// Desemberfila 2025 er i eldre rapportformat og har ingen svinnrader i
// det hele tatt.
//
// Målt i produksjon 2026-09-13 — matomsetning fra 121 185 til 511 258
// kroner, matkast 0, svinnrader 0, på alle fem stasjonene. `0213` retter
// kontrakten; denne fila beviser at koden respekterer den.
//
// De fire påstandene Robert satte opp, én test hver:
//
//   1  manglende svinndata blir ikke 0
//   2  ekte null er fortsatt 0
//   3  manglende måned kommer ikke inn i trendserien som null
//   4  januar–juli er identiske med dagens verifiserte tall
//
// Den femte — «desember blokkeres med riktig årsak» — hører til
// confidence gate i PR 2. Her blokkeres den uten årsak, og det er
// forskjellen mellom en grense og en forklaring.

import { describe, expect, it } from 'vitest'
import { byggHistorikk } from './hent'
import { byggMaanedsplan, medSvinngrunnlag, type Maanedstall } from './plan'
import { retning } from './retning'

type Rad = Parameters<typeof byggHistorikk>[0][number]

const rad = (over: Partial<Rad>): Rad => ({
  stasjon_id: 's1', maaned: '2026-07-01',
  omsetning_kr: 0, omsetning_budsjett_kr: 0, brutto_kr: 0,
  matsalg_kr: 0, matkast_kr: 0, usynlig_rest_kr: 0,
  personal_kr: 0, personal_budsjett_kr: 0,
  paavirkbar_drift_kr: 0, paavirkbar_drift_budsjett_kr: 0,
  resultat_kr: 0, har_svinndata: true, datastatus: 'gruppe',
  ...over,
})

// De fem desemberradene, slik kontroll 4 leste dem 2026-09-13.
const DESEMBER: Rad[] = [
  { stasjon_id: '4185', matsalg_kr: 511_258 },
  { stasjon_id: '9038', matsalg_kr: 377_406 },
  { stasjon_id: '4177', matsalg_kr: 273_865 },
  { stasjon_id: '9145', matsalg_kr: 174_860 },
  { stasjon_id: '9467', matsalg_kr: 121_185 },
].map((s) => rad({
  ...s, maaned: '2025-12-01',
  matkast_kr: null, usynlig_rest_kr: null,
  har_svinndata: false, datastatus: null,
}))

describe('1 · manglende svinndata blir ikke 0', () => {
  it.each(DESEMBER.map((d) => [d.stasjon_id, d] as const))(
    'desember 2025 på %s gir null, ikke null kroner',
    (_id, d) => {
      const [m] = byggHistorikk([d])
      expect(m.matkastKr).toBeNull()
      expect(m.usynligRestKr).toBeNull()
      expect(m.harSvinndata).toBe(false)
      expect(m.datastatus).toBeNull()
      // Matomsetningen ER der. Det er nettopp derfor nullen var farlig:
      // en nevner uten teller ser ut som en perfekt måned.
      expect(m.matsalgKr).toBeGreaterThan(100_000)
    },
  )

  it('KANARI: `?? 0` i stedet for null gjør testen grønn av feil grunn', () => {
    // Beviset på at påstanden over måler noe. Slik den sto før 0213:
    const somFoer = Number(DESEMBER[0].matkast_kr ?? 0)
    expect(somFoer).toBe(0)
    expect(byggHistorikk([DESEMBER[0]])[0].matkastKr).not.toBe(somFoer)
  })

  it('viewet kan ikke sende har_svinndata=false med et tall', () => {
    // Skulle basen likevel gjøre det, vinner flagget. Kolonnen er
    // autoriteten, ikke verdien.
    const [m] = byggHistorikk([rad({ har_svinndata: false, matkast_kr: 9_999 })])
    expect(m.matkastKr).toBeNull()
  })
})

describe('2 · ekte null er fortsatt 0', () => {
  it('en måned med svinnrader og null kroner kast gir 0', () => {
    const [m] = byggHistorikk([
      rad({ matsalg_kr: 300_000, matkast_kr: 0, usynlig_rest_kr: 0, har_svinndata: true }),
    ])
    expect(m.matkastKr).toBe(0)
    expect(m.usynligRestKr).toBe(0)
    expect(m.harSvinndata).toBe(true)
  })

  it('0 og null er ulike svar, ikke to skrivemåter', () => {
    const medData = byggHistorikk([rad({ matkast_kr: 0, har_svinndata: true })])[0]
    const utenData = byggHistorikk([rad({ matkast_kr: null, har_svinndata: false })])[0]
    expect(medData.matkastKr).toBe(0)
    expect(utenData.matkastKr).toBeNull()
    expect(medData.matkastKr).not.toBe(utenData.matkastKr)
  })

  it('negativt usynlig svinn beholder fortegn', () => {
    // Minus er overskudd og helt normalt. En `Math.abs` eller en
    // `?? 0` her ville gjort et overskudd til ingenting.
    const [m] = byggHistorikk([rad({ usynlig_rest_kr: -4_200, har_svinndata: true })])
    expect(m.usynligRestKr).toBe(-4_200)
  })
})

describe('3 · manglende måned kommer ikke inn i trendserien', () => {
  const januarTilJuli = (kast: number[]): Maanedstall[] =>
    kast.map((k, i) => byggHistorikk([
      rad({ maaned: `2026-0${i + 1}-01`, matsalg_kr: 400_000, matkast_kr: k }),
    ])[0])

  it('desember faller ut før retningen regnes', () => {
    const serie = [...byggHistorikk(DESEMBER.slice(0, 1)), ...januarTilJuli([30, 29, 28])]
    expect(serie).toHaveLength(4)
    expect(medSvinngrunnlag(serie)).toHaveLength(3)
    expect(medSvinngrunnlag(serie).every((m) => m.harSvinndata)).toBe(true)
  })

  it('en null i serien ville snudd retningen', () => {
    // Uten filteret: desember 0, så 30, 29, 28 — en kraftig stigning
    // ut av et nullpunkt som aldri ble målt.
    const medNull = retning([0, 30, 29, 28])
    const utenNull = retning([30, 29, 28])
    expect(medNull?.vei).toBe('opp')
    expect(utenNull?.vei).toBe('ned')
  })

  it('filteret er inert på dagens data', () => {
    // MÅLT: `fraOgMedIAaret` starter serien i januar i BP-året, så
    // desember 2025 ligger allerede utenfor vinduet. Filteret fjerner
    // null måneder i dag — det står for at fellen ikke skal slå til
    // når vinduet en gang utvides.
    const janJul = januarTilJuli([30, 29, 28, 27, 26, 25, 24])
    expect(medSvinngrunnlag(janJul)).toEqual(janJul)
  })

  it('for kort serie gir null retning, ikke «flat»', () => {
    expect(retning([30, 29])).toBeNull()
  })

  it('KOBLET INN: byggMaanedsplan ser ikke desember i matkastserien', () => {
    // En vakt som er eksportert uten aa bli kalt, vokter ingenting.
    // Her gaar hele veien gjennom `byggMaanedsplan`.
    const historikk = [
      byggHistorikk([rad({
        maaned: '2025-12-01', matsalg_kr: 511_258,
        matkast_kr: null, usynlig_rest_kr: null,
        har_svinndata: false, datastatus: null,
        omsetning_kr: 1_000_000, omsetning_budsjett_kr: 1_000_000,
        brutto_kr: 500_000, resultat_kr: 10_000,
      })])[0],
      ...[1, 2, 3].map((i) => byggHistorikk([rad({
        maaned: `2026-0${i}-01`, matsalg_kr: 400_000,
        matkast_kr: 31_000 - i * 1_000, usynlig_rest_kr: 5_000,
        omsetning_kr: 1_000_000, omsetning_budsjett_kr: 1_000_000,
        brutto_kr: 500_000, resultat_kr: 10_000 + i * 1_000,
      })])[0]),
    ]
    const plan = byggMaanedsplan({
      stasjonNavn: 'Testeriet', historikk, leverandorer: [], satser: null,
    })
    // Matkastet FALLER over de tre maanedene med grunnlag. Kom
    // desembernullen med, ville serien vaert [0, 30k, 29k, 28k] og
    // matkast blitt et tiltak - fra et nullpunkt som aldri ble maalt.
    const matkasttiltak = plan.punkter.filter(
      (p) => p.loftestang === 'matkast' && p.slag === 'tiltak')
    expect(matkasttiltak).toHaveLength(0)
  })
})

describe('4 · januar–juli er uendret', () => {
  // De verifiserte tallene fra kontroll 4, 2026-09-13. Endres noen av
  // dem, har 0213 flyttet et tall den ikke skulle røre.
  const JULI: [string, number, number][] = [
    ['4177', 397_163, 32_730],
    ['4185', 838_292, 32_019],
    ['9038', 393_159, 48_718],
    ['9145', 172_472, 19_116],
    ['9467', 135_687, 26_230],
  ]

  it.each(JULI)('%s juli går uendret gjennom', (id, salg, kast) => {
    const [m] = byggHistorikk([rad({
      stasjon_id: id, maaned: '2026-07-01',
      matsalg_kr: salg, matkast_kr: kast, har_svinndata: true,
    })])
    expect(m.matsalgKr).toBe(salg)
    expect(m.matkastKr).toBe(kast)
    expect(m.harSvinndata).toBe(true)
  })

  it('alle 35 stasjonsmånedene har svinngrunnlag', () => {
    // Kontroll 4 målte 55–61 svinnrader på hver. Ingen av dem skal
    // falle ut av serien.
    const alle = JULI.flatMap(([id, salg, kast]) =>
      [1, 2, 3, 4, 5, 6, 7].map((i) => byggHistorikk([rad({
        stasjon_id: id, maaned: `2026-0${i}-01`,
        matsalg_kr: salg, matkast_kr: kast, har_svinndata: true,
      })])[0]))
    expect(alle).toHaveLength(35)
    expect(medSvinngrunnlag(alle)).toHaveLength(35)
  })
})
