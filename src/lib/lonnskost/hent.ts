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
  const [regnskap, bp] = await Promise.all([
    supabase
      .from('regnskapslinjer')
      .select('periode, seksjon, kode, post, regnskap, budsjett')
      .eq('stasjon_id', stasjonId)
      .gte('periode', fraOgMed)
      .in('seksjon', ['driftskostnader', 'nokkeltall'])
      .is('slettet_tid', null)
      .limit(20000)
      .overrideTypes<Kontolinje[]>(),
    // BP-EN SOM SITT EGET DOKUMENT (`0155`), IKKE `bp_kostnad`.
    //
    // De to bærer de samme tallene, men `bp_kostnad` i regnskapslinjer
    // hopper over hver avlagt måned — importen skriver den ikke når
    // måneden er låst. `bp_linje` er hva fila SA, urørt av låsen, og har
    // derfor alle tolv månedene.
    //
    // Én kilde for BP, ikke to. Sto tallet begge steder, ville de før
    // eller siden svart forskjellig på samme spørsmål.
    supabase
      .from('bp_linje')
      .select('maned, seksjon, kode, post, belop_kr, bp_aar!inner(ar, stasjon_id)')
      .eq('bp_aar.stasjon_id', stasjonId)
      .eq('seksjon', 'kostnad')
      // INGEN `slettet_tid` HER. `0155` utelot kolonnen med vilje — se
      // `0154`, der en SELECT-policy som krevde `slettet_tid is null`
      // blokkerte sin egen sletting på 31 tabeller. Et filter på en
      // kolonne som ikke finnes ville gitt en PostgREST-feil, ikke et
      // tomt svar.
      .limit(5000)
      .overrideTypes<{
        maned: number; seksjon: string; kode: string | null; post: string
        belop_kr: number | null; bp_aar: { ar: number; stasjon_id: string }
      }[]>(),
  ])

  // BP-LINJENE STØPES I SAMME FORM som regnskapets, så `byggLonnskost`
  // slipper å kjenne to radtyper. `regnskap: 0` er riktig: en BP-linje
  // er et budsjett, den bærer ingen faktisk kostnad.
  const bpSomKontolinjer: Kontolinje[] = (bp.data ?? [])
    .filter((r) => `${r.bp_aar.ar}-12-31` >= fraOgMed)
    .map((r) => ({
      periode: `${r.bp_aar.ar}-${String(r.maned).padStart(2, '0')}-01`,
      seksjon: 'bp_kostnad',
      kode: r.kode,
      post: r.post,
      regnskap: 0,
      budsjett: r.belop_kr,
    }))
    .filter((r) => r.periode >= fraOgMed)

  const linjer = [...(regnskap.data ?? []), ...bpSomKontolinjer]
  return {
    maaneder: byggLonnskost(linjer, BP_LONNSKODER),
    ukjenteKoder: ukjenteLonnskoder(
      linjer.filter((l) => l.seksjon === 'bp_kostnad' && l.kode).map((l) => l.kode!),
    ),
  }
}
