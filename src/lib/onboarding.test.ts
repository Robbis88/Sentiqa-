import { describe, expect, test } from 'vitest'
import { KILDER, nesteSteg, onboardingsteg, type Kildemaaling } from './onboarding'

const m = (noekkel: string, stasjoner: number, dager: number): Kildemaaling =>
  ({ noekkel, stasjonerMedData: stasjoner, dagerDekket: dager, sisteDato: '2026-08-13' })

const alt = (stasjoner: number, dager: number) => KILDER.map((k) => m(k.noekkel, stasjoner, dager))

describe('onboardingsteg', () => {
  test('en ny retailer mangler alt, og får vite hvor filene hentes', () => {
    const s = onboardingsteg([], 5)
    expect(s.every((x) => x.status === 'mangler')).toBe(true)
    expect(s[0].beskjed).toContain('St1-rapport 0714')
  })

  test('tre av fem stasjoner er ikke «ok» — det ser ferdig ut uten å være det', () => {
    const s = onboardingsteg([m('timesalg', 3, 400)], 5)
    const t = s.find((x) => x.noekkel === 'timesalg')!
    expect(t.status).toBe('ufullstendig')
    expect(t.beskjed).toContain('2 av 5')
  })

  test('for få dager er «tynt», ikke «mangler»', () => {
    const s = onboardingsteg([m('timesalg', 5, 60)], 5)
    expect(s.find((x) => x.noekkel === 'timesalg')!.status).toBe('tynt')
  })

  test('kilder uten dagskrav vurderes bare på om alle stasjoner har dem', () => {
    const s = onboardingsteg([m('bemanning_maned', 5, 0)], 5)
    expect(s.find((x) => x.noekkel === 'bemanning_maned')!.status).toBe('ok')
  })

  test('alt på plass gir ok hele veien', () => {
    const s = onboardingsteg(alt(5, 400), 5)
    expect(s.every((x) => x.status === 'ok')).toBe(true)
  })
})

describe('nesteSteg', () => {
  test('peker på det kritiske før det pene', () => {
    // Stemplinger mangler helt, men salgsstatistikk er tynn — og
    // salgsstatistikken bærer alt annet.
    const s = onboardingsteg([m('st1_salgsstatistikk', 5, 30), m('timesalg', 5, 400),
      m('bemanning_maned', 5, 0), m('regnskapslinjer', 5, 0)], 5)
    expect(nesteSteg(s)!.noekkel).toBe('st1_salgsstatistikk')
  })

  test('helt manglende går foran tynt, når begge er kritiske', () => {
    const s = onboardingsteg([m('st1_salgsstatistikk', 5, 400), m('timesalg', 0, 0),
      m('bemanning_maned', 5, 0)], 5)
    expect(nesteSteg(s)!.noekkel).toBe('timesalg')
  })

  test('når alt er på plass er det ingen neste steg', () => {
    expect(nesteSteg(onboardingsteg(alt(5, 400), 5))).toBeNull()
  })

  test('rekkefølgen i KILDER avgjør når alt annet er likt', () => {
    const s = onboardingsteg([], 5)
    expect(nesteSteg(s)!.noekkel).toBe(KILDER.find((k) => k.kritisk)!.noekkel)
  })
})
