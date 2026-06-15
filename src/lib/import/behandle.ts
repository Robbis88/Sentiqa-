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

// «Behandle alle» — kjører hele 'mottatt'-køen i en løkke med feil-isolasjon
// per fil: én rar/korrupt fil flagges (status 'feilet'), men stopper ikke resten.
export async function behandleAlle(): Promise<{ ok: number; feil: number }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { ok: 0, feil: 0 }
  const supabase = await lagSupabaseServerKlient()
  const { data: jobber } = await supabase
    .from('import_jobber').select('id')
    .eq('retailer_id', bruker.retailerId).eq('status', 'mottatt')
    .order('opprettet_tid', { ascending: true })
  let ok = 0, feil = 0
  for (const j of (jobber ?? []) as { id: string }[]) {
    try {
      await behandleJobbKjerne(supabase, bruker.retailerId, j.id)
      ok++
    } catch {
      feil++ // kjernen setter selv status='feilet'; dette er ekstra sikring så løkka går videre
    }
  }
  revalidatePath('/import')
  return { ok, feil }
}
