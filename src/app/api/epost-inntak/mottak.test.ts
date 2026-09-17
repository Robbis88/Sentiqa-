import { beforeEach, expect, it, vi } from 'vitest'
import type { NextRequest } from 'next/server'

const fake = vi.hoisted(() => ({ svar: [] as { data: unknown; error: unknown }[], behandle: vi.fn(), upload: vi.fn(), remove: vi.fn() }))
vi.mock('@/lib/env', () => ({ env: { EPOST_INNTAK_SECRET: 'test-hemmelighet' } }))
vi.mock('@/lib/import/kjerne', () => ({ behandleJobbKjerne: fake.behandle }))
vi.mock('@/lib/supabase/admin', () => ({ lagSupabaseAdminKlient: () => ({
  from() {
    const resultat = fake.svar.shift()
    if (!resultat) throw new Error('Testen mangler databasesvar')
    const q: unknown = new Proxy({}, { get(_t, felt) {
      if (felt === 'then') return Promise.resolve(resultat).then.bind(Promise.resolve(resultat))
      return () => q
    } })
    return q
  },
  storage: { from: () => ({ upload: fake.upload, remove: fake.remove }) },
}) }))
import { POST } from './route'

function req() {
  return new Request('https://test.invalid/api/epost-inntak', { method: 'POST',
    headers: { 'content-type': 'application/json', 'x-inntak-secret': 'test-hemmelighet' },
    body: JSON.stringify({ To: 'kjede@test.invalid', From: 'rapport@test.invalid',
      Attachments: [{ Name: 'rapport.csv', Content: 'dGVzdA==' }] }),
  }) as NextRequest
}
const kjede = { data: { id: 'kjede', avsender_allowlist: ['rapport@test.invalid'] }, error: null }
const fil = { data: { id: 'fil' }, error: null }
const tom = { data: [], error: null }

beforeEach(() => {
  fake.svar.length = 0
  vi.clearAllMocks()
  fake.upload.mockResolvedValue({ error: null })
  fake.remove.mockResolvedValue({ error: null })
})

it('jobbinnsettingsfeil gir retrybar 503 og ingen mottatt-telling', async () => {
  fake.svar.push(kjede, fil, tom, { data: null, error: { message: 'DB utilgjengelig' } })
  const svar = await POST(req())
  expect(svar.status).toBe(503)
  expect(await svar.json()).toMatchObject({ ok: false, mottatt: 0 })
  expect(fake.behandle).not.toHaveBeenCalled()
})

it('retry reparerer en eksisterende SHA-råfil uten jobb og behandler den', async () => {
  fake.svar.push(kjede, { data: null, error: { code: '23505', message: 'dublett' } },
    { data: [{ id: 'fil' }], error: null }, tom, { data: { id: 'nyjobb' }, error: null })
  const svar = await POST(req())
  expect(svar.status).toBe(200)
  expect(await svar.json()).toMatchObject({ ok: true, mottatt: 1 })
  expect(fake.behandle).toHaveBeenCalledWith(expect.anything(), 'kjede', 'nyjobb')
})

it('bekreftet duplikat er 200 og starter ikke eksisterende jobb igjen', async () => {
  fake.svar.push(kjede, { data: null, error: { code: '23505', message: 'dublett' } },
    { data: [{ id: 'fil' }], error: null }, { data: [{ id: 'gammeljobb' }], error: null })
  const svar = await POST(req())
  expect(svar.status).toBe(200)
  expect(await svar.json()).toMatchObject({ ok: true, mottatt: 0 })
  expect(fake.behandle).not.toHaveBeenCalled()
})

it('Storage-feil kan ikke se ut som ferdig mottak hos workeren', async () => {
  fake.svar.push(kjede)
  fake.upload.mockResolvedValue({ error: { message: 'Storage utilgjengelig' } })
  const svar = await POST(req())
  expect(svar.status).toBe(503)
  expect(await svar.json()).toMatchObject({ ok: false, mottatt: 0 })
})
