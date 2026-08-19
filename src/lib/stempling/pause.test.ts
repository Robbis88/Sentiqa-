import { describe, it, expect } from 'vitest'
import {
  tellbareMinutter, pausetrekk, PAUSE_TERSKEL_MIN, PAUSE_MIN,
} from './pause'

const BETALT = { betalt: true }
const UBETALT = { betalt: false }

describe('tellbareMinutter', () => {
  it('teller hele vakta når pausen er betalt', () => {
    expect(tellbareMinutter(600, BETALT)).toBe(600)
  })

  it('teller hele vakta når den er kortere enn terskelen', () => {
    expect(tellbareMinutter(240, UBETALT)).toBe(240)
  })

  it('teller hele vakta akkurat på terskelen', () => {
    expect(tellbareMinutter(PAUSE_TERSKEL_MIN, UBETALT)).toBe(PAUSE_TERSKEL_MIN)
  })

  it('trekker pausen fra en lang vakt', () => {
    expect(tellbareMinutter(480, UBETALT)).toBe(480 - PAUSE_MIN)
  })

  // Et kvarters ekstra arbeid skal ikke gi tjue minutter mindre betalt.
  // Det er et tall ingen kan forklare til den det gjelder.
  it('gjør aldri en vakt kortere enn terskelen', () => {
    expect(tellbareMinutter(PAUSE_TERSKEL_MIN + 10, UBETALT)).toBe(PAUSE_TERSKEL_MIN)
  })

  it('er monotont — mer arbeid gir aldri mindre betalt', () => {
    let forrige = 0
    for (let m = 0; m <= 900; m += 5) {
      const naa = tellbareMinutter(m, UBETALT)
      expect(naa).toBeGreaterThanOrEqual(forrige)
      forrige = naa
    }
  })

  it('gir aldri mer enn vakta varte', () => {
    for (const m of [0, 60, 330, 331, 480, 900]) {
      expect(tellbareMinutter(m, UBETALT)).toBeLessThanOrEqual(m)
      expect(tellbareMinutter(m, BETALT)).toBeLessThanOrEqual(m)
    }
  })
})

describe('pausetrekk', () => {
  it('er null når pausen er betalt', () => {
    expect(pausetrekk(600, BETALT)).toBe(0)
  })

  it('er hele pausen på en lang vakt', () => {
    expect(pausetrekk(600, UBETALT)).toBe(PAUSE_MIN)
  })

  it('er null på en kort vakt', () => {
    expect(pausetrekk(200, UBETALT)).toBe(0)
  })
})
