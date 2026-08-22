'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { kvitter, type Kvittering } from '@/lib/kvittering'
import { maaLykkes } from '@/lib/skriv-svar'

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
  maaLykkes(await admin.from('kampanjer').insert({ retailer_id, navn, fra_dato, til_dato, eaner, opprettet_av: bruker.id }), 'opprette kampanjen')
  revalidatePath('/kampanjer')
}

export async function slettKampanje(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  if (!(await erEier())) return { feil: 'Bare eier kan slette kampanjer.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  let admin
  // `try { ... } catch { return }` ga noeyaktig samme bilde som et
  // vellykket klikk. Mangler tjenestenoekkelen i miljoeet, skjedde det
  // ingenting - og ingenting sa fra.
  try { admin = lagSupabaseAdminKlient() } catch {
    return { feil: 'Tjenestenøkkelen mangler i miljøet.' }
  }
  return kvitter(
    admin.from('kampanjer')
      .update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id),
    { hva: 'slette kampanjen', ok: 'Kampanje slettet', oppfrisk: ['/kampanjer'] },
  )
}
