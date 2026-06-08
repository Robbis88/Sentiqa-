import 'server-only'
import webpush from 'web-push'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

let konfigurert = false
function konfig(): boolean {
  if (konfigurert) return true
  if (!env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || !env.VAPID_PRIVATE_KEY) return false
  webpush.setVapidDetails(
    env.VAPID_SUBJECT || 'mailto:hei@sentiqa.ai',
    env.NEXT_PUBLIC_VAPID_PUBLIC_KEY,
    env.VAPID_PRIVATE_KEY,
  )
  konfigurert = true
  return true
}

type PushPayload = { tittel: string; tekst?: string | null; lenke?: string | null }

async function sendTilBrukere(userIds: string[], payload: PushPayload): Promise<void> {
  if (!konfig() || userIds.length === 0) return
  const admin = lagSupabaseAdminKlient()
  const { data: subs } = await admin
    .from('push_abonnementer')
    .select('id, endpoint, p256dh, auth')
    .in('user_id', userIds)
  const body = JSON.stringify({ tittel: payload.tittel, tekst: payload.tekst ?? '', lenke: payload.lenke ?? '/varsler' })

  await Promise.all(
    (subs ?? []).map(async (s: { id: string; endpoint: string; p256dh: string; auth: string }) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, body)
      } catch (e) {
        const kode = (e as { statusCode?: number }).statusCode
        if (kode === 404 || kode === 410) {
          await admin.from('push_abonnementer').delete().eq('id', s.id) // utløpt
        }
      }
    }),
  )
}

// Sender push for et varsel: til mottakeren, ellers til kjedens ledere.
export async function sendPushForVarsel(v: {
  retailer_id: string
  mottaker_id?: string | null
  tittel: string
  tekst?: string | null
  lenke?: string | null
}): Promise<void> {
  if (!konfig()) return
  let userIds: string[]
  if (v.mottaker_id) {
    userIds = [v.mottaker_id]
  } else {
    const admin = lagSupabaseAdminKlient()
    const { data } = await admin
      .from('profiler')
      .select('id')
      .eq('retailer_id', v.retailer_id)
      .in('rolle', ['retailer_admin', 'butikksjef'])
    userIds = (data ?? []).map((p: { id: string }) => p.id)
  }
  await sendTilBrukere(userIds, { tittel: v.tittel, tekst: v.tekst, lenke: v.lenke })
}
