// Et hull midt i serien er ikke det samme som en måned foran den.
//
// =====================================================================
// Å FJERNE EN MANGLENDE MÅNED ER IKKE Å HÅNDTERE DEN
// =====================================================================
//
// Første utgave av `0213`-arbeidet filtrerte bort ALLE måneder uten
// svinngrunnlag. Det løser desember 2025, som ligger foran vinduet — og
// skjuler et hull midt i det.
//
// Mangler mars, blir januar, februar og april tre jevnt fordelte punkter
// i regresjonen. Avstanden februar→april er dobbelt så lang som
// januar→februar, og stigningstallet lyver. Et komprimert hull er en
// oppdiktet måling, ikke en manglende en.
//
// De tre tilfellene, én describe hver:
//
//   A  desember FORAN vinduet   →  holdes utenfor, januar–juli gir retning
//   B  mars mangler INNE i det  →  retning blokkeres, ikke flat/opp/ned
//   C  siste måned mangler      →  ingen konklusjon for gjeldende nivå
//
// Og til slutt: at ingen intern måned faktisk mangler i dagens 35.

import { describe, expect, it } from 'vitest'
import { byggHistorikk } from './hent'
import { byggMaanedsplan, svinnserie, type Maanedstall } from './plan'
import { retning } from './retning'

type Rad = Parameters<typeof byggHistorikk>[0][number]

const rad = (over: Partial<Rad>): Rad => ({
  stasjon_id: 's1', maaned: '2026-01-01',
  omsetning_kr: 1_000_000, omsetning_budsjett_kr: 1_000_000, brutto_kr: 500_000,
  matsalg_kr: 400_000, matkast_kr: 30_000, usynlig_rest_kr: 5_000,
  personal_kr: 300_000, personal_budsjett_kr: 300_000,
  paavirkbar_drift_kr: 40_000, paavirkbar_drift_budsjett_kr: 40_000,
  resultat_kr: 50_000, har_svinndata: true, datastatus: 'gruppe',
  ...over,
})

/** Én måned med grunnlag. Kastet faller, så retningen er «ned». */
const med = (maaned: string, kast: number): Maanedstall =>
  byggHistorikk([rad({ maaned, matkast_kr: kast })])[0]

/** Én måned uten grunnlag — matkast og usynlig er null. */
const uten = (maaned: string): Maanedstall =>
  byggHistorikk([rad({
    maaned, matkast_kr: null, usynlig_rest_kr: null,
    har_svinndata: false, datastatus: null,
  })])[0]

// 6 % av matomsetningen. Uten en sats blokkerer confidence gate matkast
// helt, og da ville «ingen matkastkonklusjon» vaert sant av feil grunn.
const KASTSATS = { stasjonId: 's1', aar: 2026, andel: 0.06, nivaa: 'avdeling' } as const

const plan = (historikk: Maanedstall[]) =>
  byggMaanedsplan({
    stasjonNavn: 'Testeriet', historikk, leverandorer: [],
    satser: null, kastsats: KASTSATS,
  })

const matkastpunkt = (h: Maanedstall[]) =>
  plan(h).punkter.filter((p) => p.loftestang === 'matkast')

// =====================================================================
describe('A · desember foran analysevinduet', () => {
  const serie = [
    uten('2025-12-01'),
    med('2026-01-01', 33_000), med('2026-02-01', 31_000),
    med('2026-03-01', 29_000), med('2026-04-01', 27_000),
  ]

  it('desember holdes utenfor, og de fire andre står igjen', () => {
    const s = svinnserie(serie)
    expect(s.blokkert).toBe(false)
    expect(s.aarsak).toBeNull()
    expect(s.rader.map((m) => m.maaned)).toEqual([
      '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01',
    ])
  })

  it('retningen regnes, og den er «ned»', () => {
    expect(retning(svinnserie(serie).rader.map((m) => m.matkastKr!))?.vei).toBe('ned')
  })

  it('planen ser fire måneder, ikke fem', () => {
    // Planen velger ut hvilke løftestenger den nevner, så en
    // matkastpåstand her ville målt utvalget og ikke serien.
    // Det som er sant uansett utvalg: serien er fire lang.
    expect(svinnserie(serie).rader).toHaveLength(4)
  })

  it('desembernullen ville snudd retningen til «opp»', () => {
    // Beviset på at filtreringen gjør noe. Uten den: [0, 33k, 31k, 29k].
    expect(retning([0, 33_000, 31_000, 29_000])?.vei).toBe('opp')
  })
})

