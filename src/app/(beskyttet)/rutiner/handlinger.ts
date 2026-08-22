'use server'
import { randomUUID } from 'node:crypto'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { maaLykkes } from '@/lib/skriv-svar'

const BILDE_BUCKET = 'rutinebilder'

// Avkryssing skjer på VAKTDATOEN (kan være i går for nattvakt over midnatt).
export async function kryssAv(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  if (!rutineId || !stasjonId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt(supabase)
  maaLykkes(await supabase.from('rutine_utforinger').upsert(
    { rutine_id: rutineId, stasjon_id: stasjonId, dato, utfort_av: bruker.id, ansatt_id: ansatt?.id ?? null },
    { onConflict: 'rutine_id,dato', ignoreDuplicates: true },
  ), 'lagre rutine utforinger')
  revalidatePath('/rutiner')
}

// Avkryssing med bildebevis (rutiner med paakrevd_bilde).
export async function kryssAvMedBilde(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return
  const rutineId = String(formData.get('rutine_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  const fil = formData.get('bilde')
  if (!rutineId || !stasjonId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  if (!(fil instanceof File) || fil.size === 0 || !fil.type.startsWith('image/')) return

  const buffer = Buffer.from(await fil.arrayBuffer())
  const ext = fil.type === 'image/png' ? 'png' : 'jpg'
  const sti = `${bruker.retailerId}/${stasjonId}/${randomUUID()}.${ext}`
  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt(supabase)

  const opp = await supabase.storage.from(BILDE_BUCKET).upload(sti, buffer, { contentType: fil.type })
  if (opp.error) return

  maaLykkes(await supabase.from('rutine_utforinger').upsert(
    { rutine_id: rutineId, stasjon_id: stasjonId, dato, utfort_av: bruker.id, ansatt_id: ansatt?.id ?? null, bilde_sti: sti },
    { onConflict: 'rutine_id,dato' },
  ), 'lagre rutine utforinger')
  revalidatePath('/rutiner')
}

// AV/PAA-BRYTER, IKKE EN SLETT-KNAPP. Den staar i en ternaer sammen med
// `kryssAv` og maa dele signatur med den. Krysset som forsvinner ER
// kvitteringen her; en tekst ved siden av ville sagt det samme to
// ganger. Skrivet svarer likevel - `maaLykkes` kaster om det feiler.
export async function fjernKryss(formData: FormData) {
  await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  if (!rutineId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  const supabase = await lagSupabaseServerKlient()
  // Rydd bildet i storage hvis det finnes.
  const { data } = await supabase
    .from('rutine_utforinger')
    .select('bilde_sti')
    .eq('rutine_id', rutineId)
    .eq('dato', dato)
    .maybeSingle<{ bilde_sti: string | null }>()
  if (data?.bilde_sti) await supabase.storage.from(BILDE_BUCKET).remove([data.bilde_sti])
  maaLykkes(await supabase.from('rutine_utforinger').delete().eq('rutine_id', rutineId).eq('dato', dato), 'fjerne kryss')
  revalidatePath('/rutiner')
}
