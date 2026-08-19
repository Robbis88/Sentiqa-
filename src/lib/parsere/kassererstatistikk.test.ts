import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseKassererstatistikk } from './kassererstatistikk'

const FIL = join(process.cwd(), 'eksempelfiler', '0018_CashierStatistics_std 2026-05-13.xlsx')

describe.skipIf(!existsSync(FIL))('parseKassererstatistikk (ekte St1 0018-fil)', () => {
  // Lat lesing. describe.skipIf hopper over testene, men evaluerer
  // likevel kroppen for aa samle testnavn - saa en lesing her kaster
  // FOER skippingen slaar inn. Eksempelfilene ligger ikke i repoet
  // (ekte kundedata), og uten dette er CI rod paa noe som skal hoppes.
  let husket: ReturnType<typeof parseKassererstatistikk> | null = null
  const resultat = () => (husket ??= parseKassererstatistikk(readFileSync(FIL)))

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
