import { describe, expect, test } from 'vitest'
import { nesteRetning, harStaattLenge, LANG_VAKT_TIMER } from './tilstand'

describe('nesteRetning', () => {
  test('uten hendelser stempler man inn', () => {
    expect(nesteRetning(null)).toBe('inn')
  })

  test('sist inne betyr at neste trykk er ut', () => {
    expect(nesteRetning({ type: 'inn', tidspunkt: '2026-08-19T07:00:00+02:00' })).toBe('ut')
  })

  test('sist ute betyr at neste trykk er inn', () => {
    expect(nesteRetning({ type: 'ut', tidspunkt: '2026-08-19T15:00:00+02:00' })).toBe('inn')
  })

  test('doegnskifte gjor ikke en aapen vakt til en ny', () => {
    // Inn 23:30, trykker igjen 00:30. Hun skal stemple UT - vakten er
    // den samme selv om datoen har skiftet. Ser man paa dato i stedet
    // for siste hendelse, blir det to halve vakter og ingen hel.
    expect(nesteRetning({ type: 'inn', tidspunkt: '2026-08-19T23:30:00+02:00' })).toBe('ut')
  })
})

describe('harStaattLenge', () => {
  const naa = new Date('2026-08-20T12:00:00+02:00')

  test('en aapen vakt over terskelen varsles', () => {
    const inn = { type: 'inn' as const, tidspunkt: '2026-08-19T19:00:00+02:00' }
    expect(harStaattLenge(inn, naa)).toBe(true)
  })

  test('en lang, men lovlig vakt varsles ikke', () => {
    // Et varsel som fyrer paa normale vakter blir ignorert naar det
    // gjelder. Ti timer er en vakt, ikke en feil.
    const inn = { type: 'inn' as const, tidspunkt: '2026-08-20T02:00:00+02:00' }
    expect(harStaattLenge(inn, naa)).toBe(false)
  })

  test('noyaktig paa terskelen varsles', () => {
    const timer = LANG_VAKT_TIMER
    const inn = {
      type: 'inn' as const,
      tidspunkt: new Date(naa.getTime() - timer * 3_600_000).toISOString(),
    }
    expect(harStaattLenge(inn, naa)).toBe(true)
  })

  test('den som er ute varsles ikke uansett hvor lenge siden', () => {
    const ut = { type: 'ut' as const, tidspunkt: '2020-01-01T00:00:00+01:00' }
    expect(harStaattLenge(ut, naa)).toBe(false)
  })

  test('ingen hendelser varsler ikke', () => {
    expect(harStaattLenge(null, naa)).toBe(false)
  })
})
