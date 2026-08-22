'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function leggTilAnvisning(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const kategori = String(formData.get('kategori') ?? '').trim() || 'Generelt'
  const tittel = String(formData.get('tittel') ?? '').trim()
  const innhold = String(formData.get('innhold') ?? '').trim()
  if (!tittel || !innhold) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('anvisninger').insert({ retailer_id: bruker.retailerId, kategori, tittel, innhold, opprettet_av: bruker.id })
  revalidatePath('/anvisninger')
}

export async function slettAnvisning(
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
  const { error } = await supabase.from('anvisninger').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/anvisninger')
  return { ok: 'Anvisningen slettet' }
}
