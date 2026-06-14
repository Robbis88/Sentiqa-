import { NextResponse, type NextRequest } from 'next/server'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { genererFokusForRetailer } from '@/lib/ai/fokus'
import { genererLederstotteForRetailer } from '@/lib/ai/lederstotte'
import { kjorRegnskapsanalyse } from '@/lib/ai/regnskapsanalyse'
import { hentEllerLagUkerapport } from '@/lib/ukerapport'
import { hentVaerMedKlient } from '@/lib/vaer'
import { importerAlleKalenderKilder } from '@/lib/ical'
import { hentTrafikkMedKlient } from '@/lib/trafikk'

// AI-nattjobb (Vercel Cron). Henter vær (analyse-input til produksjonsplan) +
// regenererer auto-fokus + lederstøtte for ALLE kjeder, så eierne våkner til
// ferske vurderinger. Beskyttet av CRON_SECRET (Vercel sender den i
// Authorization-headeren). Kjører som service-role.
export const maxDuration = 300

export async function GET(req: NextRequest) {
  const auth = req.headers.get('authorization')
  if (!env.CRON_SECRET || auth !== `Bearer ${env.CRON_SECRET}`) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }

  const supabase = lagSupabaseAdminKlient()

  // Vær først — analyse-input til produksjonsplanen (alle stasjoner m/koordinater).
  let vaer: Awaited<ReturnType<typeof hentVaerMedKlient>> | null = null
  try {
    vaer = await hentVaerMedKlient(supabase)
  } catch {
    // værfeil skal ikke velte nattjobben
  }

  // iCal-arrangementer → forslag (lederen bekrefter senere).
  let kalender: Awaited<ReturnType<typeof importerAlleKalenderKilder>> | null = null
  try {
    kalender = await importerAlleKalenderKilder(supabase)
  } catch {
    // kalenderfeil skal ikke velte nattjobben
  }

  // Trafikk (Vegvesen) → døgnvolum for stasjoner med aktiv måling.
  let trafikk: Awaited<ReturnType<typeof hentTrafikkMedKlient>> | null = null
  try {
    trafikk = await hentTrafikkMedKlient(supabase)
  } catch {
    // trafikkfeil skal ikke velte nattjobben
  }

  const { data: retailers } = await supabase.from('retailers').select('id').is('slettet_tid', null)

  let kjeder = 0
  for (const r of (retailers ?? []) as { id: string }[]) {
    try {
      await genererFokusForRetailer(supabase, r.id)
    } catch {
      // hopp over – én kjede skal ikke velte hele jobben
    }
    try {
      await genererLederstotteForRetailer(supabase, r.id)
    } catch {
      // hopp over
    }
    try {
      // Admin-regnskapsanalyse (fallback hvis import-AI-en timet ut; race-guard internt).
      await kjorRegnskapsanalyse(supabase, r.id)
    } catch {
      // hopp over
    }
    try {
      // Ukerapport m/AI-sammendrag (genereres her, ikke i dashbord-render).
      const { data: st } = await supabase.from('stasjoner').select('id, navn, butikknummer').eq('retailer_id', r.id).is('slettet_tid', null)
      await hentEllerLagUkerapport(supabase, r.id, (st ?? []) as { id: string; navn: string; butikknummer: string }[], true)
    } catch {
      // hopp over
    }
    kjeder++
  }

  return NextResponse.json({ ok: true, kjeder, vaer, kalender, trafikk })
}
