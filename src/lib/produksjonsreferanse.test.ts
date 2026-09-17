import { describe, expect, it } from 'vitest'
import { lagProduksjonsplan, leggTilDager, produksjonsdag, produksjonsreferanse, type SalgsPunkt } from './produksjonsplan'

const row = (dato: string, antall: number): SalgsPunkt => ({ dato, antall, varenavn: 'Bolle', varegruppeKode: '1216', varegruppeNavn: 'Bakst' })
const options = { maalDato: '2026-09-21', sisteSalgsdato: '2026-09-20', vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0 }

describe('produksjonsgrunnlaget', () => {
  it('dagsaggregerer samme varenavn før snitt og datadekning', () => {
    const split = lagProduksjonsplan({ ...options, salg: ['2026-09-07', '2026-09-14'].flatMap(d => [row(d, 10), row(d, 10)]) })
    const samlet = lagProduksjonsplan({ ...options, salg: ['2026-09-07', '2026-09-14'].map(d => row(d, 20)) })
    expect(split).toEqual(samlet)
    expect(split.forslag[0].foreslatt).toBe(20)
    expect(split.forslag[0].flagg).toContain('fa_data')
  })

  it('beholder hele 28-dagers referansen når siste import er syv dager bak', () => {
    const siste = leggTilDager(options.maalDato, -7)
    const salg = Array.from({ length: 28 }, (_, i) => [row(leggTilDager(siste, -i), 10), row(leggTilDager(siste, -i - 364), 10)]).flat()
    const referanse = produksjonsreferanse(options.maalDato, siste)
    const plan = lagProduksjonsplan({ ...options, sisteSalgsdato: siste, salg: salg.filter(p => p.dato >= referanse.fra && p.dato <= referanse.til) })
    expect(referanse.fra).toBe(leggTilDager(siste, -391))
    expect(plan.forslag[0].trendfaktor).toBe(1)
    expect(plan.forslag[0].foreslatt).toBe(10)
    // Kanarifugl: det gamle datovinduet skaper falsk vekst med samme fixture.
    const gammel = lagProduksjonsplan({ ...options, sisteSalgsdato: siste, salg: salg.filter(p => p.dato >= leggTilDager(options.maalDato, -392)) })
    expect(gammel.forslag[0].trendfaktor).toBe(1.27)
  })

  it('lar ikke salget på eller etter historisk måldag påvirke forslaget', () => {
    const salg = [row('2026-09-07', 10), row('2026-09-14', 10)]
    const forventet = lagProduksjonsplan({ ...options, salg })
    const medFremtid = lagProduksjonsplan({ ...options, sisteSalgsdato: '2026-10-20', salg: [...salg, row('2026-09-21', 500), row('2026-10-19', 999)] })
    expect(medFremtid).toEqual(forventet)
    expect(produksjonsreferanse(options.maalDato, '2026-10-20').til).toBe('2026-09-20')
  })

  it('bruker samme navngitte helligdag som felles salgs- og værreferanse', () => {
    const referanse = produksjonsreferanse('2026-04-02', '2026-04-01')
    expect(referanse.fjorDato).toBe('2025-04-17')
    const plan = lagProduksjonsplan({ ...options, maalDato: '2026-04-02', sisteSalgsdato: '2026-04-01', salg: [row('2025-04-17', 40), row('2025-04-03', 5), row('2026-03-26', 10)] })
    expect(plan.forslag[0].fjorMedian).toBe(40)
    expect(produksjonsreferanse('2026-05-17', '2026-05-16').fjorDato).toBe('2025-05-17')
  })

  it('velger morgendagen i Oslo rundt midnatt og sommertid', () => {
    expect(produksjonsdag(undefined, new Date('2026-09-17T22:30:00Z'))).toBe('2026-09-19')
    expect(produksjonsdag(undefined, new Date('2026-01-17T23:30:00Z'))).toBe('2026-01-19')
    expect(produksjonsdag(undefined, new Date('2026-03-28T23:30:00Z'))).toBe('2026-03-30')
    expect(produksjonsdag('2026-02-28')).toBe('2026-02-28')
    expect(() => produksjonsdag('2026-02-30')).toThrow('ugyldig')
  })

  it('avviser ukjent salgsantall fremfor et troverdig nullforslag', () => {
    expect(() => lagProduksjonsplan({ ...options, salg: [row('2026-09-14', NaN)] })).toThrow('ukjent')
  })
})
