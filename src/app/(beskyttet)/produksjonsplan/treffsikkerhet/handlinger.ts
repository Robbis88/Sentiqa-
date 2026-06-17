'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { kjorBacktestForRetailer } from '@/lib/backtest'

// Kjører backtesten på nytt for innlogget eiers kjede (service-role → omgår RLS
// og slipper 1000-rad-fella). Kun eier; butikksjef får tallene via nattjobben.
export async function oppdaterTreffsikkerhet(): Promise<{ ok: boolean; stasjoner?: number; feil?: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { ok: false, feil: 'Kun eier kan oppdatere treffsikkerheten.' }
  try {
    const admin = lagSupabaseAdminKlient()
    const n = await kjorBacktestForRetailer(admin, bruker.retailerId, 60)
    revalidatePath('/produksjonsplan/treffsikkerhet')
    return { ok: true, stasjoner: n }
  } catch (e) {
    return { ok: false, feil: e instanceof Error ? e.message : 'Ukjent feil' }
  }
}
