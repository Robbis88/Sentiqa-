import { describe, expect, test } from 'vitest'
import { lagStasjonsmatcher } from './stasjonsmatch'

const S = (...navn: string[]) => navn.map((n, i) => ({ id: `id${i}`, navn: n }))

describe('stasjonsmatch', () => {
  test('samme navn med og uten kjedeprefiks', () => {
    for (const variant of ['Bønes', 'St1 Bønes', 'ST1 - Bønes', 'bønes']) {
      const m = lagStasjonsmatcher(S(variant, 'Laguneparken'))
      expect(m('St1 - Bønes'), variant).toBe('id0')
    }
  })

  test('butikknummer i navnet hindrer ikke treff', () => {
    const m = lagStasjonsmatcher(S('Bønes (0084)', 'Laguneparken (0085)'))
    expect(m('St1 - Bønes')).toBe('id0')
    expect(m('St1 - Laguneparken')).toBe('id1')
  })

  test('en stasjon som ikke finnes gir ingen match', () => {
    const m = lagStasjonsmatcher(S('Bønes', 'Laguneparken'))
    expect(m('St1 - Sandsli')).toBeUndefined()
  })

  test('tvetydig delvis treff matcher ikke — heller umatchet enn feil stasjon', () => {
    // «Bønes» finnes ikke, men to stasjoner inneholder ordet. Da skal
    // 2214 timer IKKE havne på en av dem etter myntkast.
    const m = lagStasjonsmatcher(S('Bønes Vest', 'Bønes Øst'))
    expect(m('St1 - Bønes')).toBeUndefined()
  })

  test('eksakt treff vinner over et delvis', () => {
    const m = lagStasjonsmatcher(S('Bønes', 'Bønes Vest'))
    expect(m('St1 - Bønes')).toBe('id0')
  })

  test('en stasjon som bare heter St1 sluker ikke alt', () => {
    const m = lagStasjonsmatcher(S('St1', 'Laguneparken'))
    expect(m('St1 - Laguneparken')).toBe('id1')
  })

  test('tom lokasjon matcher ingenting', () => {
    expect(lagStasjonsmatcher(S('Bønes'))('')).toBeUndefined()
    expect(lagStasjonsmatcher(S('Bønes'))('   ')).toBeUndefined()
  })

  test('for korte navn matcher ikke delvis', () => {
    const m = lagStasjonsmatcher(S('Ås'))
    expect(m('St1 - Åsane')).toBeUndefined()
  })
})
