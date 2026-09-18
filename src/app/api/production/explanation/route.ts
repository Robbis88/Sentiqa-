import { NextResponse } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// Forklaringen leses fra samme spor som ble lagret sammen med planlinjen.
// Route-handleren gjør ingen ny prognose og er derfor ikke en alternativ motor.
export async function GET(req: Request) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return NextResponse.json({ feil: 'Ikke tilgjengelig for denne rollen.' }, { status: 403 })
  const url = new URL(req.url)
  const stationId = url.searchParams.get('stationId')
  const productId = url.searchParams.get('productId')
  const date = url.searchParams.get('date')
  if (!stationId || !productId || !date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return NextResponse.json({ feil: 'stationId, productId og date må oppgis.' }, { status: 400 })
  }
  const supabase = await lagSupabaseServerKlient()
  const byId = await supabase.from('produksjonsplan_linjer')
    .select('id, stasjon_id, dato, varenavn, varegruppe_kode, varegruppe_navn, foreslatt, planlagt, start_antall, forklaringsspor')
    .eq('id', productId).eq('stasjon_id', stationId).eq('dato', date).maybeSingle()
  if (byId.error) return NextResponse.json({ feil: 'Kunne ikke hente forklaringen.' }, { status: 500 })
  if (!byId.data) return NextResponse.json({ feil: 'Fant ikke produktet på denne planen.' }, { status: 404 })
  if (!byId.data.forklaringsspor) {
    return NextResponse.json({ feil: 'Jeg finner forslaget, men beregningsgrunnlaget ble ikke lagret for denne kjøringen.' }, { status: 409 })
  }
  return NextResponse.json({
    productId: byId.data.id,
    productName: byId.data.varenavn,
    date: byId.data.dato,
    stationId: byId.data.stasjon_id,
    groupCode: byId.data.varegruppe_kode,
    groupName: byId.data.varegruppe_navn,
    modelProposal: byId.data.foreslatt,
    plannedQuantity: byId.data.planlagt,
    startQuantity: byId.data.start_antall,
    explanation: byId.data.forklaringsspor,
  })
}
