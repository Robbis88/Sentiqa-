import { describe, expect, test } from 'vitest'
import { formendring, formendringTekst, justerProfil } from './bemanningsanalyse'

const UKE = ['', 'man', 'tir', 'ons', 'tor', 'fre', 'lør', 'søn']
// Døgnkurve 06–20 for alle sju dager, med en gitt verdi per time.
const kurve = (per: (time: number) => number) => new Map(
  [1, 2, 3, 4, 5, 6, 7].flatMap((u) =>
    Array.from({ length: 14 }, (_, i) => [`${u}:${i + 6}`, per(i + 6)] as [string, number])))

describe('formendring', () => {
  test('jevn vekst er ikke en formendring', () => {
    // 20 % flere kunder overalt. Formen er den samme, og veksten ligger
    // allerede i BP-rammen — legger vi den på her også, telles den to ganger.
    const e = formendring(kurve(() => 10), kurve(() => 12))
    expect(e.drift).toBeCloseTo(0, 6)
    expect(e.paalitelig).toBe(false)
  })

  test('kveldene vokser mens morgenene faller', () => {
    const e = formendring(
      kurve((t) => (t < 13 ? 20 : 10)),
      kurve((t) => (t < 13 ? 10 : 20)),
    )
    expect(e.paalitelig).toBe(true)
    expect(e.faktorer.get('1:8')!).toBeLessThan(1)
    expect(e.faktorer.get('1:18')!).toBeGreaterThan(1)
  })

  test('en dod nattetime som dobler seg velter ikke bildet', () => {
    // 2 → 4 kunder i én time, alt annet likt. Vektingen skal gjøre at
    // dette ikke regnes som at formen har flyttet seg.
    const basis = kurve(() => 50)
    const ny = new Map(basis)
    ny.set('1:6', 2)
    const forst = formendring(basis, new Map([...basis]).set('1:6', 2))
    ny.set('1:6', 4)
    const etter = formendring(basis, ny)
    expect(etter.drift).toBeLessThan(0.08)
    expect(forst.paalitelig).toBe(false)
  })

  test('for lite data gir ingen konklusjon', () => {
    const smaa = new Map([['1:12', 5]])
    expect(formendring(smaa, smaa).paalitelig).toBe(false)
  })

  test('en time som ikke fantes i fjor hoppes over', () => {
    const basis = kurve(() => 10)
    const ny = new Map(kurve(() => 10))
    ny.set('1:5', 30) // ny åpningstime
    expect(formendring(basis, ny).faktorer.has('1:5')).toBe(false)
  })
})

describe('justerProfil', () => {
  const basis = kurve((t) => (t < 13 ? 20 : 10))
  const ny = kurve((t) => (t < 13 ? 10 : 20))

  test('justerer fjorårets kurve etter det som er målt', () => {
    const e = formendring(basis, ny)
    const septemberIFjor = kurve((t) => (t < 13 ? 100 : 50))
    const justert = justerProfil(septemberIFjor, e)
    expect(justert.get('1:8')!).toBeLessThan(100)
    expect(justert.get('1:18')!).toBeGreaterThan(50)
  })

  test('rører ikke profilen når driften er for liten', () => {
    const e = formendring(kurve(() => 10), kurve(() => 11))
    const p = kurve(() => 100)
    expect(justerProfil(p, e)).toEqual(p)
  })

  test('justeringen kappes — ingen enkelttime kan velte planen', () => {
    const vill = new Map(kurve(() => 10))
    for (const u of [1, 2, 3, 4, 5, 6, 7]) vill.set(`${u}:12`, 500)
    const e = formendring(kurve(() => 10), vill)
    const justert = justerProfil(kurve(() => 100), e)
    expect(justert.get('1:12')).toBeLessThanOrEqual(170)
  })
})

describe('formendringTekst', () => {
  test('sier hva som har flyttet seg, eller ingenting', () => {
    const e = formendring(kurve((t) => (t < 13 ? 20 : 10)), kurve((t) => (t < 13 ? 10 : 20)))
    const t = formendringTekst(e, UKE)
    expect(t).toMatch(/flyttet seg/)
    expect(t).toMatch(/kl\. \d\d/)
    expect(formendringTekst(formendring(kurve(() => 10), kurve(() => 10)), UKE)).toBeNull()
  })
})
