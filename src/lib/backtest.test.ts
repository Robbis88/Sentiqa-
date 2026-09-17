import { describe, expect, it, vi } from 'vitest'
const fake = vi.hoisted(() => ({ plan: vi.fn((opts: unknown) => { void opts; return { forslag: [{ varegruppeKode: '1201', foreslatt: 10 }], advarsler: [] } }) }))
vi.mock('./ai/periode', () => ({ idagOslo: () => '2026-05-18' }))
vi.mock('./produksjonsplan', async (actual) => ({ ...await actual<typeof import('./produksjonsplan')>(), lagProduksjonsplan: fake.plan }))
import { kjorBacktestForStasjon, skrivTreff, hentKalibrering } from './backtest'
import { hentProduksjonskoder } from './produksjonskoder'

function klient(overstyr: Record<string, unknown[]> = {}) {
  const kall: { tabell: string; filter: [string, unknown][] }[] = []
  const data: Record<string, unknown[]> = {
    retailer_koderegel: [{ retailer_id: 'A', kode: '1201' }, { retailer_id: 'B', kode: '9999' }],
    arrangementer: [{ dato: '2026-05-17', stasjon_id: 'st', faktor: 1.3 }, { dato: '2026-05-17', stasjon_id: 'annen', faktor: 9 }],
    v_butikksalg: ['2026-05-16', '2026-05-17'].map((dato) => ({ dato, varenavn: 'Bolle', varegruppe_kode: '1201', antall: 10 })),
    v_salg_per_avdeling_dag: [],
    vaer: [{ dato: '2025-05-17', temp_maks: 10 }, { dato: '2025-05-18', temp_maks: 99 }, { dato: '2026-05-17', temp_maks: 15 }],
    kategori_vaerprofil: [],
    ...overstyr,
  }
  const db = { from(tabell: string) {
    const filter: [string, unknown][] = []; kall.push({ tabell, filter })
    const q: unknown = new Proxy({}, { get(_t, felt) {
      if (felt === 'then') {
        const tenant = filter.find(([f]) => f === 'retailer_id')?.[1]
        const rader = (data[tabell] ?? []).filter((r) => tabell !== 'retailer_koderegel' || !tenant || (r as { retailer_id: string }).retailer_id === tenant)
        return Promise.resolve({ data: rader, error: null }).then.bind(Promise.resolve({ data: rader, error: null }))
      }
      return (...args: unknown[]) => { if (felt === 'eq') filter.push([String(args[0]), args[1]]); return q }
    } })
    return q
  } } as unknown as Parameters<typeof kjorBacktestForStasjon>[0]
  return { db, kall }
}
describe('service-backtest bruker egen mapping og samme produksjonsdato', () => {
  it.each([null, Number.NaN, Number.POSITIVE_INFINITY])('ukjent eller ugyldig salgsantall %s gir ingen prognose', async (antall) => {
    fake.plan.mockClear()
    const { db } = klient({ v_butikksalg: [{ dato: '2026-05-16', varenavn: 'Bolle', varegruppe_kode: '1201', antall }] })
    await expect(kjorBacktestForStasjon(db, { id: 'st', retailer_id: 'A', butikknummer: '0001', navn: 'Test', stasjonstype: 'bydel', vaerfolsomhet: 0.5, vaerfolsomhet_laert: null }, 1)).rejects.toThrow('gyldig salgsantall')
    expect(fake.plan).not.toHaveBeenCalled()
  })
  it.each([null, Number.NaN, Number.POSITIVE_INFINITY])('ukjent eller ugyldig omsetning %s gir ingen kalibrering', async (omsetning) => {
    fake.plan.mockClear()
    const { db } = klient({ v_salg_per_avdeling_dag: [{ dato: '2026-05-16', avdeling_kode: '20', omsetning }] })
    await expect(kjorBacktestForStasjon(db, { id: 'st', retailer_id: 'A', butikknummer: '0001', navn: 'Test', stasjonstype: 'bydel', vaerfolsomhet: 0.5, vaerfolsomhet_laert: null }, 1)).rejects.toThrow('gyldig omsetning')
    expect(fake.plan).not.toHaveBeenCalled()
  })
  it('manglende eller avvist kalibrering er ikke en legitim tom modell', async () => {
    for (const svar of [{ data: null, error: { message: 'timeout' } }, { data: null, error: null }]) {
      const q: unknown = new Proxy({}, { get(_t, felt) {
        if (felt === 'then') return Promise.resolve(svar).then.bind(Promise.resolve(svar))
        return () => q
      } })
      const db = { from: () => q } as unknown as Parameters<typeof hentKalibrering>[0]
      await expect(hentKalibrering(db, 'st', 'produksjonsplan')).rejects.toThrow()
    }
  })
  it('persistens er ett atomisk kall og feil returneres uten klient-delete', async () => {
    const from = vi.fn()
    const rpc = vi.fn(async () => ({ error: { message: 'innsetting feilet' } }))
    const db = { rpc, from } as unknown as Parameters<typeof skrivTreff>[0]
    await expect(skrivTreff(db, 'st', [], [])).rejects.toThrow('Tidligere gyldig historikk er beholdt')
    expect(rpc).toHaveBeenCalledWith('erstatt_prognosehistorikk', { p_stasjon: 'st', p_treff: [], p_kalibrering: [] })
    expect(from).not.toHaveBeenCalled()
  })
  it('to tenants får hvert sitt produksjonsutvalg uten RLS', async () => {
    const { db } = klient()
    expect(await hentProduksjonskoder(db, 'A')).toEqual({ status: 'mappet', koder: ['1201'] })
    expect(await hentProduksjonskoder(db, 'B')).toEqual({ status: 'mappet', koder: ['9999'] })
  })
  it('17. mai bruker samme helligdag og bare aktuelle arrangementer', async () => {
    fake.plan.mockClear()
    const { db, kall } = klient()
    await kjorBacktestForStasjon(db, { id: 'st', retailer_id: 'A', butikknummer: '0001', navn: 'Test', stasjonstype: 'bydel', vaerfolsomhet: 0.5, vaerfolsomhet_laert: null }, 1)
    expect(fake.plan).toHaveBeenCalledOnce()
    expect(fake.plan.mock.calls[0]?.[0]).toMatchObject({ maalDato: '2026-05-17', fjorHelligdag: '2025-05-17', vaerFjor: { temp_maks: 10 }, arrangementFaktor: 1.3 })
    expect(kall.find((k) => k.tabell === 'retailer_koderegel')?.filter).toContainEqual(['retailer_id', 'A'])
  })
})
