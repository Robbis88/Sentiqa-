import { describe, expect, test } from 'vitest'
import { LONNSKONTI, SYKEKONTI, kjedensSykesats } from './sykereserve'

describe('sykefraværsreserven', () => {
  test('samme sats uansett hvem som er syk', () => {
    // DEN VIKTIGSTE AV DISSE. Stasjon A har alt sykefraværet, B har
    // ingenting — og begge skal likevel få trukket kjedens snitt.
    //
    // Før dette var satsen `max(egen, snitt)`: A ble trukket 20 % og B
    // 10 %. A hadde da både færre hender på jobb OG mindre ramme å
    // planlegge med, mens forskjellen mellom dem ble utlignet i stedet
    // for å bli synlig.
    const rader = [
      { stasjon_id: 'A', kode: '503', regnskap: 500 },
      { stasjon_id: 'A', kode: '505', regnskap: 100 },
      { stasjon_id: 'B', kode: '503', regnskap: 500 },
    ]
    // 100 syk av 1000 lønn = 10 %, for begge.
    expect(kjedensSykesats(rader)).toBeCloseTo(10, 6)
  })

  test('uten lønn i grunnlaget tas ingen reserve', () => {
    // Ikke en standardsats, ikke et anslag: en reserve vi ikke har
    // grunnlag for å ta, tar vi ikke. En ny retailer uten regnskap skal
    // ikke få trukket et tall noen har funnet på.
    expect(kjedensSykesats([])).toBe(0)
    expect(kjedensSykesats([{ stasjon_id: 'A', kode: '505', regnskap: 100 }])).toBe(0)
  })

  test('null i regnskapet teller som null, ikke som manglende', () => {
    expect(kjedensSykesats([
      { stasjon_id: 'A', kode: '503', regnskap: 1000 },
      { stasjon_id: 'A', kode: '505', regnskap: null },
    ])).toBe(0)
  })

  test('bare sykekontiene teller som fravær', () => {
    // KANARIFUGL FOR KONTOLISTA. Havner en lønnskonto i SYKEKONTI, blir
    // reserven for stor og alle stasjoner får mindre å planlegge med —
    // uten at noe annet sier fra.
    expect(SYKEKONTI).toEqual(['505', '506'])
    expect(LONNSKONTI).toContain('503')
    for (const k of SYKEKONTI) {
      expect(LONNSKONTI, `${k} kan ikke være både lønn og sykefravær`)
        .not.toContain(k)
    }
  })

  test('satsen er andelen, ikke kronene', () => {
    expect(kjedensSykesats([
      { stasjon_id: 'A', kode: '501', regnskap: 800 },
      { stasjon_id: 'A', kode: '503', regnskap: 200 },
      { stasjon_id: 'A', kode: '506', regnskap: 25 },
    ])).toBeCloseTo(2.5, 6)
  })
})
