import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, it, expect } from 'vitest'
import { parseRegnskapStasjoner } from './regnskap'

const FIL = join(process.cwd(), 'eksempelfiler', 'regnskap-kelsar-202604.xlsx')

describe.skipIf(!existsSync(FIL))('parseRegnskapStasjoner (driftskostnader pr stasjon)', () => {
  it('henter per-stasjon kostnader fra Res-seksjonen', async () => {
    const stasjoner = await parseRegnskapStasjoner(readFileSync(FIL))
    const lone = stasjoner.find((s) => s.butikknummer === '4177')
    expect(lone).toBeDefined()
    const kost = lone!.linjer.filter((l) => l.seksjon === 'driftskostnader')
    expect(kost.length).toBeGreaterThan(5)
    const forbruk = kost.find((l) => l.kode === '633')
    expect(forbruk).toBeDefined()
    expect(forbruk!.regnskap).toBeGreaterThan(6000)
    expect(forbruk!.regnskap).toBeLessThan(7000)
    expect(forbruk!.budsjett).toBeGreaterThan(7000)
  })
})
