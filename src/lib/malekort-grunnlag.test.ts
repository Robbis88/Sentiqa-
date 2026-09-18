import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { beregnMalekort, type Malekort } from './malekort'
import { egneMaalinger, maalegrunnlag } from './malekort-oppsummering'

const kort: Malekort = { id: 'k', navn: 'Salg', metrikk: 'omsetning', normalisering: 'vekst_pst', periode: 'uke', retning: 'hoy', krev_fullstendig_periode: false, anonymiser: false }
const butikker = [{ id: 'a', navn: 'A' }, { id: 'b', navn: 'B' }]
function klient(naa: object[], fjor: object[], kunder: object[] = [], feil = false) {
  let salgsKall = 0
  return {
    from: () => ({ select: () => ({ order: () => ({ limit: () => ({ maybeSingle: async () => ({ data: { dato: '2026-09-13' }, error: feil ? { message: 'timeout' } : null }) }) }) }) }),
    rpc: async (navn: string) => ({ data: navn === 'beregn_malekort_salg' ? (salgsKall++ === 0 ? naa : fjor) : kunder, error: null }),
  } as unknown as SupabaseClient
}
describe('målekort ukjent grunnlag', () => {
  it('rangerer ikke ukjent fjorår over ekte negativ vekst', async () => {
    const r = await beregnMalekort(klient([{ stasjon_id: 'a', omsetning: 100 }, { stasjon_id: 'b', omsetning: 95 }], [{ stasjon_id: 'b', omsetning: 100 }]), kort, butikker)
    expect(r.klar).toBe(true)
    if (!r.klar) return
    expect(r.rader.map(x => x.stasjonId)).toEqual(['b'])
    expect(r.rader[0].verdi).toBe(-5)
    expect(r.utenGrunnlag?.map(x => x.stasjonId)).toEqual(['a'])
  })
  it('manglende kunder blir ikke null kroner per kunde', async () => {
    const r = await beregnMalekort(klient([{ stasjon_id: 'a', omsetning: 100 }], [], []), { ...kort, normalisering: 'per_kunde' }, butikker.slice(0, 1))
    expect(r.klar && r.rader).toEqual([])
    expect(r.klar && r.utenGrunnlag?.length).toBe(1)
  })
  it('beholder reelt null salg når kundene er kjent', async () => {
    const r = await beregnMalekort(klient([{ stasjon_id: 'a', omsetning: 0 }], [], [{ stasjon_id: 'a', kunder: 10 }]), { ...kort, normalisering: 'per_kunde' }, butikker.slice(0, 1))
    expect(r.klar && r.rader[0].verdi).toBe(0)
  })
  it('propagerer feil i siste salgsdato', async () => {
    await expect(beregnMalekort(klient([], [], [], true), kort, butikker)).rejects.toThrow('timeout')
  })
  it('viser hver butikk og korrekt deltakerantall per kort', () => {
    const r = { klar: true as const, enhet: 'kr' as const, etikett: 'uke', rader: [{ stasjonId: 'a', navn: 'A', verdi: 20, vekstPst: null }, { stasjonId: 'b', navn: 'B', verdi: 10, vekstPst: null }] }
    expect(egneMaalinger(kort, r, new Set(['a', 'b']))).toEqual(['A: 1. plass av 2 på «Salg»', 'B: 2. plass av 2 på «Salg»'])
    expect(egneMaalinger(kort, { ...r, rader: [r.rader[1]] }, new Set(['b']))).toEqual(['B: 1. plass av 1 på «Salg»'])
  })
  it('forklarer normalisering og retning', () => {
    expect(maalegrunnlag(kort)).toBe('Vekst mot i fjor (%) · høyest er best')
    expect(maalegrunnlag({ ...kort, normalisering: 'per_kunde', retning: 'lav' })).toBe('Per kunde · lavest er best')
  })
})
