import { describe, expect, it } from 'vitest'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentVaresok } from './forventetverktoy'
import { slaaOpp, sokefilter, type Varerad } from '@/lib/forventet/varesok'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>
describe('varesøk må se alle kandidatene', () => {
  it('andre kandidat etter PostgREST-taket gjør søket tvetydig', async () => {
    const rader: Varerad[] = Array.from({ length: 1001 }, (_, i) => ({
      ean: i < 1000 ? '5000112651881' : '5000112691719', varenavn: 'COCA-COLA ZERO',
      dato: '2026-09-16', stasjon_id: 'dale', antall: 1,
      varegruppe_kode: '1402', varegruppe_navn: 'BRUS', avdeling_navn: 'KALD DRIKKE',
    }))
    const ordnet: string[] = []
    const sider: number[][] = []
    const q = {
      select: () => q, in: () => q, gte: () => q, lte: () => q,
      ilike: () => q, eq: () => q, order: (kol: string) => { ordnet.push(kol); return q },
      range: async (fra: number, til: number) => { sider.push([fra, til]); return { data: rader.slice(fra, til + 1), error: null } },
    }
    const klient = { from: () => q } as unknown as Klient
    const resultat = await hentVaresok(klient, ['dale'], 'Coca Cola Zero', '2026-09-17')
    expect(resultat).toHaveLength(1001)
    expect(slaaOpp(resultat, 'Coca Cola Zero').slag).toBe('flere')
    expect(sider).toEqual([[0, 999], [1000, 1999]])
    expect(ordnet.slice(0, 4)).toEqual(['dato', 'stasjon_id', 'ean', 'retailer_id'])
  })
  it('databasefeil er ukjent svar, aldri ingen varematch', async () => {
    const q = { select: () => q, in: () => q, gte: () => q, lte: () => q, ilike: () => q, order: () => q,
      range: async () => ({ data: null, error: { message: 'timeout' } }) }
    await expect(hentVaresok({ from: () => q } as unknown as Klient, ['dale'], 'Cola', '2026-09-17')).rejects.toThrow('timeout')
  })
  it('interne varekoder er kildenøkler, og filteret tåler tegnsetting', () => {
    expect(sokefilter('4001')).toEqual({ ean: '4001' })
    expect(sokefilter('Coca-Cola Zero')).toEqual({ navn: '%c%o%c%a%' })
    expect(sokefilter('!!!')).toBeNull()
  })
})
