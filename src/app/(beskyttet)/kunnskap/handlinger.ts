'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

// Kunnskapsbasen er global og vedlikeholdes KUN av plattform-redaktøren.
export async function leggTilKunnskap(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return
  const tittel = String(formData.get('tittel') ?? '').trim()
  const innhold = String(formData.get('innhold') ?? '').trim()
  const kategori = String(formData.get('kategori') ?? 'rutine').trim() || 'rutine'
  const kilde = String(formData.get('kilde') ?? '').trim() || null
  if (!tittel || !innhold) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('kunnskap').insert({ retailer_id: null, kategori, tittel, innhold, kilde, opprettet_av: bruker.id }), 'opprette kunnskap')
  revalidatePath('/kunnskap')
}

export async function slettKunnskap(
  _t: SlettTilstand, formData: FormData,
): Promise<SlettTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return { feil: 'Ikke tilgang.' }
  const id = String(formData.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  // FEILEN SKAL VAERE SYNLIG. Ble raden avvist av RLS, skjedde
  // det ingenting - og sida sa ingenting. Da er «slettet» og
  // «gikk ikke» to tilstander som ser helt like ut.
  const { error } = await supabase.from('kunnskap').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/kunnskap')
  return { ok: 'Artikkelen slettet' }
}
