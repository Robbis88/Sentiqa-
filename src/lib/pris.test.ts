import { describe, it, expect } from 'vitest'
import { beregnAbonnement } from './pris'

describe('beregnAbonnement', () => {
  it('5 stasjoner uten premium = 1744 kr/mnd (§4-eksempelet)', () => {
    const { maaned } = beregnAbonnement(5, false)
    expect(maaned).toBe(1744)
  })
  it('årlig = 10 måneder (2 gratis)', () => {
    const { maaned, aarlig } = beregnAbonnement(5, false)
    expect(aarlig).toBe(maaned * 10)
  })
  it('premium legger til Avtalevokter', () => {
    expect(beregnAbonnement(0, true).maaned).toBe(499 + 199)
  })
})
