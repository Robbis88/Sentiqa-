import { describe, expect, it } from 'vitest'
import { beregnAvtaledatoer } from './avtale-dato'

describe('avtaledatoer', () => {
  it('regner to måneder og tolv måneders binding fra 15. oktober', () => {
    expect(beregnAvtaledatoer('2026-10-15')).toEqual({ trial_starts_at: '2026-10-15', trial_ends_at: '2026-12-14', first_payment_date: '2026-12-15', commitment_starts_at: '2026-12-15', commitment_ends_at: '2027-12-14' })
  })
  it('klipper dag 31 til siste dag i måneden', () => {
    expect(beregnAvtaledatoer('2027-01-31', 1, 12).trial_ends_at).toBe('2027-02-27')
    expect(beregnAvtaledatoer('2028-01-31', 1, 12).first_payment_date).toBe('2028-02-29')
  })
})
