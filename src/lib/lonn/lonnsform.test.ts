import { describe, expect, test } from 'vitest'
import { delEtterLonnsform, type Lonnsform } from './lonnsform'
import { LONNSART } from './tidsband'

const T = LONNSART.timelonn

const l = (ansattNr: string, lonnsart: string, antall: number) =>
  ({ ansattNr, lonnsart, antall })

const kart = (o: Record<string, Lonnsform | null>) =>
  new Map<string, Lonnsform | null>(Object.entries(o))

describe('delEtterLonnsform', () => {
  test('bare timelønnede kommer med i fila', () => {
    const f = delEtterLonnsform(
      [l('1001', T, 150), l('1002', T, 160), l('1003', T, 40)],
      kart({ 1001: 'timelonn', 1002: 'fastlonn', 1003: 'tilkalling' }),
      T,
    )
    expect(f.med.map((x) => x.ansattNr)).toEqual(['1001'])
    expect(f.utelatt.map((x) => x.ansattNr)).toEqual(['1002', '1003'])
    expect(f.uavklart).toEqual([])
  })

  test('ukjent lønnsform er et spørsmål, ikke «ta med»', () => {
    const f = delEtterLonnsform([l('1001', T, 150)], kart({}), T)
    expect(f.med).toEqual([])
    expect(f.uavklart).toEqual([{ ansattNr: '1001', timer: 150 }])
  })

  test('tilleggene følger personen, ikke linjen', () => {
    // Fastlønnede skal ikke ha tilleggslinjer heller. Slipper én av dem
    // gjennom, får butikksjefen helligdagsgodtgjørelse i en fil der han
    // ellers ikke finnes — og da spør Azets hvem det er.
    const f = delEtterLonnsform(
      [l('1002', T, 160), l('1002', LONNSART.helligdag, 8), l('1001', T, 100)],
      kart({ 1001: 'timelonn', 1002: 'fastlonn' }),
      T,
    )
    expect(f.med).toHaveLength(1)
    expect(f.med[0].ansattNr).toBe('1001')
  })

  test('timene telles på timelønn alene — tillegg ligger oppå de samme timene', () => {
    const f = delEtterLonnsform(
      [l('1002', T, 160), l('1002', LONNSART.lordag, 12), l('1002', LONNSART.sondag0618, 6)],
      kart({ 1002: 'fastlonn' }),
      T,
    )
    // 160, ikke 178. En lørdagsvakt er ikke to vakter.
    expect(f.utelatt).toEqual([{ ansattNr: '1002', lonnsform: 'fastlonn', timer: 160 }])
  })

  test('en person står én gang i lista, uansett hvor mange linjer hun har', () => {
    const f = delEtterLonnsform(
      [l('1003', T, 40), l('1003', LONNSART.hverdag1821, 9), l('1003', LONNSART.lordag, 4)],
      kart({ 1003: null }),
      T,
    )
    expect(f.uavklart).toHaveLength(1)
  })

  test('de med flest timer står øverst — det er der feilen koster mest', () => {
    const f = delEtterLonnsform(
      [l('a', T, 12), l('b', T, 160), l('c', T, 80)],
      kart({ a: null, b: null, c: null }),
      T,
    )
    expect(f.uavklart.map((x) => x.ansattNr)).toEqual(['b', 'c', 'a'])
  })

  test('Bønes mai: 27 % av timene forsvinner, og det er riktig', () => {
    // Den ekte avstemmingen. easy@works fil manglet 191,68 av 713 timer,
    // og de to som manglet var butikksjefen og Carmen.
    const f = delEtterLonnsform(
      [l('1058', T, 158), l('9001', T, 33.68), l('1010', T, 521.32)],
      kart({ 1058: 'fastlonn', 9001: 'tilkalling', 1010: 'timelonn' }),
      T,
    )
    const utenfor = f.utelatt.reduce((s, x) => s + x.timer, 0)
    expect(utenfor).toBeCloseTo(191.68, 2)
    expect(f.uavklart).toEqual([])
  })
})
