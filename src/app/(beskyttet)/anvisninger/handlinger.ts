'use server'
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

export async function slettAnvisning(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('anvisninger').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/anvisninger')
}
