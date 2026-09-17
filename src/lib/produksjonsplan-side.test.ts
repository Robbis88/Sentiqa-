import { afterEach, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({ feilTabell: '', klient: {} as { from: (tabell: string) => unknown }, filter: [] as [string, string, string][] }))
vi.mock('@/lib/auth/dal', () => ({ hentInnloggetBruker: async () => ({ rolle: 'retailer_admin', id: 'eier' }) }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: async () => mock.klient }))
vi.mock('@/lib/stasjonskontekst', () => ({ husketStasjon: async () => 'stasjon-a' }))
vi.mock('@/lib/produksjonskoder', () => ({ hentProduksjonskoder: async () => ({ status: 'mappet', koder: ['1216'] }), IKKE_KONFIGURERT_TEKST: '' }))
vi.mock('@/lib/backtest', () => ({ hentKalibrering: async () => new Map() }))
vi.mock('@/lib/vaerprofil', () => ({ hentVaerKoeff: async () => new Map() }))
vi.mock('@/app/(beskyttet)/produksjonsplan/plan-tabell', () => ({ PlanTabell: () => null }))
vi.mock('@/app/(beskyttet)/produksjonsplan/tablet-plan', () => ({ TabletPlan: () => null }))
vi.mock('@/app/(beskyttet)/produksjonsplan/tablet-morgendag', () => ({ TabletMorgendag: () => null }))
import ProduksjonsplanSide from '@/app/(beskyttet)/produksjonsplan/page'

mock.klient.from = (tabell) => {
  const rows: Record<string, unknown> = {
    stasjoner: [{ id: 'stasjon-a', butikknummer: '1', navn: 'A', stasjonstype: 'bydel', vaerfolsomhet: null, vaerfolsomhet_laert: null }],
    v_butikksalg: null, vaer: null, produksjonsplan_hode: null,
  }
  const svar = { data: rows[tabell] === undefined ? [] : rows[tabell], error: mock.feilTabell === tabell ? { message: 'spørringen feilet' } : null }
  const q: Record<string, unknown> = { then: (ok: (v: unknown) => unknown) => Promise.resolve(svar).then(ok) }
  for (const f of ['select', 'is', 'order', 'limit', 'overrideTypes', 'maybeSingle', 'eq', 'in', 'lt', 'gte', 'lte', 'neq']) {
    q[f] = (...args: string[]) => { if (['eq', 'lt', 'gte', 'lte'].includes(f)) mock.filter.push([tabell, `${f}:${args[0]}`, args[1]]); return q }
  }
  return q
}
afterEach(() => { mock.feilTabell = ''; mock.filter.length = 0 })

it.each(['stasjoner', 'v_butikksalg', 'vaer', 'produksjonsplan_linjer', 'produksjonsplan_hode', 'stasjon_produksjon_innstilling', 'arrangementer'])(
  'viser ikke et forslag fra falske standardverdier når %s feiler', async (tabell) => {
    mock.feilTabell = tabell
    await expect(ProduksjonsplanSide({ searchParams: Promise.resolve({ dato: '2026-04-02' }) })).rejects.toThrow('spørringen feilet')
  },
)

it('henter salg før måldagen og vær på samme navngitte referansehelligdag', async () => {
  await ProduksjonsplanSide({ searchParams: Promise.resolve({ dato: '2026-04-02' }) })
  expect(mock.filter).toContainEqual(['v_butikksalg', 'lt:dato', '2026-04-02'])
  expect(mock.filter).toContainEqual(['vaer', 'eq:dato', '2025-04-17'])
  expect(mock.filter.filter(([tabell, f]) => tabell === 'v_butikksalg' && f === 'lte:dato').every(([, , dato]) => dato < '2026-04-02')).toBe(true)
})
