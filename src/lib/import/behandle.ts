'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { behandleJobbKjerne } from '@/lib/import/kjerne'

// UI-knappen «Behandle» — kjører kjernen med brukerens sesjon, og revaliderer.
export async function behandleJobb(formData: FormData) {
  const jobbId = String(formData.get('jobbId') ?? '')
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  await behandleJobbKjerne(supabase, bruker.retailerId, jobbId)
  revalidatePath('/import')
}
