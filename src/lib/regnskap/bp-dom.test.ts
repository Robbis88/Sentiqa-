import { describe, expect, test } from 'vitest'
import { alvor, domsord, sorterEtterAvvik, sumBakPlan, gapAlvor } from './bp-dom'
import { TERSKLER } from './terskler'

describe('dommen om en avdeling', () => {
  test('grensene er de samme som regnskapsvarslene bruker', () => {
    // KANARIFUGL FOR TO SANNHETER. Endrer noen terskelen i
    // regnskap-varsler.ts uten aa endre den her, ser butikksjefen gult
    // paa /regnskap og gronn paa /businessplan for det SAMME tallet - og
    // da slutter hun aa tro paa begge.
    expect(alvor(TERSKLER.omsRod), `${TERSKLER.omsRod} % skal kreve handling`).toBe('handling')
    expect(alvor(TERSKLER.omsGul), `${TERSKLER.omsGul} % skal vaere en endring`).toBe('endring')
  })

  test('alvoret foelger avviket, ikke stoerrelsen', () => {
    expect(alvor(-12)).toBe('handling')
    expect(alvor(-10)).toBe('handling')
    expect(alvor(-9.9)).toBe('endring')
    expect(alvor(-3)).toBe('endring')
    expect(alvor(-2.9)).toBe('normal')
    expect(alvor(0)).toBe('normal')
    expect(alvor(15)).toBe('normal')
    expect(alvor(null)).toBe('normal')
  })

  test('retningen staar i ORD, ikke i et fortegn', () => {
    // Den som skanner en liste skal lese retningen uten aa tolke et
    // symbol - og uten aa se farge.
    expect(domsord(-28400)).toBe('bak plan')
    expect(domsord(12100)).toBe('foran plan')
    expect(domsord(0)).toBe('foran plan')
  })

  test('det som mangler mest staar oeverst', () => {
    const rader = [
      { navn: 'Tobakk', mot_bp_kr: 19500 },
      { navn: 'Mat', mot_bp_kr: -28400 },
      { navn: 'Bil', mot_bp_kr: -3100 },
      { navn: 'Kald drikke', mot_bp_kr: null },
    ]
    expect(sorterEtterAvvik(rader).map((r) => r.navn))
      .toEqual(['Mat', 'Bil', 'Kald drikke', 'Tobakk'])
  })

  test('en avdeling som gaar bra skjuler ikke en som gaar daarlig', () => {
    // DEN VIKTIGSTE AV DISSE. Nettosummen ville sagt «vi er i rute»
    // fordi Tobakk gaar bra - mens Mat mangler 28 400. Bare de negative
    // telles, saa overskudd ett sted ikke betaler for underskudd et annet.
    const rader = [
      { mot_bp_kr: -28400 },
      { mot_bp_kr: 40000 },
      { mot_bp_kr: -3100 },
    ]
    expect(sumBakPlan(rader), 'nettosummen ville vaert +8500').toBe(-31500)
  })

  test('gapet: tideler er stoy, prosentpoeng er penger', () => {
    expect(gapAlvor(5.2)).toBe('handling')
    expect(gapAlvor(3)).toBe('handling')
    expect(gapAlvor(2.9)).toBe('endring')
    expect(gapAlvor(1)).toBe('endring')
    expect(gapAlvor(0.9)).toBe('normal')
    expect(gapAlvor(-1)).toBe('normal')
    expect(gapAlvor(null)).toBe('normal')
  })
})
