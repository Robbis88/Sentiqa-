import { describe, expect, it } from 'vitest'
import { signerPrognose, lesPrognose, erTreffoppfolging } from './prognosereferanse'

const ref = { vare: '5000112636833', stasjoner: ['4185'], fra: '2026-09-18', til: '2026-09-18' }
describe('siste leverte prognose følger samtalen som signert referanse', () => {
  it('bevarer vare og stasjon uten å lagre tall', () => {
    expect(lesPrognose(signerPrognose(ref, 'dale', 'hemmelig'), 'dale', 'hemmelig')).toEqual(ref)
  })
  it('godtar verken annen bruker eller endret vare', () => {
    const token = signerPrognose(ref, 'dale', 'hemmelig')
    expect(lesPrognose(token, 'bones', 'hemmelig')).toBeNull()
    expect(lesPrognose(token, 'dale', 'annen-noekkel')).toBeNull()
    const [body, sig] = token.split('.')
    const endret = JSON.parse(Buffer.from(body, 'base64url').toString())
    endret.ref.vare = 'zero'
    expect(lesPrognose(`${Buffer.from(JSON.stringify(endret)).toString('base64url')}.${sig}`, 'dale', 'hemmelig')).toBeNull()
  })
  it('gjenkjenner den rapporterte oppfølgingen', () => {
    expect(erTreffoppfolging('hvor sikker er du på tallet?')).toBe(true)
    expect(erTreffoppfolging('jeg mener Zero')).toBe(false)
    expect(lesPrognose(undefined, 'dale', 'hemmelig')).toBeNull()
  })
})
