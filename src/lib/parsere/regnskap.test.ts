import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseRegnskap } from './regnskap'

const FIL = join(process.cwd(), 'eksempelfiler', '190 Kelsar Bil AS 202512-202512_3 (1).xlsx')

describe.skipIf(!existsSync(FIL))('parseRegnskap (ekte Azets-fil, Cluster-ark)', () => {
  const resultat = parseRegnskap(readFileSync(FIL))

  it('leser retailernavn og periode', async () => {
    const r = await resultat
    expect(r.retailerNavn).toContain('Kelsar Bil AS')
    expect(r.periode).toMatch(/^2025-12/)
  })

  it('dekker alle fire seksjoner', async () => {
    const r = await resultat
    const seksjoner = new Set(r.linjer.map((l) => l.seksjon))
    expect([...seksjoner].sort()).toEqual([
      'bruttofortjeneste', 'driftskostnader', 'omsetning', 'resultat',
    ])
  })

  it('leser en kjent omsetningslinje (120 Mat) med regnskap + budsjett', async () => {
    const r = await resultat
    const mat = r.linjer.find((l) => l.seksjon === 'omsetning' && l.kode === '120')!
    expect(mat.post).toBe('120 Mat')
    expect(mat.regnskap).toBeCloseTo(1458573.9, 1)
    expect(mat.budsjett).toBeCloseTo(1633870.31, 1)
  })

  it('fanger omsetning totalt og resultat', async () => {
    const r = await resultat
    const total = r.linjer.find((l) => /^omsetning totalt/i.test(l.post))
    expect(total?.regnskap).toBeCloseTo(5289620.3, 0)
    expect(r.linjer.some((l) => l.seksjon === 'resultat')).toBe(true)
  })
})
