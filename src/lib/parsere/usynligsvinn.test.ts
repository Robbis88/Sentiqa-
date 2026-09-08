import { describe, it, expect } from 'vitest'
import { kildeFor } from './fixtures/kilde'
import { lagRegnskap } from './fixtures/regnskap'
import { parseUsynligSvinn } from './usynligsvinn'

const kilde = kildeFor('regnskap-kelsar-202604.xlsx', lagRegnskap)

describe(`parseUsynligSvinn (${kilde.merke})`, () => {
  it('finner usynlig svinn pr stasjon med riktig fortegn', async () => {
    const r = await parseUsynligSvinn(await kilde.les())
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
