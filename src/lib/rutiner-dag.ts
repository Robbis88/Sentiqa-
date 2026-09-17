import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { rutinerForDato, type Rutinerad } from './rutineskjema'
import { maaVaereHele } from './supabase/datobolker'

/** Hele rutinedøgnet etter vaktenes startdato, ikke bare vakten som pågår. */
export function tellDagRutiner(
  skjemaer: { id: string; ukedager: number[] }[],
  rutiner: Rutinerad[],
  utforinger: { rutine_id: string; dato: string }[],
  dato: string,
) {
  const forventet = rutinerForDato(rutiner, new Map(skjemaer.map(s => [s.id, s.ukedager])), dato)
  const gjort = new Set(utforinger.filter(u => u.dato === dato).map(u => u.rutine_id))
  return { totalt: forventet.length, utfort: forventet.filter(id => gjort.has(id)).length }
}

export async function hentDagRutiner(supabase: SupabaseClient, dato: string, stasjonId?: string) {
  const paaStasjon = <T,>(q: T): T => stasjonId
    ? (q as unknown as { eq: (kolonne: string, verdi: string) => T }).eq('stasjon_id', stasjonId) : q
  const [skjema, rutiner, gjort] = await Promise.all([
    paaStasjon(supabase.from('rutineskjemaer').select('id, ukedager').eq('aktiv', true).is('slettet_tid', null)).limit(1000),
    paaStasjon(supabase.from('rutiner').select('id, skjema_id, ukedager, opprettet_dato').is('slettet_tid', null)).limit(1000),
    paaStasjon(supabase.from('rutine_utforinger').select('rutine_id, dato').eq('dato', dato)).limit(1000),
  ])
  return tellDagRutiner(
    maaVaereHele(skjema, 'dagens rutineskjemaer') as { id: string; ukedager: number[] }[],
    maaVaereHele(rutiner, 'dagens rutiner') as Rutinerad[],
    maaVaereHele(gjort, 'dagens utføringer') as { rutine_id: string; dato: string }[], dato,
  )
}
