'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function markerLest(formData: FormData) {
  await hentInnloggetBruker()
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('varsler').update({ lest: true }).eq('id', id)
  revalidatePath('/varsler')
}

export async function markerAlle() {
  await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('varsler').update({ lest: true }).eq('lest', false)
  revalidatePath('/varsler')
}
