import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { byggLonnskost, type Kontolinje, type Maanedslonn } from './maaned'
import { BP_LONNSKODER, ukjenteLonnskoder } from './bp'

// =====================================================================
// Henter lønnskosten for én stasjon, måned for måned.
//
// ÉN SPØRRING, TRE SEKSJONER. `driftskostnader` bærer avlagte måneder,
// `bp_kostnad` de åpne, `nokkeltall` timene. To kall mot samme tabell
// kunne dessuten gitt to ulike svar hvis en import lander imellom.
//
// STASJONEN FILTRERES I SPØRRINGEN, ikke etterpå. RLS gir butikksjefen
// sine egne stasjoner og eieren kjeden; et valg her er en innsnevring
// av det, aldri en utvidelse.
// =====================================================================

export type Lonnsbilde = {
  maaneder: Maanedslonn[]
  /** BP-personalkoder ingen har tatt stilling til. Skal være tom. */
  ukjenteKoder: string[]
}

export async function hentLonnskost(
  supabase: SupabaseClient,
  stasjonId: string,
  fraOgMed: string,
): Promise<Lonnsbilde> {
  const { data } = await supabase
    .from('regnskapslinjer')
    .select('periode, seksjon, kode, post, regnskap, budsjett')
    .eq('stasjon_id', stasjonId)
    .gte('periode', fraOgMed)
    .in('seksjon', ['driftskostnader', 'bp_kostnad', 'nokkeltall'])
    .is('slettet_tid', null)
    .limit(20000)
    .overrideTypes<Kontolinje[]>()

  const linjer = data ?? []
  return {
    maaneder: byggLonnskost(linjer, BP_LONNSKODER),
    ukjenteKoder: ukjenteLonnskoder(
      linjer.filter((l) => l.seksjon === 'bp_kostnad' && l.kode).map((l) => l.kode!),
    ),
  }
}
