'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function leggTilKunnskap(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const tittel = String(formData.get('tittel') ?? '').trim()
  const innhold = String(formData.get('innhold') ?? '').trim()
  const kategori = String(formData.get('kategori') ?? 'rutine').trim() || 'rutine'
  const kilde = String(formData.get('kilde') ?? '').trim() || null
  if (!tittel || !innhold) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('kunnskap').insert({ retailer_id: bruker.retailerId, kategori, tittel, innhold, kilde, opprettet_av: bruker.id })
  revalidatePath('/kunnskap')
}

export async function slettKunnskap(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('kunnskap').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/kunnskap')
}
