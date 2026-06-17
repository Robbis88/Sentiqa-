import { describe, it, expect } from 'vitest'
import { finnUtsolgt, type Kandidatrad } from './utsolgt'
import { leggTilDager } from './produksjonsplan'

const IDAG = '2026-06-16'
const VINDU = 10

// Hjelper: bygg en jevn selger over vinduet, med valgfrie 0-dager (utelatt rad).
function serie(ean: string, navn: string, perDag: number, hull: number[]): Kandidatrad[] {
  const rader: Kandidatrad[] = []
  for (let i = VINDU; i >= 1; i--) {
    if (hull.includes(i)) continue // ingen rad = 0 salg den dagen
    rader.push({ ean, varenavn: navn, dato: leggTilDager(IDAG, -i), antall: perDag, omsetning: perDag * 20 })
  }
  return rader
}

describe('finnUtsolgt', () => {
  it('flagger et 0-hull på 3 dager omkranset av normalt salg', () => {
    // Cola selger 5/dag, men dag -6,-5,-4 (midt i vinduet) er 0.
    const h = finnUtsolgt(serie('X', 'Cola 0,5l', 5, [6, 5, 4]), IDAG, VINDU)
    expect(h).toHaveLength(1)
    expect(h[0].dager).toBe(3)
    expect(h[0].snitt).toBe(5)
    expect(h[0].tapt_kr).toBe(5 * 3 * 20) // normal × dager × enhetspris
  })

  it('flagger IKKE et hull på bare 1 dag', () => {
    const h = finnUtsolgt(serie('X', 'Pepsi', 4, [5]), IDAG, VINDU)
    expect(h).toHaveLength(0)
  })

  it('flagger IKKE hull i kanten av vinduet (mangler salg etterpå)', () => {
    // 0 de to siste dagene (-2,-1) → ingen «tilbake på normalen» å bekrefte mot.
    const h = finnUtsolgt(serie('X', 'Farris', 6, [2, 1]), IDAG, VINDU)
    expect(h).toHaveLength(0)
  })

  it('flagger IKKE når salget før hullet var langt under normalen', () => {
    // Varen tapret ut (selger 5, men dag -7 er 1 = under 60 % av normal) før 0-hullet.
    const rader = serie('X', 'Sesongvare', 5, [6, 5])
    const dagSyv = rader.find((r) => r.dato === leggTilDager(IDAG, -7))!
    dagSyv.antall = 1 // svak dag rett før hullet
    const h = finnUtsolgt(rader, IDAG, VINDU)
    expect(h).toHaveLength(0)
  })

  it('skiller to varer fra hverandre', () => {
    const rader = [...serie('X', 'Cola', 5, [6, 5, 4]), ...serie('Y', 'Pepsi', 5, [6, 5, 4])]
    const h = finnUtsolgt(rader, IDAG, VINDU)
    expect(h).toHaveLength(2)
    expect(new Set(h.map((x) => x.ean))).toEqual(new Set(['X', 'Y']))
  })
})
