import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseSalesPerHour } from './salesperhour'

const FIL = join(process.cwd(), 'eksempelfiler', '0758_SalesPerHour 2026-05-13 (1).xlsx')

describe.skipIf(!existsSync(FIL))('parseSalesPerHour (ekte St1 0758-fil)', () => {
  const resultat = parseSalesPerHour(readFileSync(FIL))

  it('finner alle fem stasjonene (på navn)', async () => {
    const r = await resultat
    expect(r.stasjoner.map((s) => s.navn).sort()).toEqual([
      'St1 Bønes', 'St1 Dale', 'St1 Laguneparken', 'St1 Lone', 'St1 Varden',
    ])
    expect(r.stasjoner[0].butikknummer).toBeNull()
  })

  it('leser 24 time-bøtter med riktige salgstall for Bønes', async () => {
    const r = await resultat
    const bones = r.stasjoner.find((s) => s.navn === 'St1 Bønes')!
    expect(bones.timer).toHaveLength(24)
    expect(bones.timer.find((t) => t.time === '0-1')!.salg).toBeCloseTo(451.62, 2)
    expect(bones.timer.find((t) => t.time === '1-2')!.salg).toBeCloseTo(1097.48, 2)
  })

  it('tar ikke med grand total-raden som stasjon', async () => {
    const r = await resultat
    expect(r.stasjoner.some((s) => /totalt/i.test(s.navn))).toBe(false)
  })
})
