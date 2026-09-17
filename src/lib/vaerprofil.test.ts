import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentVaerKoeff } from './vaerprofil'

function klient(data: unknown[] | null, error: { message: string } | null = null) {
  const q = { select: () => q, eq: () => q, limit: async () => ({ data, error }) }
  return { from: () => q } as unknown as SupabaseClient
}

describe('værprofil: fravær skilles fra ukjent', () => {
  it('en bekreftet tom profil kan bruke standardmodellen', async () => {
    expect((await hentVaerKoeff(klient([]), 'stasjon', 'varegruppe')).size).toBe(0)
  })
  it('bevarer lærte koeffisienter', async () => {
    const m = await hentVaerKoeff(klient([{ kode: 'a', temp_korr: 0.4, nedbor_korr: null }]), 'stasjon', 'varegruppe')
    expect(m.get('a')).toEqual({ temp: 0.4, nedbor: null })
  })
  it('databasefeil og manglende svar blir ikke en tom profil', async () => {
    await expect(hentVaerKoeff(klient(null, { message: 'timeout' }), 'stasjon', 'varegruppe')).rejects.toThrow('timeout')
    await expect(hentVaerKoeff(klient(null), 'stasjon', 'varegruppe')).rejects.toThrow('Mangler svar')
  })
  it('et svar på radtaket kan ikke brukes som komplett profil', async () => {
    await expect(hentVaerKoeff(klient(Array(1000).fill({ kode: 'a', temp_korr: 0.4, nedbor_korr: null })), 'stasjon', 'varegruppe')).rejects.toThrow()
  })
})
