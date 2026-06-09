'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

function erLeder(rolle: string) {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}

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

export async function slettSkills(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('skills_score').delete().eq('id', id)
  revalidatePath('/skills')
}
