import { describe, expect, it } from 'vitest'
import { byggLonnsrom, laertMargin, bpMargin, erDrivstoff, MAANEDER_FOR_MARGIN } from './rom'

const R = (maaned: string, omsetningKr: number | null, bruttoKr: number | null) =>
  ({ maaned, omsetningKr, bruttoKr })
const G = (maaned: string, omsetningKr: number, svinnKr = 0) =>
  ({ maaned, omsetningKr, svinnKr })
const B = (maaned: string, bruttoKr: number | null, lonnKr: number | null) =>
  ({ maaned, bruttoKr, lonnKr })

describe('laertMargin', () => {
  it('summerer brutto og omsetning, ikke snittet av brøkene', () => {
    // En liten maaned med skyhoey margin skal ikke veie like mye som en
    // stor med normal. Snittet av 50 % og 25 % er 37,5 %; den faktiske
    // marginen er 300 000 / 1 100 000 = 27,3 %.
    const m = laertMargin([R('2026-07', 1000000, 250000), R('2026-06', 100000, 50000)])
    expect(m).toBeCloseTo(300000 / 1100000, 6)
    expect(m).not.toBeCloseTo(0.375, 3)
  })

  it('bruker bare de nyeste månedene', () => {
    const gamle = Array.from({ length: 10 }, (_, i) =>
      R(`2025-${String(i + 1).padStart(2, '0')}`, 1000, 100)) // 10 %
    const nye = Array.from({ length: MAANEDER_FOR_MARGIN }, (_, i) =>
      R(`2026-${String(i + 1).padStart(2, '0')}`, 1000, 300)) // 30 %
    expect(laertMargin([...gamle, ...nye])).toBeCloseTo(0.3, 6)
  })

  it('hopper over måneder som mangler et av tallene', () => {
    expect(laertMargin([R('2026-07', 1000, null), R('2026-06', 1000, 280)]))
      .toBeCloseTo(0.28, 6)
  })

  // AA GJETTE EN MARGIN VILLE GJORT ET HULL TIL ET TALL.
  it('gir null når ingenting kan måles', () => {
    expect(laertMargin([])).toBeNull()
    expect(laertMargin([R('2026-07', 0, 0)])).toBeNull()
    expect(laertMargin([R('2026-07', null, 280)])).toBeNull()
  })
})

describe('bpMargin', () => {
  it('bruker BP-ens egen forventning når regnskapet mangler', () => {
    const m = bpMargin([B('2026-08', 280000, 90000)], [G('2026-08', 1000000)])
    expect(m).toBeCloseTo(0.28, 6)
  })

  it('gir null uten omsetning å måle mot', () => {
    expect(bpMargin([B('2026-08', 280000, 90000)], [])).toBeNull()
  })
})

