'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function settAbonnement(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return
  const fakturaEpost = String(formData.get('faktura_epost') ?? '').trim() || null
  const aarlig = formData.get('aarlig_forskudd') === 'on'
  const premium = formData.get('premium_avtalevokter') === 'on'

  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase
    .from('retailers')
    .update({ faktura_epost: fakturaEpost, aarlig_forskudd: aarlig, premium_avtalevokter: premium })
    .eq('id', bruker.retailerId), 'oppdatere retailers')
  revalidatePath('/abonnement')
}
