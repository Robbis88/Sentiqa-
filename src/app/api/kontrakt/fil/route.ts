import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { gjenskapKontrakt } from '@/lib/kontrakt/gjenskap'
import { loggOppslag } from '@/lib/personvern/logg'

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

  // Det SIGNERTE eksemplaret er en fil, ikke noe som gjenskapes — det er
  // jo nettopp signaturen som ikke lar seg regne ut.
  if (req.nextUrl.searchParams.get('signert') === '1') {
    const { data: rad } = await supabase
      .from('ansatt_kontrakt').select('storage_sti, ansatt_navn').eq('id', id)
      .maybeSingle<{ storage_sti: string | null; ansatt_navn: string }>()
    if (!rad?.storage_sti) {
      return NextResponse.json({ feil: 'Ingen signert kopi lagret.' }, { status: 404 })
    }
    const ned = await supabase.storage.from('raa-filer').download(rad.storage_sti)
    if (ned.error || !ned.data) {
      return NextResponse.json({ feil: 'Fant ikke fila i Storage.' }, { status: 404 })
    }
    await loggOppslag(supabase, {
      retailerId: bruker.retailerId ?? '',
      stasjonId: null,
      ansattNavn: rad.ansatt_navn,
      handling: 'signert_lastet_ned',
      brukerId: bruker.id,
      brukerNavn: bruker.fulltNavn,
      detaljer: { kontraktId: id },
    })
    const endelse = rad.storage_sti.endsWith('.pdf') ? 'pdf' : 'docx'
    const filnavn = `${rad.ansatt_navn.replace(/[^\wÆØÅæøå -]/g, '')} - signert.${endelse}`
    return new NextResponse(ned.data as unknown as BodyInit, {
      headers: {
        'Content-Type': endelse === 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(filnavn)}`,
        'Cache-Control': 'no-store',
      },
    })
  }

  const svar = await gjenskapKontrakt(supabase, id)
  if (!svar.ok) return NextResponse.json({ feil: svar.feil }, { status: svar.status })

  await loggOppslag(supabase, {
    retailerId: bruker.retailerId ?? '',
    stasjonId: null,
    ansattNavn: svar.ansattNavn,
    handling: 'kontrakt_lastet_ned',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { kontraktId: id },
  })

  return new NextResponse(svar.docx as unknown as BodyInit, {
    headers: {
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(svar.navn)}`,
      'Cache-Control': 'no-store',
    },
  })
}
