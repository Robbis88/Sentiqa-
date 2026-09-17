import type { lagSupabaseServerKlient } from '@/lib/supabase/server'

// =====================================================================
// ALLE TREFF-RADENE FOR ÉN STASJON
// =====================================================================
//
// Trukket ut av `page.tsx` for å kunne måles. Løkka, sidestørrelsen og
// stoppvilkåret er de samme som sto der.
// =====================================================================

export type TreffRad = {
  type: 'produksjonsplan' | 'salgsprognose'
  dato: string
  kategori: string
  forventet: number
  faktisk: number
  treff: number
}

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export const SIDE = 1000
export const MAKS_SIDER = 20

export async function hentTreff(supabase: Klient, stasjonId: string): Promise<TreffRad[]> {
  const rader: TreffRad[] = []
  for (let side = 0; side < MAKS_SIDER; side++) {
    const { data, error } = await supabase
      .from('prognose_treff').select('type, dato, kategori, forventet, faktisk, treff')
      .eq('stasjon_id', stasjonId)
      // `dato` alene er ikke unik: noekkelen er
      // `unique (stasjon_id, type, dato, kategori)`, og stasjonen er
      // laast med .eq(). Én dato bærer én rad per (type, kategori), saa
      // `.range()` over `dato` alene mister rader i stillhet.
      .order('dato')
      .order('type')
      .order('kategori')
      .range(side * SIDE, side * SIDE + SIDE - 1)
      .overrideTypes<TreffRad[]>()
    if (error || !data || data.length === 0) break
    rader.push(...data)
    if (data.length < SIDE) break
  }
  return rader
}
