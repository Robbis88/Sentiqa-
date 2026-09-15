import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { maaVaereHele } from '@/lib/supabase/datobolker'

// =====================================================================
// SALGSDAGER: HVOR MANGE DAGER SOM FAKTISK HAR TALL
// =====================================================================
//
// FRA `v_butikksalg_dag`, IKKE FRA `v_butikksalg`.
//
// `v_butikksalg` er én rad per EAN per dag — tusenvis i måneden. Teller
// vi distinkte datoer der, treffer vi PostgREST sitt radtak, og et
// avkortet svar ser ut som en måned med færre salgsdager enn den har.
// Da melder dekningen en mangel som ikke finnes, og «Hva bør jeg vite
// nå?» ber noen lete etter en fil som ligger inne.
//
// Samme felle som 0090, 0166 og 0175: en avkortet spørring ser ut som
// en liten stasjon. `v_butikksalg_dag` (`0157`) er én rad per dag.
//
// OG IKKE `daglig_salg`: drivstoff er ~68 % av omsetningen og hører
// ikke hjemme i en vurdering av butikkens dag. Viewet holder det ute.
// =====================================================================

/**
 * Taket, og hvorfor det er under tusen.
 *
 * =====================================================================
 * ET TAK PÅ 1000 ER IKKE ET TAK
 * =====================================================================
 *
 * `supabase/config.toml` setter `max_rows = 1000`, så PostgREST gir
 * aldri mer uansett hva `.limit()` sier. Ba vi om tusen, ville et
 * avkortet svar hatt nøyaktig tusen rader — og vært umulig å skille
 * fra et komplett et.
 *
 * Tretten måneder er under 400 dager. 800 er romslig nok til at et
 * lovlig svar aldri treffer det, og lavt nok til at `maaVaereHele`
 * FAKTISK kan kaste hvis spørringen en dag henter noe annet enn én rad
 * per dag.
 */
const TAK_SALGSDAGER = 800

/**
 * Antall dager med butikksalg per måned, `yyyy-mm` → dager.
 *
 * KASTER PÅ FEIL OG PÅ AVKORTING, gjennom husets egen `maaVaereHele`.
 * En svelget `error` ville gitt en tom map, og da ville hver måned
 * stått som null salgsdager — altså full dekningsfeil på en stasjon der
 * alt er i orden, og «Hva bør jeg vite nå?» ville bedt noen lete etter
 * filer som ligger inne. «Ingen data» og «spørringen feilet» ser like
 * ut når feilen svelges.
 */
export async function hentSalgsdager(
  supabase: SupabaseClient,
  stasjonId: string,
  fraOgMed: string,
): Promise<Map<string, number>> {
  const svar = await supabase
    .from('v_butikksalg_dag')
    .select('dato')
    .eq('stasjon_id', stasjonId)
    .gte('dato', fraOgMed)
    .limit(TAK_SALGSDAGER)
    .overrideTypes<{ dato: string }[]>()

  const rader = maaVaereHele(svar, 'salgsdagene', TAK_SALGSDAGER)

  const per = new Map<string, number>()
  for (const rad of rader) {
    const maaned = rad.dato.slice(0, 7)
    per.set(maaned, (per.get(maaned) ?? 0) + 1)
  }
  return per
}
