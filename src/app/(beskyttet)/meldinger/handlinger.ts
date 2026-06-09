'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function sendMelding(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const tekst = String(formData.get('tekst') ?? '').trim()
  const stasjonId = String(formData.get('stasjon_id') ?? '') || null // tom = alle
  const viktig = formData.get('viktig') === 'on'
  if (!tekst) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('tablet_meldinger').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    tekst,
    viktig,
    opprettet_av: bruker.id,
  })
  revalidatePath('/meldinger')
}

export async function slettMelding(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('tablet_meldinger').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/meldinger')
}
