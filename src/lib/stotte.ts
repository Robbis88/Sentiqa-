import 'server-only'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

// =====================================================================
// PORTEN FORAN TJENESTENØKKELEN
//
// Plattformens tilgang til en kunde var alt eller ingenting:
// `plattform_redaktor` har `retailer_id = null` og ser null rader gjennom
// RLS, mens tjenestenøkkelen ser absolutt alt. Ingenting imellom, og
// ingen logg over at den ble brukt.
//
// Denne fila er det som ligger imellom. Den utvider IKKE
// radnivåsikkerheten — se begrunnelsen i `0196_stottetilgang.sql`: å la
// `gjeldende_retailer_id()` svare noe annet ville vært den eleganteste
// og farligste endringen i hele basen.
//
// ---------------------------------------------------------------------
// FEILER LUKKET, PÅ ALLE TRE MÅTENE DEN KAN FEILE
//
//   feil rolle         → nei
//   ingen aktiv rad    → nei
//   klarte ikke spørre → nei
//
// Den siste er den som pleier å bli skrevet motsatt. En port som slipper
// gjennom når den ikke får svar, er ikke en port — den er en port som
// står åpen akkurat når databasen har det vanskelig.
// =====================================================================

export type Stottesvar =
  | { ok: true; tilgangId: string; admin: ReturnType<typeof lagSupabaseAdminKlient> }
  | { ok: false; feil: string }

/**
 * Krever en aktiv støttetilgang for `retailerId`, og skriver et oppslag.
 *
 * HANDLINGEN LOGGES FØR DEN UTFØRES, ikke etter. En handling som feiler
 * halvveis har likevel vært et oppslag i kundens data — og det er nettopp
 * den varianten en kunde vil se. Logger vi etterpå, mangler de linjene
 * som betydde mest.
 */
export async function krevStotte(
  retailerId: string,
  handling: string,
  detaljer: Record<string, unknown> = {},
): Promise<Stottesvar> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') {
    return { ok: false, feil: 'Bare plattform-redaktør kan gjøre dette.' }
  }
  if (!retailerId) return { ok: false, feil: 'Mangler kjede.' }

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { ok: false, feil: 'Tjenestenøkkelen mangler i miljøet.' }
  }

  // Den aktive raden hentes, ikke bare telles: id-en trengs for å knytte
  // oppslaget til tildelingen det skjedde under.
  const { data, error } = await admin
    .from('stotte_tilgang')
    .select('id')
    .eq('retailer_id', retailerId)
    .eq('gitt_til', bruker.id)
    .is('avsluttet_tid', null)
    .lte('fra_tid', new Date().toISOString())
    .gte('til_tid', new Date().toISOString())
    .order('til_tid', { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string }>()

  if (error) {
    // LUKKET. Se blokken øverst.
    return { ok: false, feil: `Kunne ikke sjekke støttetilgang: ${error.message}` }
  }
  if (!data) {
    return {
      ok: false,
      feil: 'Ingen aktiv støttetilgang for denne kjeden. Åpne en med begrunnelse først.',
    }
  }

  const { error: le } = await admin.from('stotte_oppslag').insert({
    tilgang_id: data.id,
    retailer_id: retailerId,
    handling,
    detaljer,
  })
  // EN HANDLING SOM IKKE LOT SEG LOGGE SKAL IKKE SKJE. Hele poenget er
  // sporet; uten det er dette bare tjenestenøkkelen med et ekstra steg.
  if (le) return { ok: false, feil: `Kunne ikke skrive oppslagsloggen: ${le.message}` }

  return { ok: true, tilgangId: data.id, admin }
}

/** Timer en tildeling kan vare. Databasen håndhever det samme (0196). */
export const MAKS_TIMER = 8

/**
 * Åpner et støttevindu for én kjede, med begrunnelse.
 *
 * Begrunnelsen er påkrevd både her og i skjemaet (`check` i 0196). En
 * begrunnelse man må skrive, er en begrunnelse man må ha — og den er det
 * eneste i raden som forteller en kunde hvorfor noen var inne.
 */
export async function apneStotte(
  retailerId: string,
  begrunnelse: string,
  timer: number,
): Promise<{ ok: true } | { ok: false; feil: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') {
    return { ok: false, feil: 'Bare plattform-redaktør kan åpne støttetilgang.' }
  }
  const grunn = begrunnelse.trim()
  if (grunn.length < 10) {
    return { ok: false, feil: 'Skriv en begrunnelse på minst 10 tegn. Den vises for kunden.' }
  }
  const t = Math.min(Math.max(Math.round(timer) || 1, 1), MAKS_TIMER)

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { ok: false, feil: 'Tjenestenøkkelen mangler i miljøet.' }
  }

  const naa = new Date()
  const { error } = await admin.from('stotte_tilgang').insert({
    retailer_id: retailerId,
    gitt_til: bruker.id,
    begrunnelse: grunn,
    fra_tid: naa.toISOString(),
    til_tid: new Date(naa.getTime() + t * 3600_000).toISOString(),
  })
  if (error) return { ok: false, feil: `Kunne ikke åpne: ${error.message}` }
  return { ok: true }
}

/** Lukker et åpent vindu før tiden. Den som er ferdig, skal kunne si det. */
export async function lukkStotte(
  tilgangId: string,
): Promise<{ ok: true } | { ok: false; feil: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') {
    return { ok: false, feil: 'Bare plattform-redaktør kan lukke støttetilgang.' }
  }
  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { ok: false, feil: 'Tjenestenøkkelen mangler i miljøet.' }
  }
  // Bundet til egen bruker: en redaktør lukker sitt eget vindu, ikke en
  // annens. `count` skiller «lukket» fra «fantes ikke».
  const { error, count } = await admin
    .from('stotte_tilgang')
    .update({ avsluttet_tid: new Date().toISOString() }, { count: 'exact' })
    .eq('id', tilgangId)
    .eq('gitt_til', bruker.id)
    .is('avsluttet_tid', null)
  if (error) return { ok: false, feil: `Kunne ikke lukke: ${error.message}` }
  if (count === 0) return { ok: false, feil: 'Fant ingen åpen tilgang å lukke.' }
  return { ok: true }
}
