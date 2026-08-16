import { describe, expect, test } from 'vitest'
import { byggVismafil, medBom, vismaFilnavn } from './vismafil'
import { LONNSART } from './tidsband'

describe('byggVismafil', () => {
  const linjer = [
    { ansattNr: '1009', lonnsart: LONNSART.timelonn, antall: 9 },
    { ansattNr: '1009', lonnsart: LONNSART.lordag, antall: 5.98 },
  ]

  test('treffer formatet byte for byte', () => {
    // Fasit hentet fra fila easy@work leverer til Azets i dag.
    expect(byggVismafil(linjer, '9467').split('\r\n')[0])
      .toBe('0;0;1009;2;0;9.00;0;0;0;0;"9467";" ";" ";" ";" ";" ";0')
  })

  test('sytten felt, verken flere eller færre', () => {
    for (const rad of byggVismafil(linjer, '9467').trim().split('\r\n')) {
      expect(rad.split(';')).toHaveLength(17)
    }
  })

  test('felt 12–16 er sitert MELLOMROM, ikke tomt', () => {
    const f = byggVismafil(linjer, '9467').split('\r\n')[0].split(';')
    for (let i = 11; i <= 15; i++) expect(f[i], `felt ${i + 1}`).toBe('" "')
    expect(f[16]).toBe('0')
  })

  test('antall har alltid to desimaler og PUNKTUM', () => {
    const f = byggVismafil(linjer, '9467').split('\r\n')[1].split(';')
    expect(f[5]).toBe('5.98')
    expect(byggVismafil([{ ansattNr: '1', lonnsart: '2', antall: 9 }], '1')
      .split(';')[5]).toBe('9.00')
  })

  test('CRLF på hver linje, også den siste', () => {
    const s = byggVismafil(linjer, '9467')
    expect(s.endsWith('\r\n')).toBe(true)
    expect(s.split('\r\n').filter(Boolean)).toHaveLength(2)
  })

  test('kostnadsstedet er sitert', () => {
    expect(byggVismafil(linjer, '4185')).toContain('"4185"')
  })
})

describe('medBom', () => {
  test('BOM først, deretter innholdet', () => {
    const b = medBom('abc')
    expect([...b.slice(0, 3)]).toEqual([0xef, 0xbb, 0xbf])
    expect(new TextDecoder().decode(b.slice(3))).toBe('abc')
  })
})

describe('vismaFilnavn', () => {
  test('stasjon og periode står i navnet', () => {
    expect(vismaFilnavn('9467', 2026, 5)).toBe('lonn_9467_2026-05.csv')
  })
})
