import { beforeEach, describe, expect, test, vi } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import type { Kassererrad } from '@/lib/kasserer/rate'
const mock = vi.hoisted(() => ({ rader: [] as Kassererrad[] }))
vi.mock('@/lib/auth/dal', () => ({ hentInnloggetBruker: async () => ({ rolle: 'retailer_admin' }) }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: async () => ({ from: () => ({ select: () => ({ is: () => ({ order: () => ({ overrideTypes: async () => ({ data: [{ id: 'a', butikknummer: '101', navn: 'Første butikk' }, { id: 'b', butikknummer: '102', navn: 'Andre butikk' }], error: null }) }) }) }) }) }) }))
vi.mock('@/lib/stasjonskontekst', () => ({ husketStasjon: async () => null }))
vi.mock('@/lib/paginer', () => ({ hentAlt: async () => mock.rader }))
vi.mock('../ai-kontekst', () => ({ AiKontekst: () => null }))
vi.mock('@/components/ui/periode', () => ({ Maanedsvelger: () => null }))
import KassererSide from './page'
function rad(stasjon_id: string, maned: string, navn: string | null, retur_antall: number): Kassererrad {
  return { stasjon_id, kasserer_nr: '29', maned, dager: 20, bonger: 1000, omsetning_kr: 100000, retur_kr: 1500, retur_antall, makulert_kr: 100, makulert_antall: 1, slettet_kr: 50, slettet_antall: 1, navn, ulike_navn: navn ? 1 : 0 }
}
function historikk(stasjon: string, navn: string | null) {
  return ['2026-06-01', '2026-07-01', '2026-08-01'].map((m) => rad(stasjon, m, navn, 2))
}
async function varsler() {
  const html = renderToStaticMarkup(await KassererSide({ searchParams: Promise.resolve({ maned: '2026-09-01' }) }))
  return html.slice(html.indexOf('Returer som bør undersøkes'), html.indexOf('Hvordan velges returavvikene?'))
}
beforeEach(() => { mock.rader = [] })
describe('returvarsel bruker bare importnavn fra samme stasjon og valgt måned', () => {
  test('kjent navn vises med kassenummer og norsk desimaltall', async () => {
    mock.rader = [...historikk('a', 'Maja Eksempel'), rad('a', '2026-09-01', 'Maja Eksempel', 110.64)]
    const html = await varsler()
    expect(html).toContain('Maja Eksempel (kassenummer 29): økning i returer')
    expect(html).toContain('Registrert returantall: 110,64')
    expect(html).toContain('Undersøk returkvitteringene')
    expect(html).toContain('bekreft at registreringene stemmer')
    expect(html).not.toContain('avklar hvem')
  })
  test('ukjent månedsnavn låner ikke navn fra historikk eller annen stasjon', async () => {
    mock.rader = [...historikk('a', 'Historisk navn'), rad('a', '2026-09-01', null, 50), ...historikk('b', 'Annet navn'), rad('b', '2026-09-01', 'Annet navn', 50)]
    const html = await varsler()
    expect(html).toContain('101 Første butikk · kassenummer 29: økning i returer')
    expect(html).not.toContain('101 Første butikk · Historisk navn')
    expect(html).not.toContain('101 Første butikk · Annet navn')
    expect(html).toContain('102 Andre butikk · Annet navn (kassenummer 29)')
  })
  test('flere historikknavn utløser fortsatt ingen personvarsling', async () => {
    mock.rader = [...historikk('a', 'Første navn'), rad('a', '2026-09-01', 'Andre navn', 50)]
    const html = await varsler()
    expect(html).not.toContain('økning i returer')
    expect(html).toContain('Ingen utslag')
  })
})
