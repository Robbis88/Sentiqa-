'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function registrerSkills(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const prosent = Number(String(formData.get('prosent') ?? '').replace(',', '.'))
  const kommentar = String(formData.get('kommentar') ?? '').trim() || null
  if (!stasjonId || !Number.isFinite(prosent) || prosent < 0 || prosent > 100) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('skills_score').insert({ retailer_id: bruker.retailerId, stasjon_id: stasjonId, prosent, kommentar, registrert_av: bruker.id })
  revalidatePath('/skills')
}

export async function slettSkills(
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
  const { error } = await supabase.from('skills_score').delete().eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/skills')
  return { ok: 'Scoren slettet' }
}
