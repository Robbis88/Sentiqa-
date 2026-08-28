import { describe, expect, test } from 'vitest'
import { delVakt, tilLonnslinjer, LONNSART } from './tidsband'

const t = (v: { dato: string; fraTid: string; tilTid: string }) => {
  const m = delVakt(v)
  return Object.fromEntries([...m].map(([k, min]) => [k, min / 60]))
}

// 2026: mandag 4. mai, lørdag 9., søndag 10.
// Røde dager i mai: 1. (fre), 14. (Kristi himmelfart), 17. (søn),
// 24. (1. pinsedag), 25. (2. pinsedag). Pinseaften er 23. mai.

describe('delVakt — hverdag', () => {
  test('en dagvakt gir bare timelønn', () => {
    expect(t({ dato: '2026-05-04', fraTid: '08:00', tilTid: '16:00' }))
      .toEqual({ [LONNSART.timelonn]: 8 })
  })

  test('kveldsvakt deles i to bånd', () => {
    // 16–22: 18–21 gir tre timer, 21–22 gir én.
    expect(t({ dato: '2026-05-04', fraTid: '16:00', tilTid: '22:00' }))
      .toEqual({ [LONNSART.timelonn]: 6, [LONNSART.hverdag1821]: 3, [LONNSART.hverdag2124]: 1 })
  })

  test('nattevakt over midnatt lander på riktig døgn', () => {
    // Mandag 22:00 – tirsdag 06:00.
    expect(t({ dato: '2026-05-04', fraTid: '22:00', tilTid: '06:00' }))
      .toEqual({ [LONNSART.timelonn]: 8, [LONNSART.hverdag2124]: 2, [LONNSART.hverdag0006]: 6 })
  })
})

describe('delVakt — lørdag', () => {
  test('lørdagstillegget starter 18, ikke før', () => {
    expect(t({ dato: '2026-05-09', fraTid: '10:00', tilTid: '18:00' }))
      .toEqual({ [LONNSART.timelonn]: 8 })
  })

  test('16–22 gir fire timer lørdagstillegg', () => {
    expect(t({ dato: '2026-05-09', fraTid: '16:00', tilTid: '22:00' }))
      .toEqual({ [LONNSART.timelonn]: 6, [LONNSART.lordag]: 4 })
  })

  test('lørdagskveld gir IKKE kveldstillegg — båndene er ikke stablende', () => {
    const r = t({ dato: '2026-05-09', fraTid: '18:00', tilTid: '00:00' })
    expect(r[LONNSART.lordag]).toBe(6)
    expect(r[LONNSART.hverdag1821]).toBeUndefined()
    expect(r[LONNSART.hverdag2124]).toBeUndefined()
  })

  test('lørdag natt til søndag deles på midnatt', () => {
    // 23:00 lørdag – 07:00 søndag: 1 t lørdag, 6 t søndag natt, 1 t søndag dag.
    expect(t({ dato: '2026-05-09', fraTid: '23:00', tilTid: '07:00' }))
      .toEqual({
        [LONNSART.timelonn]: 8,
        [LONNSART.lordag]: 1,
        [LONNSART.sondag0006]: 6,
        [LONNSART.sondag0618]: 1,
      })
  })
})

describe('delVakt — søndag', () => {
  test('tre bånd gjennom døgnet', () => {
    expect(t({ dato: '2026-05-10', fraTid: '13:00', tilTid: '19:00' }))
      .toEqual({ [LONNSART.timelonn]: 6, [LONNSART.sondag0618]: 5, [LONNSART.sondag1824]: 1 })
  })
})

describe('delVakt — røde dager', () => {
  test('hele vakten er rød, og gir ingen ukedagstillegg', () => {
    // 1. mai er en fredag.
    expect(t({ dato: '2026-05-01', fraTid: '16:00', tilTid: '22:00' }))
      .toEqual({ [LONNSART.timelonn]: 6, [LONNSART.helligdag]: 6 })
  })

  test('helligdag følger forretningsdatoen OVER midnatt', () => {
    // Kristi himmelfart 14. mai, 19:00–00:20. De 20 minuttene etter
    // midnatt er fredag, men vakten hører til torsdagen — og easy@work
    // gir dem helligdag, ikke hverdag 00–06.
    const r = t({ dato: '2026-05-14', fraTid: '19:00', tilTid: '00:20' })
    expect(r[LONNSART.helligdag]).toBeCloseTo(5.33, 2)
    expect(r[LONNSART.hverdag0006]).toBeUndefined()
  })

  test('en vakt som STARTER dagen før en rød dag er ikke rød', () => {
    // Onsdag 13. mai, kvelden før Kristi himmelfart. Ingen aften-regel
    // her — den gjelder bare de fire navngitte aftenene.
    const r = t({ dato: '2026-05-13', fraTid: '16:00', tilTid: '22:00' })
    expect(r[LONNSART.helligdag]).toBeUndefined()
    expect(r[LONNSART.hverdag1821]).toBe(3)
  })
})

