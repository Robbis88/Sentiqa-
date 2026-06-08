'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function lagrePushAbonnement(sub: { endpoint: string; p256dh: string; auth: string }) {
  const bruker = await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('push_abonnementer').upsert(
    {
      user_id: bruker.id,
      retailer_id: bruker.retailerId ?? null,
      endpoint: sub.endpoint,
      p256dh: sub.p256dh,
      auth: sub.auth,
    },
    { onConflict: 'endpoint' },
  )
}

export async function fjernPushAbonnement(endpoint: string) {
  await hentInnloggetBruker()
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('push_abonnementer').delete().eq('endpoint', endpoint)
}
