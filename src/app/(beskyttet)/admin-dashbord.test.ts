import { beforeEach, expect, it, vi } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
const fake = vi.hoisted(() => ({ varsler: vi.fn(), linjer: [] as unknown[] }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: vi.fn() }))
vi.mock('@/lib/regnskap-varsler', () => ({ hentRegnskapVarsler: fake.varsler }))
vi.mock('@/lib/ukerapport', () => ({ hentEllerLagUkerapport: async () => [] }))
import { samleData } from './admin-dashbord'
const db = { from(tabell: string) {
  let select = ''
  const q: unknown = new Proxy({}, { get(_t, felt) {
    if (felt === 'then') {
      const data = tabell === 'stasjoner' ? [{ id: 's', navn: 'Butikk', butikknummer: '0001' }]
        : tabell === 'regnskapslinjer' ? select === 'periode' ? { periode: '2026-08-01' }
          : select.includes('stasjon_id') ? fake.linjer : [] : []
      const p = Promise.resolve({ data, error: null })
      return p.then.bind(p)
    }
    return (...args: string[]) => { if (felt === 'select') select = args[0]; return q }
  } })
  return q
} } as unknown as SupabaseClient
beforeEach(() => { vi.clearAllMocks(); fake.linjer = []; fake.varsler.mockResolvedValue([]) })
it('regnskapsfeil gir eksplisitt ufullstendig oversikt, aldri grønn friskmelding', async () => {
  fake.varsler.mockRejectedValue(new Error('regnskap_sum feilet: timeout'))
  const logg = vi.spyOn(console, 'error').mockImplementation(() => {})
  const d = await samleData(db, 'r', '2026-09-18')
  expect(d.feil).toContain('regnskap_sum feilet')
  expect(d.driftsstatus).toEqual([])
  logg.mockRestore()
})
it('en vellykket måling uten varsler beholder grønn status', async () => {
  const d = await samleData(db, 'r', '2026-09-18')
  expect(d.feil).toBeNull()
  expect(d.driftsstatus[0]).toMatchObject({ status: 'gronn', grunn: 'Alt i rute' })
})
it('ukjent regnskap forblir ukjent gjennom avdelings- og totalsummering', async () => {
  fake.linjer = [
    { stasjon_id: 's', seksjon: 'omsetning', kode: '120', regnskap: null, budsjett: 100 },
    { stasjon_id: 's', seksjon: 'omsetning', kode: '130', regnskap: 500, budsjett: 100 },
  ]
  const d = await samleData(db, 'r', '2026-09-18')
  expect(d.rangRader[0].oms['120'].regnskap).toBeNull()
  expect(d.rangRader[0].oms.total.regnskap).toBeNull()
})
