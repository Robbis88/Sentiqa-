import { describe, expect, test } from 'vitest'
import { planMotFaktisk, sammenlignStasjoner, type StasjonsForbruk } from './bemanningsanalyse'

// Tallene er hentet fra de ekte eksportene: Bønes 687 t/mnd, Laguneparken
// 1201 t/mnd. Kundetall og matandel er satt for å prøve ut logikken.
const st = (navn: string, timer: number, kunder: number, oms: number, mat: number): StasjonsForbruk =>
  ({ stasjonId: navn, navn, timer, kunder, omsetning: oms, matOmsetning: mat })

describe('sammenlignStasjoner', () => {
  const gruppe = [
    st('Dale', 700, 14000, 1000000, 200000),
    st('Varden', 690, 13800, 1000000, 200000),
    st('Bønes', 687, 13700, 1000000, 200000),
  ]

  test('under tre stasjoner finnes det ingen målestokk', () => {
    const r = sammenlignStasjoner(gruppe.slice(0, 2))
    expect(r.every((x) => x.vurdering === 'for lite data')).toBe(true)
  })

  test('like stasjoner er normale, ingen ropes ut', () => {
    const r = sammenlignStasjoner(gruppe)
    expect(r.every((x) => x.vurdering === 'normalt')).toBe(true)
  })

  test('høyt timeforbruk med lite mat er timer å hente', () => {
    const r = sammenlignStasjoner([...gruppe,
      st('Sløseriet', 1200, 13700, 1000000, 20000)])
    const s = r.find((x) => x.navn === 'Sløseriet')!
    expect(s.vurdering).toBe('romslig')
    expect(s.begrunnelse).toMatch(/lite mat/)
    expect(s.begrunnelse).toMatch(/timer å hente/)
  })

  test('høyt timeforbruk med mye mat får en annen beskjed', () => {
    const r = sammenlignStasjoner([...gruppe,
      st('Matbua', 1200, 13700, 1000000, 600000)])
    const s = r.find((x) => x.navn === 'Matbua')!
    expect(s.vurdering).toBe('romslig')
    expect(s.begrunnelse).toMatch(/Tilberedt mat tar tid/)
    expect(s.begrunnelse).not.toMatch(/timer å hente/)
  })

  test('lavt timeforbruk uten mat er noe å lære av', () => {
    const r = sammenlignStasjoner([...gruppe,
      st('Effektiv', 400, 13700, 1000000, 100000)])
    const s = r.find((x) => x.navn === 'Effektiv')!
    expect(s.vurdering).toBe('stramt')
    expect(s.begrunnelse).toMatch(/hvordan de har lagt opp vaktene/)
  })

  test('lavt timeforbruk MED mye mat er en advarsel, ikke ros', () => {
    const r = sammenlignStasjoner([...gruppe,
      st('Presset', 400, 13700, 1000000, 700000)])
    const s = r.find((x) => x.navn === 'Presset')!
    expect(s.vurdering).toBe('stramt')
    expect(s.begrunnelse).toMatch(/paa bekostning av folk|på bekostning av folk/)
  })

  test('små forskjeller utløser ingenting', () => {
    const r = sammenlignStasjoner([...gruppe, st('Nesten', 770, 13700, 1000000, 200000)])
    expect(r.find((x) => x.navn === 'Nesten')!.vurdering).toBe('normalt')
  })

  test('en stasjon uten kunder får ikke en dom', () => {
    const r = sammenlignStasjoner([...gruppe, st('Ny', 0, 0, 0, 0)])
    expect(r.find((x) => x.navn === 'Ny')!.vurdering).toBe('for lite data')
  })
})

describe('planMotFaktisk', () => {
  test('skiller over- fra underforbruk i stedet for å nette dem ut', () => {
    // Netto null, men to timer for mye tirsdag og to for lite mandag er
    // ikke «riktig bemannet» — det er to feil som skjuler hverandre.
    const plan = [
      { ukedag: 1, time: 12, sum: 2, kunder: 40 },
      { ukedag: 2, time: 12, sum: 1, kunder: 10 },
    ]
    const r = planMotFaktisk(plan, new Map([['1:12', 0], ['2:12', 3]]))
    expect(r.overforbruk).toBe(2)
    expect(r.underforbruk).toBe(2)
    expect(r.timer[0]).toMatchObject({ planlagt: 2, faktisk: 0 })
  })

  test('en time uten stempling teller som null, ikke som manglende', () => {
    const r = planMotFaktisk([{ ukedag: 1, time: 5, sum: 1, kunder: 0 }], new Map())
    expect(r.timer[0].faktisk).toBe(0)
    expect(r.underforbruk).toBe(1)
  })
})