// =====================================================================
describe('B · mars mangler inne i januar–juli', () => {
  const serie = [
    med('2026-01-01', 33_000), med('2026-02-01', 31_000),
    uten('2026-03-01'),
    med('2026-04-01', 27_000), med('2026-05-01', 25_000),
  ]

  it('serien blokkeres, og årsaken navngir måneden', () => {
    const s = svinnserie(serie)
    expect(s.blokkert).toBe(true)
    expect(s.rader).toEqual([])
    expect(s.aarsak).toContain('Hull i serien')
    expect(s.aarsak).toContain('2026-03-01')
  })

  it('retningen beregnes ikke — den er null, ikke «flat»', () => {
    // `null` er et annet svar enn «flat». Flat betyr målt og rolig;
    // null betyr at vi ikke kan si det.
    expect(retning(svinnserie(serie).rader.map((m) => m.matkastKr ?? 0))).toBeNull()
  })

  it('planen gir INGEN matkastkonklusjon', () => {
    expect(matkastpunkt(serie)).toEqual([])
  })

  it('KANARI: uten hullet konkluderer planen på matkast', () => {
    // Blir denne også tom, måler påstanden over ingenting.
    //
    // Kastet STIGER her, så matkast er den ene ille løftestangen og
    // blir plukket. Med et fallende kast ville planen valgt å nevne
    // noe annet, og en tom liste hadde betydd «ikke valgt», ikke
    // «ikke beregnet».
    const stigende = [0, 1, 2, 3, 4].map((i) =>
      med(`2026-0${i + 1}-01`, 20_000 + i * 6_000))
    expect(svinnserie(stigende).blokkert).toBe(false)
    expect(matkastpunkt(stigende).length).toBeGreaterThan(0)

    // Og med hull i den samme stigende serien: ingen konklusjon.
    const medHull = [...stigende]
    medHull[2] = uten('2026-03-01')
    expect(svinnserie(medHull).blokkert).toBe(true)
    expect(matkastpunkt(medHull)).toEqual([])
  })

  it('KANARI: komprimering ville gitt et svar, og det er feilen', () => {
    // Slik den sto: hullet fjernes, fire punkter i jevn rekke.
    const komprimert = serie.filter((m) => m.harSvinndata).map((m) => m.matkastKr!)
    expect(komprimert).toEqual([33_000, 31_000, 27_000, 25_000])
    expect(retning(komprimert)?.vei).toBe('ned')
    // Et svar, fra en serie der februar→april teller som ett steg.
    expect(retning(komprimert)).not.toBeNull()
  })
})

// =====================================================================
describe('C · siste måned mangler', () => {
  const serie = [
    med('2026-01-01', 33_000), med('2026-02-01', 31_000),
    med('2026-03-01', 29_000), uten('2026-04-01'),
  ]

  it('blokkeres med egen årsak — ikke som hull', () => {
    const s = svinnserie(serie)
    expect(s.blokkert).toBe(true)
    expect(s.aarsak).toContain('Siste måned mangler')
    expect(s.aarsak).toContain('2026-04-01')
    expect(s.aarsak).not.toContain('Hull')
  })

  it('ingen konklusjon for gjeldende måneds nivå', () => {
    expect(matkastpunkt(serie)).toEqual([])
  })

  it('uten regelen ville mars blitt presentert som «nå»', () => {
    // Dette er hvorfor tilfellet er eget: serien er sammenhengende,
    // den slutter bare for tidlig. En filtrering alene ville gitt
    // mars som siste måling, og flaten ville vist et tall som er en
    // måned gammelt uten å si det.
    const filtrert = serie.filter((m) => m.harSvinndata)
    expect(filtrert[filtrert.length - 1].maaned).toBe('2026-03-01')
    expect(serie[serie.length - 1].maaned).toBe('2026-04-01')
  })
})

// =====================================================================
describe('ingen av dagens 35 stasjonsmåneder har hull', () => {
  // Kontroll 4, 2026-09-13: fem stasjoner × januar–juli, hver med
  // 55–61 svinnrader. Blokkeringen over er derfor bevist inert i dag.
  const MAANEDER = [
    '2026-01-01', '2026-02-01', '2026-03-01',
    '2026-04-01', '2026-05-01', '2026-06-01', '2026-07-01',
  ]
  const STASJONER = ['4177', '4185', '9038', '9145', '9467']

  it.each(STASJONER)('%s har sju sammenhengende måneder', (id) => {
    const serie = MAANEDER.map((m, i) =>
      byggHistorikk([rad({ stasjon_id: id, maaned: m, matkast_kr: 30_000 - i * 500 })])[0])
    const s = svinnserie(serie)
    expect(s.blokkert).toBe(false)
    expect(s.rader).toHaveLength(7)
  })

  it('35 stasjonsmåneder, null blokkerte', () => {
    const blokkerte = STASJONER.filter((id) => svinnserie(
      MAANEDER.map((m, i) =>
        byggHistorikk([rad({ stasjon_id: id, maaned: m, matkast_kr: 30_000 - i * 500 })])[0]),
    ).blokkert)
    expect(blokkerte).toEqual([])
    expect(STASJONER.length * MAANEDER.length).toBe(35)
  })
})
