import { describe, it, expect } from 'vitest'
import { skjemaAktiv, rutineGjelder, osloNaa, type OsloNaa } from './rutineskjema'

const naa = (dato: string, ukedag: number, minutter: number): OsloNaa => ({ dato, ukedag, minutter })

describe('skjemaAktiv — samme dag', () => {
  const s = { tid_start: '06:00', tid_slutt: '14:00', ukedager: [] }
  it('midt i vinduet', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 8 * 60)).aktiv).toBe(true)
  })
  it('innenfor ±1t overlapp før', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 5 * 60 + 30)).aktiv).toBe(true) // 05:30
  })
  it('utenfor overlapp', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 4 * 60 + 30)).aktiv).toBe(false) // 04:30
  })
  it('respekterer ukedager', () => {
    expect(skjemaAktiv({ ...s, ukedager: [1] }, naa('2026-06-09', 2, 8 * 60)).aktiv).toBe(false)
  })
})

describe('skjemaAktiv — krysser midnatt 22:00–06:00', () => {
  const n = { tid_start: '22:00', tid_slutt: '06:00', ukedager: [] }
  it('kveldsdel: vakten hører til i dag', () => {
    const v = skjemaAktiv(n, naa('2026-06-08', 1, 23 * 60)) // man 23:00
    expect(v.aktiv).toBe(true)
    expect(v.vaktdag).toBe(1)
    expect(v.vaktdato).toBe('2026-06-08')
  })
  it('morgendel: vakten hører til i går', () => {
    const v = skjemaAktiv(n, naa('2026-06-09', 2, 2 * 60)) // tir 02:00
    expect(v.aktiv).toBe(true)
    expect(v.vaktdag).toBe(1) // mandag
    expect(v.vaktdato).toBe('2026-06-08')
  })
  it('midt på dagen er inaktiv', () => {
    expect(skjemaAktiv(n, naa('2026-06-09', 2, 12 * 60)).aktiv).toBe(false)
  })
  it('ukedag-filter gjelder startdagen (man-natt → tirsdag morgen)', () => {
    const manNatt = { ...n, ukedager: [1] } // kun mandag
    expect(skjemaAktiv(manNatt, naa('2026-06-09', 2, 2 * 60)).aktiv).toBe(true) // tir 02:00 = mandagsvakten
    expect(skjemaAktiv(manNatt, naa('2026-06-10', 3, 2 * 60)).aktiv).toBe(false) // ons 02:00 = tirsdagsvakt → nei
  })
})

describe('rutineGjelder — to-nivå ukedag + opprettet-dato', () => {
  const vindu = { aktiv: true, vaktdag: 1, vaktdato: '2026-06-08' }
  it('arver (tom) → gjelder', () => {
    expect(rutineGjelder({ ukedager: [], opprettet_dato: '2026-01-01' }, vindu)).toBe(true)
  })
  it('egne dager uten vaktdagen → gjelder ikke', () => {
    expect(rutineGjelder({ ukedager: [5], opprettet_dato: '2026-01-01' }, vindu)).toBe(false)
  })
  it('opprettet etter vaktdatoen → hoppes over', () => {
    expect(rutineGjelder({ ukedager: [], opprettet_dato: '2026-06-09' }, vindu)).toBe(false)
  })
})

describe('osloNaa', () => {
  it('returnerer gyldig form', () => {
    const o = osloNaa(new Date('2026-06-09T10:00:00Z'))
    expect(o.dato).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    expect(o.ukedag).toBeGreaterThanOrEqual(0)
    expect(o.ukedag).toBeLessThanOrEqual(6)
    expect(o.minutter).toBeGreaterThanOrEqual(0)
  })
})
