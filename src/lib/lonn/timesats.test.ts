import { describe, expect, test } from 'vitest'
import { lesTimesats } from './timesats'

const verdi = (s: unknown) => {
  const r = lesTimesats(s)
  return r.ok ? r.verdi : `FEIL: ${r.feil}`
}

describe('lesTimesats', () => {
  test('komma godtas — det er slik satsen står på lønnsslippen', () => {
    expect(verdi('196,02')).toBe(196.02)
  })

  test('punktum godtas også', () => {
    expect(verdi('196.02')).toBe(196.02)
  })

  test('mellomrom rundt tallet er ikke en feil', () => {
    expect(verdi('  241,58  ')).toBe(241.58)
  })

  test('tomt felt fjerner satsen igjen', () => {
    expect(verdi('')).toBeNull()
    expect(verdi('   ')).toBeNull()
  })

  test('null og negativt avvises', () => {
    expect(lesTimesats('0').ok).toBe(false)
    expect(lesTimesats('-196').ok).toBe(false)
  })

  test('en månedslønn i satsfeltet fanges', () => {
    const r = lesTimesats('34000')
    expect(r.ok).toBe(false)
    expect(r.ok === false && r.feil).toContain('månedslønn')
  })

  test('tekst avvises med et eksempel, ikke bare et nei', () => {
    const r = lesTimesats('hundre')
    expect(r.ok).toBe(false)
    expect(r.ok === false && r.feil).toContain('196,02')
  })

  test('rundes til øre — en flyttallsrest ville dukket opp i tariffsjekken', () => {
    expect(verdi('196,019999')).toBe(196.02)
  })

  test('ikke-tekst avvises framfor å bli tolket', () => {
    expect(lesTimesats(null).ok).toBe(false)
    expect(lesTimesats(196.02).ok).toBe(false)
  })
})
