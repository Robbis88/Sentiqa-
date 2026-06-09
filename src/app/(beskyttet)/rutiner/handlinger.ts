'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'

// Avkryssing skjer på VAKTDATOEN (kan være i går for nattvakt over midnatt).
export async function kryssAv(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  if (!rutineId || !stasjonId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  const ansatt = await lesAktivAnsatt()
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutine_utforinger').upsert(
    { rutine_id: rutineId, stasjon_id: stasjonId, dato, utfort_av: bruker.id, ansatt_id: ansatt?.id ?? null },
    { onConflict: 'rutine_id,dato', ignoreDuplicates: true },
  )
  revalidatePath('/rutiner')
}

export async function fjernKryss(formData: FormData) {
  await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  if (!rutineId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutine_utforinger').delete().eq('rutine_id', rutineId).eq('dato', dato)
  revalidatePath('/rutiner')
}
