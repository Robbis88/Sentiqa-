import { describe, it, expect } from 'vitest'
import { kildeFor } from './fixtures/kilde'
import { lagKassererstatistikk } from './fixtures/kassererstatistikk'
import { parseKassererstatistikk } from './kassererstatistikk'

const kilde = kildeFor('0018_CashierStatistics_std 2026-05-13.xlsx', lagKassererstatistikk)

describe(`parseKassererstatistikk (St1 0018 - ${kilde.merke})`, () => {
  // SUITEN HOPPET OVER SEG SELV. `describe.skipIf(!existsSync(FIL))` mot
  // en fil i `eksempelfiler/`, som er gitignored - saa den kjorte aldri i
  // CI, og heller ikke lokalt, siden mappa er tom. Naa kjorer den mot den
  // ekte fila naar den ligger der, mot en arbeidsbok med samme form
  // ellers. Se `fixtures/LESMEG.md`.
  let husket: ReturnType<typeof parseKassererstatistikk> | null = null
  const resultat = () => (husket ??= kilde.les().then(parseKassererstatistikk))

  it('leser ett ark per stasjon med butikknummer', async () => {
    const r = await resultat()
    expect(r.dato).toBe('2026-05-11')
    expect(r.stasjoner.map((s) => s.butikknummer).sort()).toEqual([
      '4177', '4185', '9038', '9145', '9467',
    ])
  })

  it('leser kasserer-radene riktig (Lone)', async () => {
    const r = await resultat()
    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')!
    expect(lone.navn).toBe('St1 Lone')
    const oeien = lone.kasserere.find((k) => k.nr === '12')!
    expect(oeien.navn).toBe('Øien, Julian')
    expect(oeien.omsetningInkMva).toBeCloseTo(9199.88, 2)
    expect(oeien.bonger).toBe(70)
  })

  it('tar ikke med "Sum butikk"-raden som kasserer', async () => {
    const r = await resultat()
    for (const s of r.stasjoner) {
      expect(s.kasserere.some((k) => /sum butikk/i.test(k.nr))).toBe(false)
    }
  })
})
