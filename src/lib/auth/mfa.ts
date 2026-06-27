import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { Brukerrolle } from './typer'

// To-faktor (TOTP) — policy + håndheving (PROSJEKT.md §3, §15).
//
// Privilegerte konti MÅ ha MFA: retailer_admin kan eksportere/​slette ALL
// kjededata og styre fakturering; plattform_redaktor publiserer ut til alle
// tenants. Butikksjef kan slå det på frivillig. Tablet (butikkbruker_tablet)
// bruker delt PIN på felles enhet — feil lag for MFA — og er bevisst utelatt.
export function mfaPaakrevd(rolle: Brukerrolle): boolean {
  return rolle === 'retailer_admin' || rolle === 'plattform_redaktor'
}

export type MfaHandling = 'ok' | 'steg_opp' | 'innruller'

// Avgjør hva sesjonen må gjøre, ut fra AAL-nivå + rolle:
//   currentLevel aal2          → 'ok' (allerede stegget opp denne sesjonen)
//   har faktor, men aal1       → 'steg_opp' (skriv inn engangskode)
//   ingen faktor               → 'innruller' hvis rollen krever MFA, ellers 'ok'
//
// nextLevel er 'aal2' når brukeren har minst én verifisert faktor.
// Ved transient AAL-feil failer vi til 'ok' — en sjelden API-feil skal ikke
// låse ute privilegerte brukere (RLS er uansett den egentlige muren, §3).
export async function mfaHandling(
  supabase: SupabaseClient,
  rolle: Brukerrolle,
): Promise<MfaHandling> {
  const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
  if (error || !data) return 'ok'
  if (data.currentLevel === 'aal2') return 'ok'
  if (data.nextLevel === 'aal2') return 'steg_opp'
  return mfaPaakrevd(rolle) ? 'innruller' : 'ok'
}
