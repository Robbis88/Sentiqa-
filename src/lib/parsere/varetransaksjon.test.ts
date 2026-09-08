import { describe, it, expect } from 'vitest'
import { parseVaretransaksjon } from './varetransaksjon'
import { kildeFor } from './fixtures/kilde'
import { lagVaretransaksjon } from './fixtures/varetransaksjon'

// =====================================================================
// DENNE SUITEN HOPPET OVER SEG SELV
//
// Den sto med `describe.skipIf(!existsSync(FIL))` mot en fil i
// `eksempelfiler/` — som er gitignored. I CI kjørte den aldri, og
// lokalt heller ikke, siden mappa er tom. Tre påstander som så grønne ut
// uten å måle noe.
//
// Nå kjører den alltid: mot den ekte fila når den ligger der, mot en
// arbeidsbok med samme form ellers. Suitenavnet sier hvilken.
// Se `fixtures/LESMEG.md` for hva de to kildene kan og ikke kan bevise.
// =====================================================================

const kilde = kildeFor('Varetransaksjonsliste 2026-05-13.xlsx', lagVaretransaksjon)

describe(`parseVaretransaksjon (St1 0452 — ${kilde.merke})`, () => {
  // Lat lesing: arbeidsboka bygges én gang, og bare hvis suiten kjører.
  let husket: ReturnType<typeof parseVaretransaksjon> | null = null
  const resultat = () => (husket ??= kilde.les().then(parseVaretransaksjon))

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

  it('leser "unknown" varenummer som ingenting', async () => {
    // St1 skriver bokstavelig «unknown» når varen ikke er i registeret.
    // Lagres den som tekst, får vi et varenummer som ser ekte ut.
    const r = await resultat()
    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')!
    expect(lone.transaksjoner.some((t) => t.varenummer === 'unknown')).toBe(false)
  })

  it('tåler begge butikkformatene St1 bruker', async () => {
    // «St1 Lone (4177)» og «9145 - St1 Dale» står om hverandre i samme
    // fil. Begge må gi butikknummeret.
    const r = await resultat()
    expect(r.stasjoner.map((s) => s.butikknummer)).toContain('9145')
  })
})
