import { describe, expect, test } from 'vitest'
import {
  ARSVERK_TIMER, MANEDER, forklarDekning, justeringPerManed, uavklarte,
} from './lederdekning'

describe('lederdekning', () => {
  test('årsverket er det St1 faktisk trekker fra', () => {
    // KANARIFUGL FOR EN TALLENDRING I STILLHET. 1695 står i 0082 som
    // «timene St1 trekker fra for butikksjefens fastlønn». Endres den
    // her uten at noen sjekker migrasjonen, blir forslaget i skjemaet
    // et annet tall enn det basen er dokumentert med.
    expect(ARSVERK_TIMER).toBe(1695)
    expect(justeringPerManed(ARSVERK_TIMER)).toBe(141)
  })

  test('uten årsverk sier forklaringen at haken ikke gjør noe', () => {
    // DEN VIKTIGSTE AV DISSE. `fast_arsverk_timer` er 0 på alle fem
    // stasjoner i dag. Huker man av uten å sette den, skjer det
    // ingenting — og uten denne setningen ser det ut som om det virket.
    expect(forklarDekning('ikke_fastlonnet', 0))
      .toMatch(/årsverket er ikke satt/)
    expect(forklarDekning('ikke_fastlonnet', 141))
      .toMatch(/økes med 141 timer/)
  })

  test('ukjent er ikke nei', () => {
    // Tre tilstander, ikke to. En måned ingen har tatt stilling til
    // skal ikke justere rammen — og den skal se uavklart ut.
    expect(forklarDekning('ukjent', 141)).toMatch(/Ikke tatt stilling/)
    expect(forklarDekning('ukjent', 141)).not.toMatch(/økes/)
    expect(forklarDekning('fastlonnet', 141)).toMatch(/står som den er/)
  })

  test('uavklarte måneder telles, også når ingen er fylt ut', () => {
    expect(uavklarte([], 12), 'ingenting utfylt').toBe(12)
    expect(uavklarte([{ fastlonnet: true }, { fastlonnet: false }], 12)).toBe(10)
    // `null` i en rad er ikke et svar — den kan komme fra en left join.
    expect(uavklarte([{ fastlonnet: null }, { fastlonnet: true }], 12)).toBe(11)
    expect(uavklarte(Array(12).fill({ fastlonnet: true }), 12)).toBe(0)
  })

  test('tolv måneder, i rekkefølge', () => {
    expect(MANEDER).toHaveLength(12)
    expect(MANEDER[0]).toBe('Januar')
    expect(MANEDER[11]).toBe('Desember')
  })
})
