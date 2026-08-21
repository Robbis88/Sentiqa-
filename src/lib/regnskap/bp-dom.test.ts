import { describe, expect, test } from 'vitest'
import { alvor, delEtterKobling, domsord, sorterEtterAvvik, sumBakPlan, gapAlvor } from './bp-dom'
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

  test('det som ikke kan maales blir en fotnote, ikke en utelatelse', () => {
    const rader = [
      { kobling: 'plan_med_salg', bp_omsetning_kr: 500000, faktisk_omsetning: 380000 },
      { kobling: 'plan_uten_salg', bp_omsetning_kr: 30000, faktisk_omsetning: null },
      { kobling: 'plan_uten_kobling', bp_omsetning_kr: 7196, faktisk_omsetning: null },
      { kobling: 'salg_uten_plan', bp_omsetning_kr: null, faktisk_omsetning: 146 },
    ]
    const d = delEtterKobling(rader)

    // `plan_uten_salg` SKAL VAERE MED. Den har en plan, den er kjent i
    // salgsdataene, og null omsetning er et svar - ikke et hull. Faller
    // den ut her, forsvinner en avdeling som faktisk ligger 30 000 bak.
    expect(d.maalbare.map((r) => r.kobling))
      .toEqual(['plan_med_salg', 'plan_uten_salg'])

    // Tallene er de ekte fra produksjon 2026-08-21.
    expect(d.umaaltBudsjett, '211 Selvvask').toBe(7196)
    expect(d.salgUtenPlan, 'DRIFT + SYSTEM').toBe(146)
  })

  test('fotnoten teller ikke budsjett to ganger', () => {
    // `salg_uten_plan` har per definisjon intet budsjett. Blir den
    // likevel talt med, sier fotnoten at penger ikke maales som aldri
    // var planlagt - og da vokser tallet av seg selv.
    const d = delEtterKobling([
      { kobling: 'salg_uten_plan', bp_omsetning_kr: 99999, faktisk_omsetning: 146 },
    ])
    expect(d.salgUtenPlan).toBe(146)
    expect(d.umaalte).toHaveLength(1)
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
