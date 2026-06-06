import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseSalgsstatistikk } from './salgsstatistikk'

const FIL = join(process.cwd(), 'eksempelfiler', 'Salgsstatistikk 2026-05-01.xlsx')
const harFil = existsSync(FIL)

// Eksempelfilen er git-ignorert (ekte data). Kjør testen lokalt der filen
// finnes; hopp over ellers (f.eks. i CI uten fixturen).
describe.skipIf(!harFil)('parseSalgsstatistikk (ekte St1 0714-fil)', () => {
  const resultat = parseSalgsstatistikk(readFileSync(FIL))

  it('leser metadata: dato og moms-flagg', async () => {
    const r = await resultat
    expect(r.rapporttype).toBe('st1_salgsstatistikk')
    expect(r.dato).toBe('2026-04-30')
    expect(r.inkludererMoms).toBe(false)
  })

  it('splitter alle fem stasjonene på butikknummer', async () => {
    const r = await resultat
    expect(r.stasjoner.map((s) => s.butikknummer).sort()).toEqual([
      '4177', '4185', '9038', '9145', '9467',
    ])
    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')
    expect(lone?.navn).toBe('St1 Lone')
  })

  it('bygger drilldown-kontekst riktig på en kjent produktrad', async () => {
    const r = await resultat
    const lone = r.stasjoner.find((s) => s.butikknummer === '4177')!
    const bolle = lone.linjer.find((l) => l.ean === '3000') // HVETEBOLLE
    expect(bolle).toBeDefined()
    expect(bolle!.varenavn).toBe('HVETEBOLLE')
    expect(bolle!.avdelingKode).toBe('120')
    expect(bolle!.avdelingNavn).toBe('MAT')
    expect(bolle!.vareomradeKode).toBe('10')
    expect(bolle!.varegruppeKode).toBe('1201')
    expect(bolle!.antallTotalt).toBe(5)
    expect(bolle!.omsetningEksMva).toBeCloseTo(57.30434785, 4)
  })

  it('summerer til et fornuftig antall produktrader', async () => {
    const r = await resultat
    const sum = r.stasjoner.reduce((a, s) => a + s.linjer.length, 0)
    expect(sum).toBeGreaterThan(1000)
    // Ingen kontekst-/sumrader skal ha sneket seg inn som produkt
    for (const s of r.stasjoner) {
      for (const l of s.linjer) {
        expect(l.varenavn).not.toMatch(/^(Butikk|Avdeling|Vareområde|Varegruppe):/)
      }
    }
  })
})
