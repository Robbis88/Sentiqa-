import { describe, it, expect } from 'vitest'
import { kildeFor } from './fixtures/kilde'
import { lagRegnskap } from './fixtures/regnskap'
import { parseRegnskapStasjoner } from './regnskap'

const kilde = kildeFor('regnskap-kelsar-202604.xlsx', lagRegnskap)

describe(`parseRegnskapStasjoner (driftskostnader pr stasjon - ${kilde.merke})`, () => {
  it('henter per-stasjon kostnader fra Res-seksjonen', async () => {
    const stasjoner = await parseRegnskapStasjoner(await kilde.les())
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

  // Beviser at parseren faktisk SPOER kontoregisteret, ikke bare at
  // registeret virker isolert. `kontoregister.test.ts` felter oppslaget;
  // denne felter koblingen.
  it('navngir kostnadslinjene fra kontoregisteret, ikke fra koden', async () => {
    const stasjoner = await parseRegnskapStasjoner(await kilde.les())
    const kost = stasjoner
      .find((s) => s.butikknummer === '4177')!
      .linjer.filter((l) => l.seksjon === 'driftskostnader')

    expect(kost.find((l) => l.kode === '633')!.post).toBe('Forbruksmateriell')
    expect(kost.find((l) => l.kode === '634')!.post).toBe('Rep & vedlikehold')

    // KANARI: «Konto 633» var formen den gamle kodeoppslags-fallbacken
    // tok naar den ikke kjente koden. Dukker den opp igjen, er vi tilbake
    // til aa gjette ut fra tall alene.
    for (const l of kost) {
      expect(l.post, `kode ${l.kode}`).not.toMatch(/^Konto \d+$/)
    }
  })
})
