import { describe, expect, test } from 'vitest'
import { vaktliste, type Dagsbemanning } from './bemanning'

const rad = (time: number, fast: number, gulv: number, ekstra: number): Dagsbemanning =>
  ({ dato: '2026-03-02', ukedag: 1, time, fast, gulv, ekstra, sum: fast + gulv + ekstra, kunder: 0, kostnad: 1 })

const vis = (v: { fraTime: number; tilTime: number; kilde: string }[]) =>
  v.map((x) => `${x.kilde} ${x.fraTime}-${x.tilTime}`)

describe('vaktliste', () => {
  test('en gjennomgående grunnbemanning blir én vakt', () => {
    const v = vaktliste([6, 7, 8, 9, 10].map((t) => rad(t, 0, 1, 0)))
    expect(vis(v)).toEqual(['gulv 6-11'])
  })

  test('to overlappende ekstravakter leses som to vakter, ikke som en topp', () => {
    // Dette er tilfellet Robert reagerte på: 3 personer klokka 12.
    // Riktig lesning er 10–15 og 11–16, som overlapper i én time.
    const timer = [
      ...[6, 7, 8, 9].map((t) => rad(t, 0, 1, 0)),
      rad(10, 0, 1, 1),
      ...[11, 12, 13, 14].map((t) => rad(t, 0, 1, 2)),
      rad(15, 0, 1, 1),
      ...[16, 17].map((t) => rad(t, 0, 1, 0)),
    ]
    expect(vis(vaktliste(timer))).toEqual(['gulv 6-18', 'ekstra 10-16', 'ekstra 11-15'])
  })

  test('gulv og ekstra smelter ikke sammen', () => {
    const v = vaktliste([6, 7, 8, 9, 10].map((t) => rad(t, 0, 1, 1)))
    expect(vis(v)).toEqual(['gulv 6-11', 'ekstra 6-11'])
  })

  test('et hull i vinduet bryter vakten', () => {
    // Stengt 10–12. Ingen går hjem og kommer tilbake.
    const v = vaktliste([6, 7, 8, 9, 12, 13, 14].map((t) => rad(t, 0, 1, 0)))
    expect(vis(v)).toEqual(['gulv 6-10', 'gulv 12-15'])
  })

  test('en fast vakt teller med i gulvet', () => {
    const v = vaktliste([
      ...[6, 7].map((t) => rad(t, 0, 1, 0)),
      ...[8, 9].map((t) => rad(t, 1, 0, 0)),
      ...[10, 11].map((t) => rad(t, 0, 1, 0)),
    ])
    expect(vis(v)).toEqual(['gulv 6-12'])
  })

  test('flere dager holdes fra hverandre', () => {
    const v = vaktliste([
      ...[6, 7].map((t) => rad(t, 0, 1, 0)),
      ...[6, 7].map((t) => ({ ...rad(t, 0, 1, 0), dato: '2026-03-03' })),
    ])
    expect(v).toHaveLength(2)
    expect(v[0].dato).toBe('2026-03-02')
    expect(v[1].dato).toBe('2026-03-03')
  })

  test('timer teller riktig', () => {
    expect(vaktliste([6, 7, 8, 9, 10].map((t) => rad(t, 0, 1, 0)))[0].timer).toBe(5)
  })
})
