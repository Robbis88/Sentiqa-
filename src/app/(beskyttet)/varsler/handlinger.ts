'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function markerLest(formData: FormData) {
  await hentInnloggetBruker()
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('varsler').update({ lest: true }).eq('id', id), 'oppdatere varsler')
  revalidatePath('/varsler')
}

export async function markerAlle() {
  await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('varsler').update({ lest: true }).eq('lest', false), 'oppdatere varsler')
  revalidatePath('/varsler')
}
