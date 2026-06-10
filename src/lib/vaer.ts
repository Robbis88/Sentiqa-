import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'

type Daglig = {
  time: string[]
  temperature_2m_max: (number | null)[]
  temperature_2m_min: (number | null)[]
  precipitation_sum: (number | null)[]
}

// Henter ~90 dager historikk + 7 dagers varsel fra Open-Meteo (gratis, ingen
// nøkkel) for én stasjon. Tidssone Europe/Oslo (§18).
async function hentForStasjon(lat: number, lon: number): Promise<Daglig | null> {
  const url =
    `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
    `&daily=temperature_2m_max,temperature_2m_min,precipitation_sum` +
    `&timezone=Europe%2FOslo&past_days=92&forecast_days=7`
  const r = await fetch(url, { cache: 'no-store' })
  if (!r.ok) return null
  const j = (await r.json()) as { daily?: Daglig }
  return j.daily ?? null
}

type VaerResultat = { ok: true; antall: number; stasjoner: number } | { ok: false; grunn: string }

// Kjernen — tar en klient (server- eller admin/cron-klient). Henter vær for
// alle stasjoner som har koordinater og upserter i vaer-tabellen.
export async function hentVaerMedKlient(supabase: SupabaseClient): Promise<VaerResultat> {
  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, breddegrad, lengdegrad')
    .is('slettet_tid', null)
    .not('breddegrad', 'is', null)
    .not('lengdegrad', 'is', null)
    .overrideTypes<{ id: string; breddegrad: number; lengdegrad: number }[]>()

  if (!stasjoner || stasjoner.length === 0) {
    return { ok: false, grunn: 'Ingen stasjoner har koordinater. Sett breddegrad/lengdegrad under Stasjoner.' }
  }

  let antall = 0
  await Promise.all(
    stasjoner.map(async (s) => {
      const d = await hentForStasjon(s.breddegrad, s.lengdegrad)
      if (!d) return
      const rader = d.time.map((dato, i) => ({
        stasjon_id: s.id,
        dato,
        temp_maks: d.temperature_2m_max[i],
        temp_min: d.temperature_2m_min[i],
        nedbor_mm: d.precipitation_sum[i],
        hentet_tid: new Date().toISOString(),
      }))
      if (rader.length === 0) return
      const { error } = await supabase.from('vaer').upsert(rader, { onConflict: 'stasjon_id,dato' })
      if (!error) antall += rader.length
    }),
  )

  return { ok: true, antall, stasjoner: stasjoner.length }
}

// Manuell trigger (eier). Cronen henter automatisk hver natt; denne beholdes
// for ev. manuell oppfriskning.
export async function hentVaerForAlle(): Promise<VaerResultat> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { ok: false, grunn: 'Bare eier kan hente vær.' }
  const supabase = await lagSupabaseServerKlient()
  return hentVaerMedKlient(supabase)
}
