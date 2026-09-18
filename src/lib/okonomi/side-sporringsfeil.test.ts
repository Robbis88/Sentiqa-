import { afterEach, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({ feil: '', svinn: false, klient: {} as { from: (tabell: string) => unknown } }))
vi.mock('@/lib/auth/dal', () => ({ hentInnloggetBruker: async () => ({ rolle: 'retailer_admin' }) }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: async () => mock.klient }))
vi.mock('@/lib/stasjonskontekst', () => ({ husketStasjon: async () => 'stasjon-a' }))
vi.mock('@/lib/svinn/hent-budsjett', () => ({ hentSvinnbudsjett: async () => null }))
vi.mock('@/app/(beskyttet)/ai-kontekst', () => ({ AiKontekst: () => null }))
import SvinnSide from '@/app/(beskyttet)/svinn/page'
import BusinessplanSide from '@/app/(beskyttet)/businessplan/page'

mock.klient.from = (tabell) => {
  const data = tabell === 'stasjoner' ? [{ id: 'stasjon-a', navn: 'A', butikknummer: '1' }]
    : tabell === 'v_bilvask_abonnement' ? null
    : tabell === 'v_svinn_maaned' && mock.svinn ? [{ stasjon_id: 'stasjon-a', maned: '2026-09-01', gruppe_kode: '1', gruppe_navn: 'Mat', koblet: true, svinn_kr: 10, svinn_antall: 1, svinn_linjer: 1, varekost_kr: 100, omsetning_kr: 200, solgt_antall: 10 }] : []
  const svar = { data, error: mock.feil === tabell ? { message: 'kontrollert queryfeil' } : null }
  const q: Record<string, unknown> = { then: (ok: (v: unknown) => unknown) => Promise.resolve(svar).then(ok) }
  for (const navn of ['select', 'is', 'order', 'overrideTypes', 'gte', 'eq', 'in', 'limit', 'maybeSingle']) q[navn] = () => q
  return q
}
afterEach(() => { mock.feil = ''; mock.svinn = false })

it.each(['stasjoner', 'v_svinn_maaned', 'v_svinn_dekning', 'v_svinn_vare_maaned'])(
  'lar ikke feil fra %s bli tom svinnvisning', async (tabell) => {
    mock.feil = tabell; mock.svinn = true
    await expect(SvinnSide({ searchParams: Promise.resolve({}) })).rejects.toThrow('kontrollert queryfeil')
  },
)

it.each(['stasjoner', 'v_bp_status_avdeling', 'v_bilvask_abonnement'])(
  'lar ikke feil fra %s bli manglende businessplan eller abonnementsgrunnlag', async (tabell) => {
    mock.feil = tabell
    await expect(BusinessplanSide({ searchParams: Promise.resolve({}) })).rejects.toThrow('kontrollert queryfeil')
  },
)

it('beholder legitim tomtilstand når spørringene lykkes uten data', async () => {
  await expect(SvinnSide({ searchParams: Promise.resolve({}) })).resolves.toBeDefined()
  await expect(BusinessplanSide({ searchParams: Promise.resolve({}) })).resolves.toBeDefined()
})
