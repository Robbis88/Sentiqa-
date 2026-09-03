'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { env } from '@/lib/env'
import { sendProve } from '@/lib/ukebrief/send'

export type Provesvar = { ok: true; til: string } | { ok: false; feil: string }

/**
 * Sender ukebriefen til DIN EGEN adresse.
 *
 * Adressen kommer fra sesjonen og kan ikke sendes med av klienten. Det er
 * ikke en formalitet: en `til`-parameter her ville gjort knappen til en
 * vei til å sende Sentiqa-post til hvem som helst, fra et verifisert
 * domene. Den finnes derfor ikke.
 *
 * Stasjonen leses med den vanlige serverklienten, så RLS avgjør om den er
 * din. Er den ikke det, finnes den ikke — og da er det ikke noe brev.
 */
export async function sendProveTilMegSelv(
  stasjonId: string, ukeMandag: string,
): Promise<Provesvar> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { ok: false, feil: 'Ikke tilgang.' }
  if (!bruker.epost) return { ok: false, feil: 'Brukeren din har ingen e-postadresse.' }

  const supabase = await lagSupabaseServerKlient()
  const { data: stasjon, error } = await supabase
    .from('stasjoner').select('id, butikknummer, navn')
    .eq('id', stasjonId).is('slettet_tid', null)
    .maybeSingle<{ id: string; butikknummer: string; navn: string }>()
  if (error) return { ok: false, feil: `Kunne ikke lese stasjonen: ${error.message}` }
  if (!stasjon) return { ok: false, feil: 'Fant ikke stasjonen.' }

  const svar = await sendProve({
    klient: supabase,
    stasjon,
    ukeMandag,
    basisUrl: env.UKEBRIEF_BASIS_URL,
    til: bruker.epost,
  })
  // Handlingen svarer ALLTID — også når den lyktes. En sending som går
  // stille gjennom ser ut som en som ikke skjedde.
  return svar.ok ? { ok: true, til: bruker.epost } : { ok: false, feil: svar.feil }
}
