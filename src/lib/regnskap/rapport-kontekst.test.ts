import { describe, expect, it } from 'vitest'
import { lagRapportKontekst } from './rapport-kontekst'

describe('RapportKontekst', () => {
  it('holder måned og hittil i år adskilt', () => {
    expect(lagRapportKontekst({ periode: '2026-07-01', modus: 'maaned' })).toMatchObject({ fra: '2026-07-01', til: '2026-07-01', etikett: 'juli 2026' })
    expect(lagRapportKontekst({ periode: '2026-07-01', modus: 'hittil' })).toMatchObject({ fra: '2026-01-01', til: '2026-07-01', etikett: 'Hittil i år 2026' })
  })
})
