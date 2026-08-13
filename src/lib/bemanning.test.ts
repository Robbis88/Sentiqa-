import { describe, expect, test } from 'vitest'
import {
  dagerPerUkedag,
  disponibleTimerAar,
  fordelPaaMaaneder,
  planleggMaaned,
  type Vindu,
} from './bemanning'

const FRADRAG = { reservePst: 1.8, sikkerhetPst: 3 }

describe('årsramme til måned', () => {
  test('fradragene tas multiplikativt, ikke som sum', () => {
    // 1,8 % og 3 % er ikke 4,8 % - de legges på hverandre.
    expect(disponibleTimerAar(10000, FRADRAG)).toBeCloseTo(10000 * 0.982 * 0.97, 6)
  })

  test('månedene summerer til nettorammen', () => {
    const brutto = [615671, 632617, 663619, 712681, 725674, 864280,
      977680, 845240, 638803, 590060, 490579, 548666]
    const m = fordelPaaMaaneder(11187.47, brutto, FRADRAG)
    expect(m.reduce((a, b) => a + b, 0)).toBeCloseTo(disponibleTimerAar(11187.47, FRADRAG), 6)
  })

  test('juli får mest og november minst — Dales egen bruttokurve', () => {
    const brutto = [615671, 632617, 663619, 712681, 725674, 864280,
      977680, 845240, 638803, 590060, 490579, 548666]
    const m = fordelPaaMaaneder(11187.47, brutto, FRADRAG)
    expect(Math.max(...m)).toBe(m[6]) // juli
    expect(Math.min(...m)).toBe(m[10]) // november
    expect(Math.max(...m) / Math.min(...m)).toBeCloseTo(977680 / 490579, 6)
  })

  test('uten BP faller den tilbake på flat fordeling', () => {
    const m = fordelPaaMaaneder(1200, new Array(12).fill(0), { reservePst: 0, sikkerhetPst: 0 })
    expect(m).toEqual(new Array(12).fill(100))
  })

  test('avviser feil antall månedstall', () => {
    expect(() => fordelPaaMaaneder(1000, [1, 2, 3], FRADRAG)).toThrow(/12/)
  })
})

describe('dagerPerUkedag', () => {
  test('januar 2026 har fem torsdager og fire mandager', () => {
    const d = dagerPerUkedag(2026, 1)
    expect(d[4]).toBe(5) // torsdag: 1., 8., 15., 22., 29.
    expect(d[1]).toBe(4)
    expect(d.slice(1).reduce((a, b) => a + b, 0)).toBe(31)
  })

  test('februar 2026 har 28 dager', () => {
    expect(dagerPerUkedag(2026, 2).slice(1).reduce((a, b) => a + b, 0)).toBe(28)
  })
})

// Én stasjon, én ukedag, åpent 06-10, for å kunne regne i hodet.
const vindu = (minBemanning = 1): Vindu[] => [
  { ukedag: 1, fraTime: 6, tilTime: 10, minBemanning },
]
const profil = (verdier: Record<number, number>) =>
  new Map(Object.entries(verdier).map(([t, v]) => [`1:${t}`, v]))

describe('planleggMaaned', () => {
  test('gulvet bindes først, og faste vakter belaster ikke rammen', () => {
    const p = planleggMaaned({
      disponibleTimer: 100,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [{ ukedag: 1, fraTime: 6, tilTime: 8 }], // dekker 06 og 07
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0 }),
    })
    const mandager = dagerPerUkedag(2026, 1)[1] // 4
    // 06 og 07 dekkes av fast vakt -> gulv 0. 08 og 09 koster 1 person hver.
    expect(p.bundneTimer).toBe(2 * mandager)
    expect(p.timer.find((r) => r.time === 6)?.gulv).toBe(0)
    expect(p.timer.find((r) => r.time === 6)?.fast).toBe(1)
    expect(p.timer.find((r) => r.time === 8)?.gulv).toBe(1)
  })

  test('krav-vindu hever gulvet der butikksjefen har sagt det trengs to', () => {
    const p = planleggMaaned({
      disponibleTimer: 200,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [{ ukedag: 1, fraTime: 6, tilTime: 8, antall: 2 }],
      fasteVakter: [],
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0 }),
    })
    expect(p.timer.find((r) => r.time === 6)?.gulv).toBe(2)
    expect(p.timer.find((r) => r.time === 8)?.gulv).toBe(1)
  })

  test('en rolig time får aldri to før hver travlere time har fått sin', () => {
    // Kunder: 06=2, 07=40, 08=30, 09=20. Budsjett til noen få ekstra.
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 4 * mandager + 3 * mandager, // gulv + tre ekstra personer
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 2, 7: 40, 8: 30, 9: 20 }),
    })
    const f = (t: number) => p.timer.find((r) => r.time === t)!
    // Den rolige timen står med én. Det er hele poenget.
    expect(f(6).ekstra).toBe(0)
    expect(f(6).sum).toBe(1)
    // Og bemanningen er monoton i kundetrykk: ingen roligere time har flere
    // folk enn en travlere. (07 får sin tredje før 09 får sin andre, fordi
    // 40/3 fortsatt er dårligere dekning enn 20/2 — det er meningen.)
    const sortert = [...p.timer].sort((a, b) => b.kunder - a.kunder)
    for (let i = 1; i < sortert.length; i++) {
      expect(sortert[i].sum).toBeLessThanOrEqual(sortert[i - 1].sum)
    }
    expect(f(7).sum).toBeGreaterThan(f(9).sum)
  })

  test('en time med kraftig trykk får tre, fire og fem når budsjettet rekker', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 4 * mandager + 8 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 1, 7: 5, 8: 200, 9: 10 }),
    })
    expect(p.timer.find((r) => r.time === 8)!.sum).toBeGreaterThanOrEqual(5)
    expect(p.timer.find((r) => r.time === 6)!.sum).toBe(1)
  })

  test('timer uten kunder får aldri ekstra bemanning', () => {
    const p = planleggMaaned({
      disponibleTimer: 10000,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0 }),
    })
    expect(p.timer.every((r) => r.ekstra === 0)).toBe(true)
    expect(p.brukteTimer).toBe(0)
  })

  test('maksBemanning respekteres', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 4 * mandager + 20 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 10, 7: 10, 8: 10, 9: 10 }),
      maksBemanning: 3,
    })
    expect(Math.max(...p.timer.map((r) => r.sum))).toBe(3)
  })

  test('flagger at planen ikke er gjennomførbar når gulvet er dyrere enn rammen', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 2 * mandager, // gulvet koster 4 personer x mandager
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 5, 7: 5, 8: 5, 9: 5 }),
    })
    expect(p.gjennomforbar).toBe(false)
    expect(p.underskudd).toBe(2 * mandager)
  })

  test('bruker aldri mer enn rammen', () => {
    const p = planleggMaaned({
      disponibleTimer: 137,
      ar: 2026, maned: 1,
      vinduer: [{ ukedag: 1, fraTime: 6, tilTime: 22, minBemanning: 1 },
        { ukedag: 6, fraTime: 8, tilTime: 20, minBemanning: 1 }],
      krav: [],
      fasteVakter: [],
      profil: new Map([...Array(24).keys()].flatMap((t) => [
        [`1:${t}`, t * 3] as [string, number],
        [`6:${t}`, t * 5] as [string, number],
      ])),
    })
    expect(p.bundneTimer + p.brukteTimer).toBeLessThanOrEqual(137)
  })
})
