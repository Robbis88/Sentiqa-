import { beforeEach, expect, it, vi } from 'vitest'
const fake = vi.hoisted(() => ({ svar: [] as { data?: unknown; error: unknown; count?: number | null }[], send: vi.fn(), ranges: [] as number[] }))
vi.mock('@/lib/kontrollrom', () => ({ rapporterBruk: fake.send }))
vi.mock('@/lib/supabase/admin', () => ({ lagSupabaseAdminKlient: () => ({ from() {
  const resultat = fake.svar.shift()
  if (!resultat) throw new Error('Fixture missing')
  const q: unknown = new Proxy({}, { get(_t, felt) {
    if (felt === 'then') return Promise.resolve(resultat).then.bind(Promise.resolve(resultat))
    return (...args: unknown[]) => { if (felt === 'range') fake.ranges.push(args[0] as number); return q }
  } })
  return q
} }) }))
import { GET } from './route'
import { beregnAbonnement } from '@/lib/pris'
const req = () => new Request('https://test.invalid', { headers: { authorization: 'Bearer test-cron' } })
const kjede = { id: 'kjede', navn: 'Kjede', faktura_epost: null, premium_avtalevokter: false }
const count = (n: number) => ({ error: null, count: n })
const rows = (data: unknown[]) => ({ data, error: null })
beforeEach(() => { fake.svar.length = 0; fake.ranges.length = 0; vi.clearAllMocks(); vi.stubEnv('CRON_SECRET', 'test-cron'); fake.send.mockResolvedValue(true) })
it('sender aldri fullsynk ved databasefeil', async () => {
  fake.svar.push(count(1), count(1), { data: null, error: { message: 'timeout' } })
  expect((await GET(req())).status).toBe(503)
  expect(fake.send).not.toHaveBeenCalled()
})
it('stopper stille trunkering mot eksakt antall', async () => {
  fake.svar.push(count(2), count(1), rows([kjede]), rows([{ id: 's', retailer_id: 'kjede' }]))
  expect((await GET(req())).status).toBe(503)
  expect(fake.send).not.toHaveBeenCalled()
})
it('henter neste side og regner med alle stasjonene', async () => {
  const stasjoner = Array.from({ length: 1000 }, (_, n) => ({ id: `s${n}`, retailer_id: 'kjede' }))
  fake.svar.push(count(1), count(1001), rows([kjede]), rows(stasjoner), rows([{ id: 's1000', retailer_id: 'kjede' }]))
  expect((await GET(req())).status).toBe(200)
  expect(fake.ranges).toEqual([0, 0, 1000])
  expect(fake.send).toHaveBeenCalledOnce()
  expect(fake.send.mock.calls[0][0].abonnement).toHaveLength(1)
  expect(fake.send.mock.calls[0][0].abonnement[0].belop).toBe(beregnAbonnement(1001, false).maaned)
})
it('avviser dubletter selv når antallet stemmer', async () => {
  fake.svar.push(count(1), count(2), rows([kjede]), rows([{ id: 's', retailer_id: 'kjede' }, { id: 's', retailer_id: 'kjede' }]))
  expect((await GET(req())).status).toBe(503)
  expect(fake.send).not.toHaveBeenCalled()
})
it('tellefeil og ukjent antall stopper før sending', async () => {
  fake.svar.push({ error: null, count: null }, count(1))
  expect((await GET(req())).status).toBe(503)
  expect(fake.send).not.toHaveBeenCalled()
})
it('feil på en senere side sender aldri delmengden', async () => {
  fake.svar.push(count(1), count(1001), rows([kjede]),
    rows(Array.from({ length: 1000 }, (_, n) => ({ id: `s${n}`, retailer_id: 'kjede' }))),
    { data: null, error: { message: 'side to feilet' } })
  expect((await GET(req())).status).toBe(503)
  expect(fake.send).not.toHaveBeenCalled()
})
