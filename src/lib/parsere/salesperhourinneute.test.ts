import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseSalesPerHourInneUte } from './salesperhourinneute'

const FIL = join(process.cwd(), 'eksempelfiler', 'Timesalgsrapport med inne- og utekunder 2026-06-10.xlsx')

describe.skipIf(!existsSync(FIL))('parseSalesPerHourInneUte (ekte St1 0603-fil)', () => {
  // Lat lesing. describe.skipIf hopper over testene, men evaluerer
  // likevel kroppen for aa samle testnavn - saa en lesing her kaster
  // FOER skippingen slaar inn. Eksempelfilene ligger ikke i repoet
  // (ekte kundedata), og uten dette er CI rod paa noe som skal hoppes.
  let husket: ReturnType<typeof parseSalesPerHourInneUte> | null = null
  const resultat = () => (husket ??= parseSalesPerHourInneUte(readFileSync(FIL)))

  it('finner alle fem stasjonene (på navn), uten total-raden', async () => {
    const r = await resultat()
    expect(r.rapporttype).toBe('st1_salesperhour_inneute')
    expect(r.stasjoner.map((s) => s.navn).sort()).toEqual([
      'St1 Bønes', 'St1 Dale', 'St1 Laguneparken', 'St1 Lone', 'St1 Varden',
    ])
    expect(r.stasjoner.some((s) => /totalt/i.test(s.navn))).toBe(false)
  })

  it('leser 24 time-bøtter for Bønes', async () => {
    const r = await resultat()
    const b = r.stasjoner.find((s) => s.navn === 'St1 Bønes')!
    expect(b.timer).toHaveLength(24)
  })

  it('splitter inne-/utekunder pr time (Bønes)', async () => {
    const r = await resultat()
    const b = r.stasjoner.find((s) => s.navn === 'St1 Bønes')!

    const t01 = b.timer.find((t) => t.time === '0-1')!
    expect(t01.salg).toBeCloseTo(2999.07, 2)
    expect(t01.inneKunder).toBe(0) // butikk stengt om natten
    expect(t01.uteKunder).toBe(7) // pumpekunder
    expect(t01.antallKunder).toBe(7) // total = inne + ute

    const t67 = b.timer.find((t) => t.time === '6-7')!
    expect(t67.inneKunder).toBe(68)
    expect(t67.uteKunder).toBe(31)
    expect(t67.antallKunder).toBe(99)
  })
})
