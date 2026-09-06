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

  // Ledd som feilet uten å velte jobben. Står i svaret, ikke bare i en
  // null-verdi ingen kan skille fra «ingenting å regne på».
  const feilet: string[] = []

  // Lært værprofil per stasjon (ukedagsjustert korrelasjon) → kalibrert følsomhet.
  let vaerprofil: number | null = null
  try {
    // TRY/CATCH FANGER IKKE EN RPC-FEIL. `supabase.rpc` KASTER IKKE -
    // den returnerer `{ data: null, error }`. Uten sjekken sto
    // vaerprofilen som null og nattjobben meldte `ok: true`, mens
    // funksjonen kanskje ikke fantes i det hele tatt.
    const { data, error } = await supabase.rpc('beregn_vaerprofil')
    if (error) feilet.push(`beregn_vaerprofil: ${error.message}`)
    vaerprofil = typeof data === 'number' ? data : null
  } catch {
    // profilfeil skal ikke velte nattjobben
  }

  // Lært vær-effekt pr kategori (avdeling + varegruppe) → datadrevet vaerfaktor.
  let kategoriVaerprofil: number | null = null
  try {
    const { data, error } = await supabase.rpc('beregn_kategori_vaerprofil')
    if (error) feilet.push(`beregn_kategori_vaerprofil: ${error.message}`)
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

  // `ok` ER IKKE LENGER ALLTID SANN. En nattjobb som melder ok mens et
  // ledd feilet, er en jobb ingen ser paa igjen. `feilet` staar i
  // svaret saa den som leser loggen ser HVA som gikk galt, ikke bare at
  // et tall er null.
  return NextResponse.json({
    ok: feilet.length === 0,
    feilet,
    importko, kjeder, vaer, kalender, trafikk, vaerprofil, kategoriVaerprofil, treffsikkerhet,
  })
}
