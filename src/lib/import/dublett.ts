import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// «Allerede lastet opp» — men ble den faktisk importert?
//
// raa_filer skrives FØR dataene, og rulles ikke tilbake når importen
// feiler. Unik indeks på (retailer_id, sha256) gjorde derfor at en
// mislykket import blokkerte sitt eget nye forsøk: fila var registrert,
// dataene fantes ikke, og opplastingen svarte «allerede lastet opp».
//
// Robert lastet opp timesalg for 13.–15. august tre ganger. Alle ble
// hoppet over, og ingen av dagene fantes i basen.
//
// Et duplikat er derfor bare et duplikat hvis den forrige importen
// lyktes. Gjorde den ikke det, slettes den gamle raden mykt — den
// partielle indeksen ser bort fra slettede — og den nye slipper inn.
// =====================================================================

type Klient = SupabaseClient

export type Dublettsvar =
  | { slippGjennom: true }
  | { slippGjennom: false; melding: string }

type Jobb = { status: string; antall_rader: number | null }
type Rad = { id: string; opprettet_tid: string; import_jobber: Jobb[] }

const tid = new Intl.DateTimeFormat('nb-NO', {
  timeZone: 'Europe/Oslo', dateStyle: 'short', timeStyle: 'short',
})

/**
 * Kalles når innsettingen i raa_filer feilet med 23505.
 *
 * Returnerer om den nye opplastingen skal slippe gjennom likevel, og
 * ellers en melding som sier NÅR fila kom inn og hva som skjedde med
 * den. «Allerede lastet opp» alene er ubrukelig — det kan bety at alt
 * er i orden, eller at ingenting er det.
 */
export async function vurderDublett(
  supabase: Klient,
  retailerId: string,
  sha256: string,
): Promise<Dublettsvar> {
  const { data } = await supabase
    .from('raa_filer')
    .select('id, opprettet_tid, import_jobber(status, antall_rader)')
    .eq('retailer_id', retailerId)
    .eq('sha256', sha256)
    .is('slettet_tid', null)
    .order('opprettet_tid', { ascending: false })
    .limit(1)
    .maybeSingle<Rad>()

  // Fant vi den ikke, er kollisjonen noe annet enn vi tror. Da er det
  // tryggere å slippe gjennom enn å avvise på feil grunnlag.
  if (!data) return { slippGjennom: true }

  const jobber = data.import_jobber ?? []
  const lyktes = jobber.find((j) => j.status === 'parset' && (j.antall_rader ?? 0) > 0)
  const behandles = jobber.some((j) => j.status === 'behandler')

  if (lyktes) {
    return {
      slippGjennom: false,
      melding: `Allerede importert ${tid.format(new Date(data.opprettet_tid))}`
        + ` — ${lyktes.antall_rader} linjer`,
    }
  }
  if (behandles) {
    return { slippGjennom: false, melding: 'Behandles akkurat nå — vent litt' }
  }

  // Registrert, men aldri importert. Fjern sperren.
  await supabase
    .from('raa_filer')
    .update({ slettet_tid: new Date().toISOString() })
    .eq('id', data.id)
  return { slippGjennom: true }
}
