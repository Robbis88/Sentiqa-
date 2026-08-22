'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function sendMelding(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const tekst = String(formData.get('tekst') ?? '').trim()
  const stasjonId = String(formData.get('stasjon_id') ?? '') || null // tom = alle
  const viktig = formData.get('viktig') === 'on'
  if (!tekst) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('tablet_meldinger').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    tekst,
    viktig,
    opprettet_av: bruker.id,
  }), 'opprette tablet meldinger')
  revalidatePath('/meldinger')
}

export async function slettMelding(
  _t: SlettTilstand, formData: FormData,
): Promise<SlettTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(formData.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  // FEILEN SKAL VAERE SYNLIG. Ble raden avvist av RLS, skjedde
  // det ingenting - og sida sa ingenting. Da er «slettet» og
  // «gikk ikke» to tilstander som ser helt like ut.
  const { error } = await supabase.from('tablet_meldinger').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/meldinger')
  return { ok: 'Meldingen slettet' }
}
