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
import { kjorBacktestAlle } from '@/lib/backtest'
import { behandleKoen } from '@/lib/import/ko'

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

  // IMPORTKØEN FØRST. Alt under — ukerapport, fokus, lederstøtte,
  // regnskapsanalyse, backtest — leser salgsdata. Behandles gårsdagens fil
  // etter at analysene har kjørt, regner de på forgårsdagens tall, hver
  // eneste natt. Rekkefølgen her er ikke tilfeldig.
  let importko: Awaited<ReturnType<typeof behandleKoen>> | null = null
  try {
    importko = await behandleKoen(supabase)
  } catch {
    // En feilende kø skal ikke velte resten av natten.
  }

  // Vær — analyse-input til produksjonsplanen (alle stasjoner m/koordinater).
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

  // Lært værprofil per stasjon (ukedagsjustert korrelasjon) → kalibrert følsomhet.
  let vaerprofil: number | null = null
  try {
    const { data } = await supabase.rpc('beregn_vaerprofil')
    vaerprofil = typeof data === 'number' ? data : null
  } catch {
    // profilfeil skal ikke velte nattjobben
  }

  // Lært vær-effekt pr kategori (avdeling + varegruppe) → datadrevet vaerfaktor.
  let kategoriVaerprofil: number | null = null
  try {
    const { data } = await supabase.rpc('beregn_kategori_vaerprofil')
    kategoriVaerprofil = typeof data === 'number' ? data : null
  } catch {
    // profilfeil skal ikke velte nattjobben
  }

  // Backtest + selvlæring: kjør prognosene bakover på historikken, mål treff,
  // oppdater kalibreringen. Etter værprofilen (bruker lært følsomhet).
  let treffsikkerhet: number | null = null
  try {
    treffsikkerhet = await kjorBacktestAlle(supabase)
  } catch {
    // backtestfeil skal ikke velte nattjobben
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

  return NextResponse.json({ ok: true, importko, kjeder, vaer, kalender, trafikk, vaerprofil, kategoriVaerprofil, treffsikkerhet })
}
