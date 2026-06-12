import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, it, expect } from 'vitest'
import { parseUsynligSvinn } from './usynligsvinn'

const FIL = join(process.cwd(), 'eksempelfiler', 'regnskap-kelsar-202604.xlsx')

describe.skipIf(!existsSync(FIL))('parseUsynligSvinn (ekte regnskapsfil)', () => {
  it('finner usynlig svinn pr stasjon med riktig fortegn', async () => {
    const r = await parseUsynligSvinn(readFileSync(FIL))
    expect(r.rapporttype).toBe('usynlig_svinn')
    // 5 driftsstasjoner (9900 Admin har ingen produktsalg)
    expect(r.stasjoner.length).toBeGreaterThanOrEqual(5)

    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')
    expect(lone).toBeDefined()
    // KAFFE skal vise manko (positivt) på Lone
    const kaffe = lone!.produkter.find((p) => /KAFFE$/.test(p.navn) || p.navn.includes('13010'))
    expect(kaffe).toBeDefined()
    expect(kaffe!.usynligKr).toBeGreaterThan(10000)
    // total manko skal være positiv
    expect(lone!.totalManko).toBeGreaterThan(0)
  })
})
