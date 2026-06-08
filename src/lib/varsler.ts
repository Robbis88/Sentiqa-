import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sendPushForVarsel } from '@/lib/push'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export type NyttVarsel = {
  retailer_id: string
  type: string
  tittel: string
  tekst?: string | null
  lenke?: string | null
  mottaker_id?: string | null
  stasjon_id?: string | null
}

// Oppretter et in-app-varsel. Skal aldri velte den utløsende handlingen → svelger feil.
export async function opprettVarsel(supabase: Klient, v: NyttVarsel): Promise<void> {
  try {
    await supabase.from('varsler').insert({
      retailer_id: v.retailer_id,
      type: v.type,
      tittel: v.tittel,
      tekst: v.tekst ?? null,
      lenke: v.lenke ?? null,
      mottaker_id: v.mottaker_id ?? null,
      stasjon_id: v.stasjon_id ?? null,
    })
  } catch {
    // ignorert med vilje
  }
  // Web-push i tillegg (best effort — hopper over hvis VAPID ikke er satt).
  try {
    await sendPushForVarsel(v)
  } catch {
    // ignorert med vilje
  }
}
