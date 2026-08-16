import { describe, expect, test } from 'vitest'
import { vurderEksponering, type Maanedstimer } from './eksponering'

const T100 = 162.5
const mnd = (fra: string, antall: number, prosent: number | ((m: number) => number)): Maanedstimer[] => {
  const [a0, m0] = fra.split('-').map(Number)
  return Array.from({ length: antall }, (_, i) => {
    const m = ((m0 - 1 + i) % 12) + 1
    const ar = a0 + Math.floor((m0 - 1 + i) / 12)
    const p = typeof prosent === 'function' ? prosent(m) : prosent
    return { maaned: `${ar}-${String(m).padStart(2, '0')}`, timer: (p / 100) * T100 }
  })
}
const person = (k: number | null, ramme = false) =>
  ({ ansattNr: '1', navn: 'Test', kontraktProsent: k, harRammeavtale: ramme })

describe('vurderEksponering', () => {
  test('den som jobber kontrakten sin får ingen beskjed', () => {
    const r = vurderEksponering(person(20), mnd('2025-08', 12, 20))
    expect(r.vurdering).toBe('ok')
  })

  test('små avvik roper ikke — 23 % på en 20 %-kontrakt er greit', () => {
    expect(vurderEksponering(person(20), mnd('2025-08', 12, 23)).vurdering).toBe('ok')
  })

  test('jevnt over kontrakten er § 14-4 a, ikke rammeavtale', () => {
    const r = vurderEksponering(person(20), mnd('2025-08', 12, 45))
    expect(r.vurdering).toBe('bor_okes')
    expect(r.melding).toMatch(/14-4 a/)
    expect(r.melding).toMatch(/hjelper ikke/)
  })

  test('20 % hele året, 80 % om sommeren = sesong', () => {
    // Nøyaktig Roberts eksempel: alle måneder utenom juni, juli, august.
    const r = vurderEksponering(person(20),
      mnd('2025-01', 24, (m) => ([6, 7, 8].includes(m) ? 80 : 20)))
    expect(r.vurdering).toBe('sesong')
    expect(r.sesong?.maaneder).toEqual([6, 7, 8])
    expect(r.melding).toMatch(/midlertidig avtale/)
    expect(r.melding).toMatch(/juni, juli, august/)
  })

  test('sesong over årsskiftet henger sammen', () => {
    // Julehandel: desember og januar.
    const r = vurderEksponering(person(20),
      mnd('2025-01', 24, (m) => ([12, 1].includes(m) ? 70 : 20)))
    expect(r.vurdering).toBe('sesong')
    expect(r.sesong?.maaneder).toEqual([12, 1])
  })

  test('spredte topper er IKKE sesong', () => {
    // Høye måneder i februar, juni og oktober — ingen sammenheng.
    const r = vurderEksponering(person(20),
      mnd('2025-01', 24, (m) => ([2, 6, 10].includes(m) ? 70 : 20)))
    expect(r.sesong).toBeNull()
  })

  test('enkeltmåneder over kontrakten uten rammeavtale flagges', () => {
    // Snittet er greit, men to måneder stikker opp.
    const r = vurderEksponering(person(20, false),
      mnd('2025-01', 12, (m) => (m === 3 ? 55 : 18)))
    expect(r.vurdering).toBe('mangler_ramme')
    expect(r.melding).toMatch(/overtid/)
  })

  test('med rammeavtale er de samme månedene i orden', () => {
    const r = vurderEksponering(person(20, true),
      mnd('2025-01', 12, (m) => (m === 3 ? 55 : 18)))
    expect(r.vurdering).toBe('ok')
  })

  test('uten bekreftet kontrakt sier den fra i stedet for å gjette', () => {
    const r = vurderEksponering(person(null), mnd('2025-01', 12, 40))
    expect(r.vurdering).toBe('ukjent')
    expect(r.snittProsent).toBe(40)
  })

  test('Olaf på Bønes — median 19 %, topp 66 %', () => {
    // Ekte tall: median 30 t, maks 107 t.
    const r = vurderEksponering(person(20, false), [
      ...mnd('2025-01', 11, 19),
      { maaned: '2025-12', timer: 107 },
    ])
    expect(r.toppProsent).toBe(66)
    expect(r.vurdering).toBe('mangler_ramme')
  })
})
