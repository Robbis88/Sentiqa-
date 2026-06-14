'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

async function erEier(): Promise<boolean> {
  const bruker = await hentInnloggetBruker()
  return bruker.rolle === 'plattform_redaktor'
}

export async function opprettKampanje(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return
  const retailer_id = String(formData.get('retailer_id') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  const fra_dato = String(formData.get('fra_dato') ?? '')
  const til_dato = String(formData.get('til_dato') ?? '')
  if (!retailer_id || !navn || !/^\d{4}-\d{2}-\d{2}$/.test(fra_dato) || !/^\d{4}-\d{2}-\d{2}$/.test(til_dato)) return
  // Tomt EAN-felt = auto (alle tilbudsvarer i perioden).
  const eanerRaw = String(formData.get('eaner') ?? '').split(/[\s,;]+/).map((s) => s.trim()).filter(Boolean)
  const eaner = eanerRaw.length > 0 ? eanerRaw : null
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  await admin.from('kampanjer').insert({ retailer_id, navn, fra_dato, til_dato, eaner, opprettet_av: bruker.id })
  revalidatePath('/kampanjer')
}

export async function slettKampanje(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  await admin.from('kampanjer').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/kampanjer')
}
