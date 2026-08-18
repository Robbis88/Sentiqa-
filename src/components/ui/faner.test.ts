import { describe, expect, test } from 'vitest'
import { aktivFane } from './faner'

// Fanene for rutiner er det ekte tilfellet: /rutiner er prefiks av alle
// de tre andre, og en naiv startsWith ville markert to samtidig.
const RUTINER = ['/rutiner', '/rutiner/min', '/rutiner/oversikt', '/rutiner/oppsett']

describe('aktivFane', () => {
  test('lengste treff vinner — ikke det første', () => {
    expect(aktivFane(RUTINER, '/rutiner/oppsett')).toBe('/rutiner/oppsett')
    expect(aktivFane(RUTINER, '/rutiner/oversikt')).toBe('/rutiner/oversikt')
  })

  test('foreldrefanen er aktiv på sin egen sti', () => {
    expect(aktivFane(RUTINER, '/rutiner')).toBe('/rutiner')
  })

  test('en dypere side markerer fanen den hører under', () => {
    // /rutiner/oppsett/[id] har ingen egen fane, men hører til oppsett.
    expect(aktivFane(RUTINER, '/rutiner/oppsett/abc-123')).toBe('/rutiner/oppsett')
  })

  test('ingen fane er aktiv utenfor området', () => {
    expect(aktivFane(RUTINER, '/lonn')).toBeNull()
  })

  test('en sti som bare LIGNER treffer ikke', () => {
    // «/rutinerx» starter med «/rutiner», men er en annen side.
    expect(aktivFane(RUTINER, '/rutinerx')).toBeNull()
  })

  test('tom sti gir ingen aktiv fane framfor å gjette', () => {
    expect(aktivFane(RUTINER, '')).toBeNull()
  })
})
