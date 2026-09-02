'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { kjorBacktestForRetailer } from '@/lib/backtest'

// Kjører backtesten på nytt for innlogget eiers kjede (service-role → omgår RLS
// og slipper 1000-rad-fella). Kun eier; butikksjef får tallene via nattjobben.
//
// INGEN `revalidatePath` PAA EGEN RUTE. Den gjoer ruteroppdateringen til
// en del av overgangen `useTransition` venter paa: serveren er ferdig,
// men knappen staar og spinner til hele sida har tegnet seg om. Paa en
// AI-generering er det minutter.
//
// `router.refresh()` i knappen, ETTER at svaret er vist, gir samme
// oppdatering uten aa ta kvitteringen som gissel. Se PR #114 og
// `kvitteringsvakt.test.ts`.
export async function oppdaterTreffsikkerhet(): Promise<{ ok: boolean; stasjoner?: number; feil?: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { ok: false, feil: 'Kun eier kan oppdatere treffsikkerheten.' }
  try {
    const admin = lagSupabaseAdminKlient()
    const n = await kjorBacktestForRetailer(admin, bruker.retailerId, 60)
    return { ok: true, stasjoner: n }
  } catch (e) {
    return { ok: false, feil: e instanceof Error ? e.message : 'Ukjent feil' }
  }
}
