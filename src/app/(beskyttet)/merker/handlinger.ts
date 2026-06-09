'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { iDag } from '@/lib/format'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { STANDARD_MERKER } from '@/lib/merker/standard'

export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase
    .from('merker')
    .select('*', { count: 'exact', head: true })
    .eq('retailer_id', bruker.retailerId)
    .is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  await supabase.from('merker').insert(
    STANDARD_MERKER.map((m, i) => ({
      retailer_id: bruker.retailerId,
      navn: m.navn,
      beskrivelse: m.beskrivelse,
      emoji: m.emoji,
      sortering: i,
    })),
  )
  revalidatePath('/merker')
}

export async function leggTilMerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const navn = String(formData.get('navn') ?? '').trim()
  const emoji = String(formData.get('emoji') ?? '').trim() || '⭐'
  const beskrivelse = String(formData.get('beskrivelse') ?? '').trim() || null
  if (!navn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('merker').insert({ retailer_id: bruker.retailerId, navn, emoji, beskrivelse, sortering: 999 })
  revalidatePath('/merker')
}

export async function slettMerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('merker').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/merker')
}

export async function tildelMerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const merkeId = String(formData.get('merke_id') ?? '')
  const ansattId = String(formData.get('ansatt_id') ?? '')
  if (!merkeId || !ansattId) return
  const supabase = await lagSupabaseServerKlient()
  const { data: ansatt } = await supabase.from('ansatte').select('stasjon_id').eq('id', ansattId).maybeSingle<{ stasjon_id: string }>()
  if (!ansatt) return
  await supabase.from('tildelte_merker').upsert(
    { merke_id: merkeId, ansatt_id: ansattId, stasjon_id: ansatt.stasjon_id, tildelt_av: bruker.id, tildelt_dato: iDag() },
    { onConflict: 'merke_id,ansatt_id', ignoreDuplicates: true },
  )
  revalidatePath('/merker')
}

export async function fjernTildeling(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('tildelte_merker').delete().eq('id', id)
  revalidatePath('/merker')
}
