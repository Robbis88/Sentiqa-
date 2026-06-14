'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { finnNaermesteTeller } from '@/lib/trafikk'

async function erEier(): Promise<boolean> {
  const bruker = await hentInnloggetBruker()
  return bruker.rolle === 'plattform_redaktor'
}

// Finn og lagre nærmeste bilteller for en stasjon (aktiverer ikke måling).
export async function finnTeller(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  const { data: st } = await admin.from('stasjoner').select('breddegrad, lengdegrad').eq('id', id).maybeSingle()
  if (!st?.breddegrad || !st?.lengdegrad) return
  const teller = await finnNaermesteTeller(st.breddegrad, st.lengdegrad)
  await admin.from('stasjoner').update({
    trafikk_punkt_id: teller?.id ?? null,
    trafikk_punkt_navn: teller ? `${teller.navn} · ${teller.snittVolum} biler/døgn · ${teller.avstandKm} km` : null,
    trafikk_punkt_vei: teller?.vei ?? null,
  }).eq('id', id)
  revalidatePath('/trafikk')
}

// Skru måling på/av for en stasjon.
export async function settTrafikkAktiv(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  const aktiv = String(formData.get('aktiv') ?? '') === 'true'
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  await admin.from('stasjoner').update({ trafikk_aktiv: aktiv }).eq('id', id)
  revalidatePath('/trafikk')
}
