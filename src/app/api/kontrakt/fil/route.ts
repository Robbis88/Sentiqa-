import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { gjenskapKontrakt } from '@/lib/kontrakt/gjenskap'

// Laster ned igjen en kontrakt som allerede er skrevet.
//
// GET er riktig her, i motsetning til genereringen: dette skriver
// ingenting. Dokumentet bygges på nytt fra verdiene og malversjonen som
// ble lagret, så det blir identisk med det som ble lastet ned første gang.
export async function GET(req: NextRequest) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return NextResponse.json({ feil: 'Ikke tilgang.' }, { status: 403 })
  }
  const id = req.nextUrl.searchParams.get('id') ?? ''
  if (!id) return NextResponse.json({ feil: 'Mangler id.' }, { status: 400 })

  const supabase = await lagSupabaseServerKlient()
  const svar = await gjenskapKontrakt(supabase, id)
  if (!svar.ok) return NextResponse.json({ feil: svar.feil }, { status: svar.status })

  return new NextResponse(svar.docx as unknown as BodyInit, {
    headers: {
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(svar.navn)}`,
      'Cache-Control': 'no-store',
    },
  })
}
