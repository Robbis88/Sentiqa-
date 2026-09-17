import { beforeEach, describe, expect, test, vi } from 'vitest'
const mock = vi.hoisted(() => ({ bruker: { retailerId: 'retailer-a', rolle: 'butikksjef' }, rpc: vi.fn(), upsert: vi.fn() }))
vi.mock('@/lib/auth/dal', () => ({ hentInnloggetBruker: async () => mock.bruker }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: async () => ({ rpc: mock.rpc, from: () => ({ upsert: mock.upsert }) }) }))
import { publiser, setLinje, setNotat, setProsent } from './handlinger'
const linjer = ['Bolle', 'Baguett'].map((varenavn) => ({ varenavn, varegruppe_kode: '1201', varegruppe_navn: 'Bakevarer', foreslatt: 5, planlagt: 6, start_antall: 2, ekskludert: false }))
beforeEach(() => {
  mock.bruker.rolle = 'butikksjef'
  mock.rpc.mockReset().mockResolvedValue({ error: null })
  mock.upsert.mockReset().mockResolvedValue({ error: null, count: 1 })
})
describe('hele planen publiseres gjennom én atomisk RPC', () => {
  test('urørte produkter og notat sendes samlet, uten produksjonsregistrering', async () => {
    expect(await publiser('station-a', '2026-09-19', linjer, '  Lag først boller  ')).toEqual({ ok: true })
    expect(mock.rpc).toHaveBeenCalledWith('publiser_produksjonsplan', {
      p_stasjon: 'station-a', p_dato: '2026-09-19', p_linjer: linjer, p_notat: 'Lag først boller',
    })
    expect(mock.upsert).not.toHaveBeenCalled()
    expect(mock.rpc.mock.calls[0][1].p_linjer.every((l: Record<string, unknown>) => !('lagd_hittil' in l))).toBe(true)
  })
  test('gjenpublisering inkluderer delvis redigert plan og ekskluderte produkter', async () => {
    const endret = [{ ...linjer[0], planlagt: 8 }, { ...linjer[1], ekskludert: true }]
    await publiser('station-a', '2026-09-19', linjer, '')
    await publiser('station-a', '2026-09-19', endret, 'Nytt notat')
    expect(mock.rpc.mock.calls[1][1].p_linjer).toEqual(endret)
    expect(mock.upsert).not.toHaveBeenCalled()
  })
  test('RPC-feil kan ikke gi publisert kvittering', async () => {
    mock.rpc.mockResolvedValue({ error: { message: 'transaction failed' } })
    expect(await publiser('station-a', '2026-09-19', linjer, '')).toMatchObject({ ok: false })
  })
  test('nettbrett og ugyldig start/dupliserte produkter avvises før DB-kall', async () => {
    mock.bruker.rolle = 'butikkbruker_tablet'
    expect((await publiser('station-a', '2026-09-19', linjer, '')).ok).toBe(false)
    await expect(setLinje({ ...linjer[0], stasjon_id: 'station-a', dato: '2026-09-19' })).rejects.toThrow('Kun leder')
    mock.bruker.rolle = 'butikksjef'
    expect((await publiser('station-a', '2026-09-19', [{ ...linjer[0], start_antall: 7 }], '')).ok).toBe(false)
    expect((await publiser('station-a', '2026-09-19', [linjer[0], linjer[0]], '')).ok).toBe(false)
    expect(mock.rpc).not.toHaveBeenCalled()
    expect(mock.upsert).not.toHaveBeenCalled()
  })
  test('lederlagring krever bekreftet berørt rad og gyldig start', async () => {
    mock.upsert.mockResolvedValue({ error: null, count: 0 })
    await expect(setLinje({ ...linjer[0], stasjon_id: 'station-a', dato: '2026-09-19' })).rejects.toThrow('Ingen rader')
    await expect(setNotat('station-a', '2026-09-19', 'Notat')).rejects.toThrow('Ingen rader')
    await expect(setProsent('station-a', '*', { start: 50, margin: 10 })).rejects.toThrow('Ingen rader')
    await expect(setLinje({ ...linjer[0], start_antall: 7, stasjon_id: 'station-a', dato: '2026-09-19' })).rejects.toThrow('Startpartiet')
  })
})
