import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { OsloNaa } from '@/lib/rutineskjema'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { skiftkoe, vaktenNaa, type Skift, type Rutine, type Skiftkoe } from './skiftkoe'

/** Dagens arbeidskoe trenger vaktdatoene, aldri nitti dagers statistikk. */
export async function hentSkiftkoe(supabase: SupabaseClient, stasjonId: string, naa: OsloNaa): Promise<Skiftkoe> {
  const [skjemaSvar, rutineSvar] = await Promise.all([
    supabase.from('rutineskjemaer').select('id, ukedager, tid_start, tid_slutt')
      .eq('stasjon_id', stasjonId).eq('aktiv', true).is('slettet_tid', null).limit(1000),
    supabase.from('rutiner').select('id, skjema_id, ukedager, opprettet_dato')
      .eq('stasjon_id', stasjonId).not('skjema_id', 'is', null).is('slettet_tid', null).limit(1000),
  ])
  const vakter = vaktenNaa(maaVaereHele(skjemaSvar, 'rutineskjemaene') as Skift[], naa)
  const rutiner = maaVaereHele(rutineSvar, 'rutinene') as Rutine[]
  const tom = skiftkoe(vakter, rutiner, new Map())
  if (!tom.vaktdatoer.length) return tom

  const svar = await supabase.from('rutine_utforinger').select('rutine_id, dato')
    .eq('stasjon_id', stasjonId).in('dato', tom.vaktdatoer).limit(1000)
  const gjort = new Map<string, Set<string>>()
  for (const u of maaVaereHele(svar, 'utførte rutiner') as { rutine_id: string; dato: string }[]) {
    const sett = gjort.get(u.dato) ?? new Set<string>()
    sett.add(u.rutine_id)
    gjort.set(u.dato, sett)
  }
  return skiftkoe(vakter, rutiner, gjort)
}
