import { describe, expect, test } from 'vitest'
import { finnOvertid, mandagen, heleUkerRundt, TIMER_PER_DAG } from './overtid'
import { TIMER_PER_UKE, type Skiftordning } from './tariff'

// =====================================================================
// DETEKTOREN MAA FINNE DET SOM FAKTISK STO DER
//
// Maalingen 2026-08-27 gjennom produksjonsfunksjonene: fire dager ga
// 59,50 ordinaere timer i loennsfila uten at noe reagerte. Det er den
// vakta denne modulen finnes for, og den staar som foerste test.
//
// Ingen av disse testene sier noe om hva overtid KOSTER. Satsen staar i
// Energiavtalen, ikke i koden.
// =====================================================================

const v = (ansattNr: string, dato: string, timer: number) =>
  ({ ansattNr, dato, minutter: timer * 60 })

const ordinaer = () => 'ordinaer' as Skiftordning
const ukjent = () => null

describe('finnOvertid', () => {
  test('KANARIFUGL: de fire dagene som ga 59,50 ordinaere timer', () => {
    // Uka gaar mandag 2026-08-03 til soendag 2026-08-09.
    const linjer = [
      v('101', '2026-08-03', 15),
      v('101', '2026-08-04', 15),
      v('101', '2026-08-05', 15),
      v('101', '2026-08-06', 14.5),
    ]
    const funn = finnOvertid(linjer, ordinaer)

    // Fire dagsfunn og ett ukesfunn. Foer denne modulen: null.
    expect(funn.filter((f) => f.slag === 'dag')).toHaveLength(4)
    const uke = funn.find((f) => f.slag === 'uke')
    expect(uke, 'ukesfunnet mangler').toBeDefined()
    expect(uke!.timer).toBe(59.5)
    expect(uke!.grense).toBe(37.5)
    expect(uke!.over).toBe(22)
    expect(uke!.noekkel).toBe('2026-08-03')
  })

  test('en vanlig uke gir ingen funn', () => {
    // Ellers ville hver eneste maaned hatt et varsel, og da leses det ikke.
    const linjer = [
      v('101', '2026-08-03', 7.5), v('101', '2026-08-04', 7.5),
      v('101', '2026-08-05', 7.5), v('101', '2026-08-06', 7.5),
      v('101', '2026-08-07', 7.5),
    ]
    expect(finnOvertid(linjer, ordinaer)).toEqual([])
  })

  test('KANARIFUGL: grensen er ikke inklusiv - noeyaktig 9 t og 37,5 t er greit', () => {
    // Bommer en `<=` mot `<`, varsler systemet om en helt vanlig full uke.
    const linjer = [
      v('101', '2026-08-03', 9), v('101', '2026-08-04', 9),
      v('101', '2026-08-05', 9), v('101', '2026-08-06', 9),
      v('101', '2026-08-07', 1.5),
    ]
    expect(finnOvertid(linjer, ordinaer)).toEqual([])
  })

  test('to skift har lavere ukegrense, og den brukes', () => {
    const linjer = [v('101', '2026-08-03', 8), v('101', '2026-08-04', 8),
      v('101', '2026-08-05', 8), v('101', '2026-08-06', 8), v('101', '2026-08-07', 4)]
    // 36 t: over 35,5 (to skift), under 37,5 (ordinaer).
    expect(finnOvertid(linjer, () => 'to_skift')).toHaveLength(1)
    expect(finnOvertid(linjer, ordinaer)).toEqual([])
  })

  test('ukjent skiftordning antas ordinaer, og det MERKES', () => {
    // Antakelsen kan skjule timer (to skift har lavere grense), aldri
    // finne opp noen. Merkelappen er der for at den som leser skal se det.
    const linjer = [v('101', '2026-08-03', 12), v('101', '2026-08-04', 12),
      v('101', '2026-08-05', 12), v('101', '2026-08-06', 12)]
    const uke = finnOvertid(linjer, ukjent).find((f) => f.slag === 'uke')!
    expect(uke.grense).toBe(TIMER_PER_UKE.ordinaer)
    expect(uke.antattOrdinaer).toBe(true)
    // Og satt ordning skal IKKE ha merkelappen - ellers betyr den ingenting.
    expect(finnOvertid(linjer, ordinaer).find((f) => f.slag === 'uke')!.antattOrdinaer)
      .toBeUndefined()
  })

  test('to ansatte blandes ikke', () => {
    const linjer = [
      v('101', '2026-08-03', 12), v('102', '2026-08-03', 8),
      v('101', '2026-08-04', 12), v('102', '2026-08-04', 8),
    ]
    const dager = finnOvertid(linjer, ordinaer).filter((f) => f.slag === 'dag')
    expect(dager.map((f) => f.ansattNr)).toEqual(['101', '101'])
  })

  test('to vakter samme dag summeres foer de maales', () => {
    // Delt vakt: 5 + 5 timer er ti timer paa en dag, ikke to korte dager.
    const funn = finnOvertid(
      [v('101', '2026-08-03', 5), v('101', '2026-08-03', 5)], ordinaer)
    expect(funn.filter((f) => f.slag === 'dag')).toHaveLength(1)
    expect(funn.find((f) => f.slag === 'dag')!.timer).toBe(10)
  })

  test('soendag hoerer til uka som startet mandagen foer', () => {
    // Klassisk av-for-en: `getUTCDay()` gir 0 for soendag, og en naiv
    // `dag - 1` ville flyttet den til neste uke og delt uka i to.
    expect(mandagen('2026-08-09')).toBe('2026-08-03') // soendag
    expect(mandagen('2026-08-03')).toBe('2026-08-03') // mandagen selv
    expect(mandagen('2026-08-04')).toBe('2026-08-03')
  })

  test('verste funn foerst', () => {
    const linjer = [v('101', '2026-08-03', 10), v('102', '2026-08-04', 14)]
    expect(finnOvertid(linjer, ordinaer)[0].ansattNr).toBe('102')
  })

  test('null minutter teller ikke som en dag', () => {
    expect(finnOvertid([v('101', '2026-08-03', 0)], ordinaer)).toEqual([])
  })

  test('KANARIFUGL: grensene er de fra tariff.ts og loven, ikke egne tall', () => {
    // Skrives de av her, kan de skli fra `tariff.ts` uten at noe sier fra.
    expect(TIMER_PER_DAG).toBe(9)
    expect(TIMER_PER_UKE.ordinaer).toBe(37.5)
    expect(TIMER_PER_UKE.to_skift).toBe(35.5)
  })
})

describe('heleUkerRundt', () => {
  test('vinduet starter paa en mandag og slutter paa en soendag', () => {
    // En uke som krysser maanedsskiftet maa telles hel, ellers UTEBLIR
    // et funn som burde vaert der - feilen gaar i farlig retning.
    const { fra, til } = heleUkerRundt(2026, 8)
    expect(mandagen(fra)).toBe(fra)
    expect(new Date(`${til}T00:00:00Z`).getUTCDay()).toBe(0)
    expect(fra <= '2026-08-01').toBe(true)
    expect(til >= '2026-08-31').toBe(true)
  })

  test('dekker hele maaneden ogsaa naar den starter paa en soendag', () => {
    // 2026-11-01 er en soendag - da ligger mandagen i oktober.
    const { fra, til } = heleUkerRundt(2026, 11)
    expect(fra).toBe('2026-10-26')
    expect(til >= '2026-11-30').toBe(true)
  })
})
