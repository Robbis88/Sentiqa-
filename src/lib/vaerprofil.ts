import type { SupabaseClient } from '@supabase/supabase-js'
import type { VaerKoeff } from './produksjonsplan'

// Henter lært vær-korrelasjon pr kategori (mig 0070). niva='varegruppe' for
// produksjonsplanen (antall), 'avdeling' for salgsprognosen (omsetning).
// Tom map → motoren faller tilbake på regex-klassifiseringen.
export async function hentVaerKoeff(
  supabase: SupabaseClient,
  stasjonId: string,
  niva: 'avdeling' | 'varegruppe',
): Promise<Map<string, VaerKoeff>> {
  const { data } = await supabase
    .from('kategori_vaerprofil').select('kode, temp_korr, nedbor_korr')
    .eq('stasjon_id', stasjonId).eq('niva', niva)
  const m = new Map<string, VaerKoeff>()
  for (const r of (data ?? []) as { kode: string; temp_korr: number | null; nedbor_korr: number | null }[]) {
    m.set(r.kode, { temp: r.temp_korr, nedbor: r.nedbor_korr })
  }
  return m
}
