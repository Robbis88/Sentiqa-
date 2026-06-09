'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

function erLeder(rolle: string) {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}

export async function leggTilLenke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const tittel = String(formData.get('tittel') ?? '').trim()
  let url = String(formData.get('url') ?? '').trim()
  const ikon = String(formData.get('ikon') ?? '').trim() || '🔗'
  if (!tittel || !url) return
  if (!/^https?:\/\//i.test(url)) url = `https://${url}`
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('lenker').insert({ retailer_id: bruker.retailerId, tittel, url, ikon, opprettet_av: bruker.id })
  revalidatePath('/lenker')
}

export async function slettLenke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('lenker').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/lenker')
}
