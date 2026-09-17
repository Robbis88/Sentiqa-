import type { SupabaseClient } from '@supabase/supabase-js'
import { maaVaereHele } from './supabase/datobolker'

export type Hullrad = {
  datasett: string; datasett_navn: string; butikknummer: string; stasjon_navn: string
  hull: number; hull_hverdag: number; forste: string; siste: string; datoer: string[]
}

export async function hentDatadekning(supabase: SupabaseClient, start: string, datasett: readonly string[]) {
  const [datoer, hullSvar] = await Promise.all([
    Promise.all(datasett.map(async (key) => {
      const svar = await supabase.from('v_datodekning').select('dato')
        .eq('datasett', key).gte('dato', start).limit(1000).overrideTypes<{ dato: string }[]>()
      if (!svar.error && !svar.data) throw new Error(`Mangler datadekning for ${key}.`)
      return [key, new Set(maaVaereHele(svar, 'datadekning').map((r) => r.dato))] as const
    })),
    supabase.from('v_datohull')
      .select('datasett, datasett_navn, butikknummer, stasjon_navn, hull, hull_hverdag, forste, siste, datoer')
      .order('hull_hverdag', { ascending: false }).limit(1000).overrideTypes<Hullrad[]>(),
  ])
  if (!hullSvar.error && !hullSvar.data) throw new Error('Mangler måling av datohull.')
  return { settPer: new Map(datoer), hull: maaVaereHele(hullSvar, 'datohull') }
}
