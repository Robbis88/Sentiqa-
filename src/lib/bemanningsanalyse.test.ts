import { describe, expect, test } from 'vitest'
import {
  historiskTak, planMotFaktisk, sammenlignStasjoner, takFraUkeprofil,
  type StasjonsForbruk,
} from './bemanningsanalyse'

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
  const p = (dato: string, time: number, sum: number, kunder = 0) => ({ dato, time, sum, kunder })

  test('over- og underforbruk nettes ikke ut', () => {
    // To timer for mye tirsdag og to for lite mandag er ikke «riktig
    // bemannet» — det er to feil som skjuler hverandre.
    const r = planMotFaktisk(
      [p('2026-03-02', 12, 2), p('2026-03-03', 12, 1)],
      new Map([['2026-03-02:12', 0], ['2026-03-03:12', 3]]),
    )
    expect(r.overforbruk).toBe(2)
    expect(r.underforbruk).toBe(2)
    expect(r.faktiskeTimer - r.planlagteTimer).toBe(0) // netto null, og det lyver
  })

  test('en time uten stempling teller som null, ikke som manglende', () => {
    const r = planMotFaktisk([p('2026-03-02', 5, 1)], new Map())
    expect(r.timer[0].faktisk).toBe(0)
    expect(r.underforbruk).toBe(1)
  })

  test('peker ut dagene som ligger lengst fra planen', () => {
    const plan = [
      ...[10, 11, 12].map((t) => p('2026-03-02', t, 1)),
      ...[10, 11, 12].map((t) => p('2026-03-03', t, 1)),
    ]
    const faktisk = new Map([
      ['2026-03-03:10', 3], ['2026-03-03:11', 3], ['2026-03-03:12', 3],
    ])
    const r = planMotFaktisk(plan, faktisk)
    expect(r.verstedager[0].dato).toBe('2026-03-03')
    expect(r.verstedager[0].avvik).toBe(6)
  })

  test('peker ut klokketimene som systematisk er overbemannet', () => {
    // Tre mandager. Kl. 12 gaar som planlagt, kl. 20 staar det en for mye
    // hver gang. Det er monsteret som skal fram - ikke enkeltdagen.
    const dager = ['2026-03-02', '2026-03-09', '2026-03-16']
    const plan = dager.flatMap((d) => [12, 20].map((t) => p(d, t, 1)))
    const faktisk = new Map(dager.flatMap((d) =>
      [[`${d}:12`, 1], [`${d}:20`, 2]] as [string, number][]))
    const r = planMotFaktisk(plan, faktisk)
    expect(r.verstetimer).toEqual([{ time: 20, avvik: 3 }])
  })

  test('smaa avvik roper ikke', () => {
    const r = planMotFaktisk([p('2026-03-02', 12, 1)], new Map([['2026-03-02:12', 1]]))
    expect(r.verstedager).toHaveLength(0)
    expect(r.verstetimer).toHaveLength(0)
  })
})

describe('historiskTak', () => {
  // 2026-01-05 er en mandag.
  const man = ['2026-01-05', '2026-01-12', '2026-01-19', '2026-01-26']
  const vakt = (dato: string, fra: string, til: string) => ({ dato, fraTid: fra, tilTid: til })

  test('en time som alltid har hatt én, får taket én', () => {
    const t = historiskTak(man.map((d) => vakt(d, '09:00', '15:00')))
    expect(t.get('1:9')).toBe(1)
    expect(t.get('1:14')).toBe(1)
  })

  test('en time som ofte har hatt to, får taket to', () => {
    const t = historiskTak([
      ...man.map((d) => vakt(d, '09:00', '15:00')),
      ...man.map((d) => vakt(d, '12:00', '15:00')), // to hver mandag 12–15
    ])
    expect(t.get('1:12')).toBe(2)
    expect(t.get('1:9')).toBe(1)
  })

  test('ett enkelt personalmøte setter ikke taket for året', () => {
    // Tolv personer i én time, én gang. Laguneparken hadde nøyaktig dette.
    const t = historiskTak([
      ...man.map((d) => vakt(d, '09:00', '15:00')),
      ...Array.from({ length: 11 }, () => vakt('2026-01-05', '12:00', '13:00')),
    ])
    expect(t.get('1:12')).toBe(1)
  })

  test('en time uten historikk står åpen framfor å bli forbudt', () => {
    const t = historiskTak(man.map((d) => vakt(d, '09:00', '15:00')))
    expect(t.get('1:5')).toBeUndefined()
  })

  test('nattevakt teller på dagen timene faktisk jobbes', () => {
    // Mandag 22:00–02:00 gir to timer på mandag og to på tirsdag.
    const t = historiskTak(man.map((d) => vakt(d, '22:00', '02:00')))
    expect(t.get('1:22')).toBe(1)
    expect(t.get('2:0')).toBe(1)
    expect(t.get('2:1')).toBe(1)
  })

  test('midnatt som sluttid regnes som 24, ikke som 0', () => {
    const t = historiskTak(man.map((d) => vakt(d, '18:00', '00:00')))
    expect(t.get('1:23')).toBe(1)
    expect(t.get('2:0')).toBeUndefined()
  })
})

describe('takFraUkeprofil', () => {
  const r = (ukedag: number, time: number, antall: number, ganger: number) =>
    ({ ukedag, time, antall, ganger })

  test('gir samme svar som historiskTak på samme data', () => {
    // Fire mandager 09–15 med én person, og to av dem med to.
    const stempl = ['2026-01-05', '2026-01-12', '2026-01-19', '2026-01-26']
      .flatMap((d) => [{ dato: d, fraTid: '09:00', tilTid: '15:00' }])
      .concat(['2026-01-05', '2026-01-12'].map((d) => ({ dato: d, fraTid: '12:00', tilTid: '15:00' })))
    const fasit = historiskTak(stempl)
    const profil = takFraUkeprofil([
      r(1, 9, 1, 4), r(1, 12, 1, 2), r(1, 12, 2, 2),
    ])
    expect(profil.get('1:12')).toBe(fasit.get('1:12'))
    expect(profil.get('1:9')).toBe(fasit.get('1:9'))
  })

  test('ett personalmøte setter ikke taket', () => {
    // Tolv personer én gang, én person 40 ganger.
    expect(takFraUkeprofil([r(1, 12, 1, 40), r(1, 12, 12, 1)]).get('1:12')).toBe(1)
  })

  test('to ganger av tjue er nok når det er over ti prosent', () => {
    expect(takFraUkeprofil([r(1, 12, 1, 16), r(1, 12, 2, 2)]).get('1:12')).toBe(2)
  })

  test('to av femti er under terskelen', () => {
    expect(takFraUkeprofil([r(1, 12, 1, 48), r(1, 12, 2, 2)]).get('1:12')).toBe(1)
  })

  test('en time uten rader står åpen', () => {
    expect(takFraUkeprofil([r(1, 12, 1, 4)]).get('1:5')).toBeUndefined()
  })
})
