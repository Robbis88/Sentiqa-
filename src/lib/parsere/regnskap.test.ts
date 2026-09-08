import { describe, it, expect } from 'vitest'
import { kildeFor } from './fixtures/kilde'
import { lagRegnskap } from './fixtures/regnskap'
import { parseRegnskap, parseRegnskapStasjoner } from './regnskap'

const kilde = kildeFor('190 Kelsar Bil AS 202512-202512_3 (1).xlsx', lagRegnskap)

describe(`parseRegnskap (Azets Cluster-ark - ${kilde.merke})`, () => {
  // SUITEN HOPPET OVER SEG SELV mot en fil i `eksempelfiler/`, som er
  // gitignored - saa den kjorte aldri i CI, og heller ikke lokalt.
  // Se `fixtures/LESMEG.md`.
  let husket: ReturnType<typeof parseRegnskap> | null = null
  const resultat = () => (husket ??= kilde.les().then(parseRegnskap))

  it('leser retailernavn og periode fra «Denne periode» (ikke «Hittil i år»)', async () => {
    const r = await resultat()
    expect(r.retailerNavn).toContain('Kelsar Bil AS')
    // «Denne periode 01.12.2025» → 2025-12-01. (Hittil i år starter 01.01.2025,
    // som ville gitt 2025-01-01 hvis vi leste feil felt.)
    expect(r.periode).toBe('2025-12-01')
  })

  it('dekker alle fire seksjoner', async () => {
    const r = await resultat()
    const seksjoner = new Set(r.linjer.map((l) => l.seksjon))
    expect([...seksjoner].sort()).toEqual([
      'bruttofortjeneste', 'driftskostnader', 'omsetning', 'resultat',
    ])
  })

  it('leser en kjent omsetningslinje (120 Mat) med regnskap + budsjett', async () => {
    const r = await resultat()
    const mat = r.linjer.find((l) => l.seksjon === 'omsetning' && l.kode === '120')!
    expect(mat.post).toBe('120 Mat')
    expect(mat.regnskap).toBeCloseTo(1458573.9, 1)
    expect(mat.budsjett).toBeCloseTo(1633870.31, 1)
  })

  it('fanger omsetning totalt og resultat', async () => {
    const r = await resultat()
    const total = r.linjer.find((l) => /^omsetning totalt/i.test(l.post))
    expect(total?.regnskap).toBeCloseTo(5289620.3, 0)
    expect(r.linjer.some((l) => l.seksjon === 'resultat')).toBe(true)
  })
})

describe(`parseRegnskapStasjoner (per-stasjon-ark - ${kilde.merke})`, () => {
  // Lat, av samme grunn som over.
  let husketSt: ReturnType<typeof parseRegnskapStasjoner> | null = null
  const stasjoner = () => (husketSt ??= kilde.les().then(parseRegnskapStasjoner))

  it('finner per-stasjon-arkene inkl. de fem ekte stasjonene', async () => {
    const nr = (await stasjoner()).map((s) => s.butikknummer)
    for (const b of ['4177', '4185', '9038', '9145', '9467']) {
      expect(nr).toContain(b)
    }
  })

  it('leser avdelingsomsetning per stasjon (Lone 120 Mat)', async () => {
    const lone = (await stasjoner()).find((s) => s.butikknummer === '4177')!
    const mat = lone.linjer.find((l) => l.seksjon === 'omsetning' && l.kode === '120')!
    expect(mat.post).toBe('120 Mat')
    expect(mat.regnskap).toBeCloseTo(273865.21, 1)
    expect(mat.budsjett).toBeCloseTo(289180.63, 1)
  })

  it('summen av avdelingsomsetning per stasjon dobbelttelles ikke (ingen "totalt")', async () => {
    const lone = (await stasjoner()).find((s) => s.butikknummer === '4177')!
    expect(lone.linjer.some((l) => /totalt/i.test(l.post))).toBe(false)
  })
})