describe('delVakt — aftener', () => {
  test('pinseaften er rød fra 15', () => {
    // 23. mai 2026. Vakt 12:00–18:00 gir tre timer rødt (15–18).
    const r = t({ dato: '2026-05-23', fraTid: '12:00', tilTid: '18:00' })
    expect(r[LONNSART.helligdag]).toBe(3)
    expect(r[LONNSART.timelonn]).toBe(6)
  })

  test('før 15 på en aften er en vanlig lørdag', () => {
    const r = t({ dato: '2026-05-23', fraTid: '08:00', tilTid: '14:00' })
    expect(r[LONNSART.helligdag]).toBeUndefined()
    expect(r[LONNSART.lordag]).toBeUndefined()
  })

  test('julaften og nyttårsaften også', () => {
    for (const d of ['2026-12-24', '2026-12-31']) {
      expect(t({ dato: d, fraTid: '14:00', tilTid: '18:00' })[LONNSART.helligdag], d).toBe(3)
    }
  })
})

describe('tilLonnslinjer', () => {
  test('summerer per ansatt og runder til to desimaler', () => {
    const l = tilLonnslinjer([
      { ansattNr: '1009', dato: '2026-05-04', fraTid: '08:00', tilTid: '16:00' },
      { ansattNr: '1009', dato: '2026-05-05', fraTid: '16:00', tilTid: '22:00' },
    ])
    expect(l).toEqual([
      { ansattNr: '1009', lonnsart: LONNSART.timelonn, antall: 14 },
      { ansattNr: '1009', lonnsart: LONNSART.hverdag1821, antall: 3 },
      { ansattNr: '1009', lonnsart: LONNSART.hverdag2124, antall: 1 },
    ])
  })

  test('rekkefølgen er fast, så to kjøringer gir identiske filer', () => {
    const vakter = [
      { ansattNr: '589', dato: '2026-05-09', fraTid: '18:00', tilTid: '00:00' },
      { ansattNr: '1009', dato: '2026-05-04', fraTid: '08:00', tilTid: '16:00' },
    ]
    const a = tilLonnslinjer(vakter)
    const b = tilLonnslinjer([...vakter].reverse())
    expect(a).toEqual(b)
  })

  test('skjeve minutter blir riktige timer', () => {
    // 12:01–18:00 = 5 t 59 min = 5,98 t.
    const l = tilLonnslinjer([
      { ansattNr: '1', dato: '2026-05-04', fraTid: '12:01', tilTid: '18:00' },
    ])
    expect(l[0].antall).toBe(5.98)
  })

  test('under et halvt minutt er støy og tas ikke med', () => {
    const l = tilLonnslinjer([
      { ansattNr: '1', dato: '2026-05-04', fraTid: '08:00', tilTid: '08:00' },
    ])
    expect(l).toEqual([])
  })
})

// =====================================================================
// REGISTRERT PAUSE (0150) — de samme minuttene ut av BEGGE.
// =====================================================================
describe('pausen utelates fra timeloenn og tillegg', () => {
  const NAVN: Record<string, string> = Object.fromEntries(
    Object.entries(LONNSART).map(([k, v]) => [v, k]))
  const kart = (v: Parameters<typeof delVakt>[0]) =>
    Object.fromEntries([...delVakt(v)].map(([k, m]) => [NAVN[k], m]))

  test('uten pause staar vakta uroert', () => {
    // 2026-08-27 er en torsdag.
    expect(kart({ dato: '2026-08-27', fraTid: '07:00', tilTid: '15:00' }))
      .toEqual({ timelonn: 480 })
  })

  test('trekker de tretti minuttene fra timeloenn', () => {
    expect(kart({
      dato: '2026-08-27', fraTid: '07:00', tilTid: '15:00',
      pauseFraTid: '11:00', pauseTilTid: '11:30',
    })).toEqual({ timelonn: 450 })
  })

  test('EN PAUSE I ET TILLEGGSBAAND FALLER UT AV BAADE DELER', () => {
    // 18:00-18:30 ligger i 1429 (hverdag 18-21). Uten utelatelsen fra
    // baandet ville hun faatt kveldstillegg for en pause hun ikke jobbet.
    expect(kart({
      dato: '2026-08-27', fraTid: '15:00', tilTid: '21:00',
      pauseFraTid: '18:00', pauseTilTid: '18:30',
    })).toEqual({ timelonn: 330, hverdag1821: 150 })
    // Til sammenligning, samme vakt uten pause:
    expect(kart({ dato: '2026-08-27', fraTid: '15:00', tilTid: '21:00' }))
      .toEqual({ timelonn: 360, hverdag1821: 180 })
  })

  test('virker over midnatt — pausen hoerer til neste doegn', () => {
    expect(kart({
      dato: '2026-08-27', fraTid: '22:00', tilTid: '06:00',
      pauseFraTid: '01:00', pauseTilTid: '01:30',
    })).toEqual({ timelonn: 450, hverdag2124: 120, hverdag0006: 330 })
  })

  test('en pause som krysser midnatt klemmes ikke i stykker', () => {
    expect(kart({
      dato: '2026-08-27', fraTid: '22:00', tilTid: '06:00',
      pauseFraTid: '23:45', pauseTilTid: '00:15',
    })).toEqual({ timelonn: 450, hverdag2124: 105, hverdag0006: 345 })
  })

  test('en klemt pause trekker bare det den faktisk varte', () => {
    // avledVakter klemmer mot sluttiden; her kommer den inn som 10 min.
    expect(kart({
      dato: '2026-08-27', fraTid: '07:00', tilTid: '15:00',
      pauseFraTid: '14:50', pauseTilTid: '15:00',
    })).toEqual({ timelonn: 470 })
  })
})