describe('byggLonnsrom', () => {
  // BP: 383 285 i loenn paa 1 201 000 i brutto = 31,9 % loennsandel.
  const bp = [B('2026-08', 1201000, 383285), B('2026-07', 1201000, 383285)]

  it('regner rommet som lønnsandelen av faktisk brutto', () => {
    const [aug] = byggLonnsrom(
      [R('2026-07', 4200000, 1201000)],
      [G('2026-08', 4060000, 24000)],
      bp,
    )
    expect(aug.maaned).toBe('2026-08')
    expect(aug.anslaatt).toBe(true)
    expect(aug.lonnsandel).toBeCloseTo(383285 / 1201000, 6)
    // margin 1 201 000 / 4 200 000 = 28,60 %
    // brutto  4 060 000 x 0,2860 - 24 000 = 1 137 100
    expect(aug.margin).toBeCloseTo(1201000 / 4200000, 6)
    expect(aug.bruttoKr).toBeCloseTo(4060000 * (1201000 / 4200000) - 24000, 2)
    expect(aug.romKr).toBeCloseTo(aug.lonnsandel! * aug.bruttoKr!, 2)
  })

  // SVINNET TREKKES FRA BRUTTO, ikke fra rommet. Mer svinn krymper
  // rommet av seg selv - det er hele koblingen mellom de to sidene.
  it('lar svinn krympe rommet', () => {
    const uten = byggLonnsrom([R('2026-07', 4200000, 1201000)], [G('2026-08', 4060000, 0)], bp)[0]
    const med = byggLonnsrom([R('2026-07', 4200000, 1201000)], [G('2026-08', 4060000, 50000)], bp)[0]
    expect(med.romKr!).toBeLessThan(uten.romKr!)
    // Rommet krymper med loennsandelen av svinnet, ikke med hele svinnet.
    expect(uten.romKr! - med.romKr!).toBeCloseTo(50000 * (383285 / 1201000), 2)
  })

  // REGNSKAPET VINNER OVER ANSLAGET. Et anslag ved siden av fasiten
  // ville bare vaert stoey.
  it('bruker regnskapets brutto når måneden er avlagt', () => {
    const rom = byggLonnsrom(
      [R('2026-07', 4200000, 1150000)],
      [G('2026-07', 4200000, 30000)],
      bp,
    )
    const juli = rom.find((m) => m.maaned === '2026-07')!
    expect(juli.anslaatt).toBe(false)
    expect(juli.bruttoKr).toBe(1150000)
  })

  // EN NY KJEDE SKAL IKKE STAA UTEN SVAR. Uten reserven ville rommet
  // krevd et halvaar med regnskap foer det virket - et onboardingkrav i
  // praksis om ikke i ord.
  it('faller tilbake på BP-marginen uten avlagt regnskap', () => {
    const [aug] = byggLonnsrom([], [G('2026-08', 4060000, 24000)], bp)
    expect(aug.marginkilde).toBe('bp')
    expect(aug.romKr).not.toBeNull()
  })

  it('gir null rom når BP mangler', () => {
    const [aug] = byggLonnsrom(
      [R('2026-07', 4200000, 1201000)],
      [G('2026-08', 4060000, 0)],
      [B('2026-08', null, null)],
    )
    expect(aug.lonnsandel).toBeNull()
    expect(aug.romKr).toBeNull()
  })

  it('deler ikke på null brutto i BP', () => {
    const [aug] = byggLonnsrom([], [G('2026-08', 100, 0)], [B('2026-08', 0, 383285)])
    expect(aug.lonnsandel).toBeNull()
    expect(aug.romKr).toBeNull()
  })
})

// =====================================================================
// DRIVSTOFF SKAL ALDRI INN I MARGINEN
//
// Regnskapets bruttofortjeneste per stasjon har en rad per
// avdelingsrollup, og drivstoff er en av dem. Omsetningen paa den andre
// siden av broeken kommer fra `v_butikksalg`, som holder drivstoff
// utenfor. Blandes de, deles brutto MED drivstoff paa omsetning UTEN.
//
// Drivstoff er ~68 % av omsetningen: feilen ville gjort marginen nesten
// tre ganger for hoey, og loennsrommet like mye for stort.
// =====================================================================
describe('erDrivstoff', () => {
  it('kjenner igjen avdelingen på navnet', () => {
    expect(erDrivstoff('ENERGI')).toBe(true)
    expect(erDrivstoff('energi')).toBe(true)
    expect(erDrivstoff('Energi drivstoff')).toBe(true)
  })

  // NAVNET, IKKE KODEN. AGENTS.md: kodeverdien varierer mellom kjeder og
  // er ikke mappet. Boter noen paa en kode her, feiler denne.
  it('slipper butikkens egne avdelinger gjennom', () => {
    expect(erDrivstoff('MAT')).toBe(false)
    expect(erDrivstoff('KIOSK')).toBe(false)
    expect(erDrivstoff('BILVASK')).toBe(false)
    expect(erDrivstoff('1000')).toBe(false)
  })
})
