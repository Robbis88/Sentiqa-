import { expect, test } from 'vitest'
import { returOppfolging } from './oppfolging'
import type { Kassererrad } from './rate'

const rad = (maned: string, retur_antall = 4, ekstra: Partial<Kassererrad> = {}): Kassererrad => ({ stasjon_id: 'a', kasserer_nr: '12', maned, dager: 12, bonger: 400, omsetning_kr: 40000, retur_kr: 400, retur_antall, makulert_kr: 20000, makulert_antall: 80, slettet_kr: 0, slettet_antall: 0, ulike_navn: 1, navn: 'A', ...ekstra })
const tidligere = [rad('2026-01-01'), rad('2026-02-01'), rad('2026-03-01')]
test('returer vurderes separat fra makulering og uten fremtid eller annen stasjon i referansen', () => {
  const [funn] = returOppfolging([...tidligere, rad('2026-04-01', 16), rad('2026-05-01', 100), rad('2026-02-01', 100, { stasjon_id: 'b' })], '2026-04-01')
  expect(funn.normal).toBe(1)
  expect(funn.rate).toBe(4)
  expect(funn.utslag).toBe(true)
})
test('liten vakt, svak historikk og få returer gir ikke utslag', () => {
  expect(returOppfolging([...tidligere, rad('2026-04-01', 4, { bonger: 20 })], '2026-04-01')[0].utslag).toBe(false)
  expect(returOppfolging([tidligere[0], rad('2026-04-01', 16)], '2026-04-01')[0].utslag).toBe(false)
  expect(returOppfolging([...tidligere, rad('2026-04-01', 4, { bonger: 100 })], '2026-04-01')[0].utslag).toBe(false)
})
test('endrede navn stopper personrettet vurdering; systemnumre utelates', () => {
  expect(returOppfolging([...tidligere, rad('2026-04-01', 16, { navn: 'B' })], '2026-04-01')[0].tvetydig).toBe(true)
  expect(returOppfolging([...tidligere, rad('2026-04-01', 16, { navn: 'B' })], '2026-04-01')[0].utslag).toBe(false)
  expect(returOppfolging([rad('2026-04-01', 16, { kasserer_nr: '999999' })], '2026-04-01')).toEqual([])
})
test('referansen er volumvektet og nullhistorikk krever fortsatt absolutt økning', () => {
  const historikk = [rad('2026-01-01', 0), rad('2026-02-01', 0), rad('2026-03-01', 0)]
  expect(returOppfolging([...historikk, rad('2026-04-01', 5, { bonger: 1000 })], '2026-04-01')[0].utslag).toBe(false)
  expect(returOppfolging([...historikk, rad('2026-04-01', 5)], '2026-04-01')[0].utslag).toBe(true)
  expect(returOppfolging([rad('2026-01-01', 10, { bonger: 100 }), rad('2026-02-01', 0, { bonger: 900 }), rad('2026-03-01', 0), rad('2026-04-01', 16)], '2026-04-01')[0].normal).toBeCloseTo(1000 / 1400)
})
