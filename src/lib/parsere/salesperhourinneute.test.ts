import { describe, it, expect } from 'vitest'
import { kildeFor } from './fixtures/kilde'
import { lagSalesPerHourInneUte } from './fixtures/salesperhourinneute'
import { parseSalesPerHourInneUte } from './salesperhourinneute'

const kilde = kildeFor('Timesalgsrapport med inne- og utekunder 2026-06-10.xlsx', lagSalesPerHourInneUte)

describe(`parseSalesPerHourInneUte (St1 0603 - ${kilde.merke})`, () => {
  // SUITEN HOPPET OVER SEG SELV. `describe.skipIf(!existsSync(FIL))` mot
  // en fil i `eksempelfiler/`, som er gitignored - saa den kjorte aldri i
  // CI, og heller ikke lokalt, siden mappa er tom. Naa kjorer den mot den
  // ekte fila naar den ligger der, mot en arbeidsbok med samme form
  // ellers. Se `fixtures/LESMEG.md`.
  let husket: ReturnType<typeof parseSalesPerHourInneUte> | null = null
  const resultat = () => (husket ??= kilde.les().then(parseSalesPerHourInneUte))

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
