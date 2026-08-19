import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseVaretransaksjon } from './varetransaksjon'

const FIL = join(process.cwd(), 'eksempelfiler', 'Varetransaksjonsliste 2026-05-13.xlsx')

describe.skipIf(!existsSync(FIL))('parseVaretransaksjon (ekte St1 0452-fil)', () => {
  // Lat lesing. describe.skipIf hopper over testene, men evaluerer
  // likevel kroppen for aa samle testnavn - saa en lesing her kaster
  // FOER skippingen slaar inn. Eksempelfilene ligger ikke i repoet
  // (ekte kundedata), og uten dette er CI rod paa noe som skal hoppes.
  let husket: ReturnType<typeof parseVaretransaksjon> | null = null
  const resultat = () => (husket ??= parseVaretransaksjon(readFileSync(FIL)))

  it('finner de tre stasjonene', async () => {
    const r = await resultat()
    expect(r.stasjoner.map((s) => s.butikknummer)).toEqual(['4177', '9145', '9467'])
  })

  it('leser en kjent svinn-transaksjon (Lone)', async () => {
    const r = await resultat()
    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')!
    const pant = lone.transaksjoner.find((t) => t.ean === '1001')!
    expect(pant.varenavn).toBe('Pant 2 kr')
    expect(pant.transaksjonstype).toBe('Synlig svinn')
    expect(pant.dato).toBe('2026-05-12')
    expect(pant.antall).toBe(4)
    expect(pant.nettoprisTotal).toBeCloseTo(8, 2)
  })

  it('hopper over "Sum EAN"-rader', async () => {
    const r = await resultat()
    for (const s of r.stasjoner) {
      expect(s.transaksjoner.some((t) => /^sum/i.test(t.varenavn))).toBe(false)
    }
  })
})
