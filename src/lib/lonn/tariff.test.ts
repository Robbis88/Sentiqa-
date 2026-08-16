import { describe, expect, test } from 'vitest'
import { plasserSats, vurderSats, TIMER_PER_UKE, TARIFF_2025_07 } from './tariff'

describe('tariffsatser', () => {
  test('to skift er 35,5 timer, ordinær er 37,5', () => {
    expect(TIMER_PER_UKE.to_skift).toBe(35.5)
    expect(TIMER_PER_UKE.ordinaer).toBe(37.5)
  })

  test('satsene fra Bønes mai 2026 plasseres i tariffen', () => {
    // Sju av ti ansatte traff eksakt da vi sjekket mot lønnseksporten.
    const fasit: [number, string, number, string][] = [
      [255.18, 'II_butikk', 6, 'to_skift'],   // Lars
      [205.53, 'II_butikk', 4, 'to_skift'],   // Maj-Linn
      [202.36, 'II_butikk', 3, 'to_skift'],   // Olaf
      [199.19, 'II_butikk', 2, 'to_skift'],   // Lena
      [185.58, 'II_butikk', 0, 'ordinaer'],   // Olav og Marius
    ]
    for (const [sats, gruppe, ans, skift] of fasit) {
      const t = plasserSats(sats)
      expect(t.some((x) => x.gruppe === gruppe && x.ansiennitet === ans && x.skift === skift),
        String(sats)).toBe(true)
    }
  })

  test('196,02 treffer to trinn — trinn 0 og 1 har samme skiftsats', () => {
    const t = plasserSats(196.02)
    expect(t).toHaveLength(2)
    expect(t.map((x) => x.ansiennitet).sort()).toEqual([0, 1])
  })
})

describe('vurderSats', () => {
  test('en tariffsats gjenkjennes og forklares', () => {
    const v = vurderSats(255.18)
    expect(v.status).toBe('tariff')
    expect(v.melding).toMatch(/Butikkpersonell/)
    expect(v.melding).toMatch(/to skift/)
  })

  test('170,14 flagges — under minstelønn for voksne', () => {
    // Helene på Bønes. 15,44 under laveste voksensats, men over
    // ungdomssatsen. Enten feil alder eller en sats som aldri ble justert.
    const v = vurderSats(170.14)
    expect(v.status).toBe('under')
    expect(v.melding).toMatch(/Sjekk alder/)
  })

  test('239,33 og 234,05 flagges som mellom trinn', () => {
    for (const s of [239.33, 234.05]) {
      expect(vurderSats(s).status, String(s)).toBe('mellom')
    }
  })

  test('en sats over høyeste trinn er en lokal avtale, ikke en feil', () => {
    expect(vurderSats(300).status).toBe('over')
  })

  test('ungdomssatsen er ikke under minstelønn', () => {
    expect(vurderSats(143.33).status).toBe('tariff')
    expect(vurderSats(151.41).status).toBe('tariff')
  })

  test('boka bærer sin egen gyldighetsdato', () => {
    // Et oppgjør i august med virkning fra 1. april betyr at avsluttede
    // perioder må kunne regnes om. Da må satsene være datert.
    expect(TARIFF_2025_07.gyldigFra).toBe('2025-07-01')
  })
})
