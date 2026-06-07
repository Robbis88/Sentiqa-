import { describe, it, expect } from 'vitest'
import { produksjonsfaktor } from './produksjonsplan'

describe('produksjonsfaktor', () => {
  it('utfart + solrik helg løfter kald drikke', () => {
    expect(produksjonsfaktor('utfart', { temp_maks: 22, nedbor_mm: 0 }, 6, 'Kald drikke')).toBeGreaterThan(1.2)
  })
  it('pendler i helg demper', () => {
    expect(produksjonsfaktor('pendler', null, 0, 'Baguett')).toBeLessThan(1)
  })
  it('nøytral hverdag på bydel uten vær = 1', () => {
    expect(produksjonsfaktor('bydel', null, 3, 'Baguett')).toBe(1)
  })
})
