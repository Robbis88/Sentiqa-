import { describe, expect, test } from 'vitest'
import { avledVakter, kanLageLonnsfil, type Hendelse } from './avled'

let teller = 0
const h = (
  tidspunkt: string,
  type: 'inn' | 'ut',
  ansattNr = '11058',
  stasjonId = 'A',
): Hendelse => ({
  id: `h${++teller}`,
  ansattNr,
  ansattNavn: 'Kari',
  stasjonId,
  tidspunkt,
  type,
})

// Oslo er UTC+2 om sommeren. Tidspunktene skrives med sone, saa testene
// sier hva de mener og ikke er avhengige av maskinens innstilling.
describe('vanlige vakter', () => {
  test('inn og ut blir en vakt', () => {
    const { vakter, avvik } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn'),
      h('2026-08-19T15:00:00+02:00', 'ut'),
    ])
    expect(avvik).toEqual([])
    expect(vakter).toHaveLength(1)
    expect(vakter[0]).toMatchObject({
      dato: '2026-08-19', fraTid: '07:00', tilTid: '15:00', minutter: 480,
    })
  })

  test('to vakter samme dag holdes fra hverandre', () => {
    const { vakter } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn'),
      h('2026-08-19T11:00:00+02:00', 'ut'),
      h('2026-08-19T16:00:00+02:00', 'inn'),
      h('2026-08-19T20:00:00+02:00', 'ut'),
    ])
    expect(vakter).toHaveLength(2)
    expect(vakter.map((v) => v.minutter)).toEqual([240, 240])
  })

  test('to ansatte blandes ikke', () => {
    const { vakter, avvik } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn', '11058'),
      h('2026-08-19T08:00:00+02:00', 'inn', '11059'),
      h('2026-08-19T15:00:00+02:00', 'ut', '11058'),
      h('2026-08-19T16:00:00+02:00', 'ut', '11059'),
    ])
    expect(avvik).toEqual([])
    expect(vakter).toHaveLength(2)
    // Uten gruppering per ansatt ville den forste «ut» lukket feil vakt.
    expect(vakter.find((v) => v.ansattNr === '11059')?.minutter).toBe(480)
  })

  test('rekkefolgen hendelsene kommer i betyr ingenting', () => {
    // En korreksjon lagt inn i etterkant hoerer hjemme der den skjedde,
    // ikke der den ble skrevet.
    const { vakter, avvik } = avledVakter([
      h('2026-08-19T15:00:00+02:00', 'ut'),
      h('2026-08-19T07:00:00+02:00', 'inn'),
    ])
    expect(avvik).toEqual([])
    expect(vakter[0].minutter).toBe(480)
  })
})

describe('over midnatt', () => {
  test('forretningsdatoen folger STARTEN', () => {
    // Samme regel som tidsband.ts bruker for helligdager. Er de to
    // uenige, sier lonnsfila og bemanningsplanen ulike ting om samme vakt.
    const { vakter } = avledVakter([
      h('2026-08-19T23:30:00+02:00', 'inn'),
      h('2026-08-20T00:30:00+02:00', 'ut'),
    ])
    expect(vakter[0].dato).toBe('2026-08-19')
    expect(vakter[0].fraTid).toBe('23:30')
    expect(vakter[0].tilTid).toBe('00:30')
    expect(vakter[0].minutter).toBe(60)
  })
})

describe('de vonde tilfellene', () => {
  test('glemt utstempling gir en AAPEN vakt, ikke en gjettet sluttid', () => {
    // En automatisk lukking som treffer feil er verre enn ingen: timene
    // ser riktige ut og er det ikke, saa ingen oppdager det.
    const { vakter, avvik } = avledVakter([h('2026-08-19T07:00:00+02:00', 'inn')])
    expect(vakter).toEqual([])
    expect(avvik).toHaveLength(1)
    expect(avvik[0].slag).toBe('aapen')
  })

  test('inn mens man er inne lukker ikke den forrige i stillhet', () => {
    const { vakter, avvik } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn'),
      h('2026-08-19T12:00:00+02:00', 'inn'),
      h('2026-08-19T15:00:00+02:00', 'ut'),
    ])
    // Den andre inn-en danner en vakt med ut-en. Den forste staar aapen
    // og blokkerer - noen glemte aa stemple ut, og det skal ryddes.
    expect(vakter).toHaveLength(1)
    expect(vakter[0].fraTid).toBe('12:00')
    expect(avvik.map((a) => a.slag).sort()).toEqual(['aapen', 'dobbel_inn'])
  })

  test('ut uten inn meldes framfor aa ignoreres', () => {
    const { vakter, avvik } = avledVakter([h('2026-08-19T15:00:00+02:00', 'ut')])
    expect(vakter).toEqual([])
    expect(avvik[0].slag).toBe('foreldrelos')
  })

  test('en aapen vakt hos EN ansatt stopper ikke de andres vakter', () => {
    const { vakter, avvik } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn', '11058'),
      h('2026-08-19T07:00:00+02:00', 'inn', '11059'),
      h('2026-08-19T15:00:00+02:00', 'ut', '11059'),
    ])
    expect(vakter).toHaveLength(1)
    expect(vakter[0].ansattNr).toBe('11059')
    expect(avvik).toHaveLength(1)
  })
})

describe('stasjon', () => {
  test('vakten hoerer til der den BEGYNTE', () => {
    // Gaar noen over til nabostasjonen midt i vakta, ville en delt vakt
    // telt i begge stasjoners bemanning.
    const { vakter } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn', '11058', 'A'),
      h('2026-08-19T15:00:00+02:00', 'ut', '11058', 'B'),
    ])
    expect(vakter[0].stasjonId).toBe('A')
  })
})

describe('kanLageLonnsfil', () => {
  test('ett avvik er nok til aa blokkere', () => {
    const { avvik } = avledVakter([h('2026-08-19T07:00:00+02:00', 'inn')])
    expect(kanLageLonnsfil(avvik)).toBe(false)
  })

  test('uten avvik gaar fila', () => {
    const { avvik } = avledVakter([
      h('2026-08-19T07:00:00+02:00', 'inn'),
      h('2026-08-19T15:00:00+02:00', 'ut'),
    ])
    expect(kanLageLonnsfil(avvik)).toBe(true)
  })
})
