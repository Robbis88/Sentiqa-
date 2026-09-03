import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentUkedata } from '@/lib/ukebrief/hent'
import { byggUkebrief } from '@/lib/ukebrief/bygg'
import { lagPdf, filnavn } from '@/lib/ukebrief/pdf'

// =====================================================================
// Ukebriefen som PDF-nedlasting.
//
// SAMME PORTNER SOM SIDA, og stasjonen leses med den vanlige
// serverklienten — ikke admin. Er stasjonen ikke din, finnes den ikke,
// og da finnes det ikke noe brev å laste ned. En eksportrute som gikk
// utenom RLS ville vært en vei rundt hele tilgangsmodellen, og den
// slags huller pleier å bli laget nettopp i eksportruter.
//
// `no-store`: brevet inneholder stasjonens tall. Det skal ikke ligge i
// en mellomlagring noen andre kan treffe.
// =====================================================================

export const maxDuration = 60

export async function GET(req: NextRequest) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return NextResponse.json({ feil: 'Ikke tilgang.' }, { status: 403 })
  }

  const stasjonId = req.nextUrl.searchParams.get('stasjon') ?? ''
  const uke = req.nextUrl.searchParams.get('uke') ?? ''
  if (!/^[0-9a-f-]{36}$/i.test(stasjonId) || !/^\d{4}-\d{2}-\d{2}$/.test(uke)) {
    return NextResponse.json({ feil: 'Ugyldig stasjon eller uke.' }, { status: 400 })
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: stasjon } = await supabase
    .from('stasjoner').select('id, butikknummer, navn')
    .eq('id', stasjonId).is('slettet_tid', null)
    .maybeSingle<{ id: string; butikknummer: string; navn: string }>()
  if (!stasjon) return NextResponse.json({ feil: 'Fant ikke stasjonen.' }, { status: 404 })

  const data = await hentUkedata(supabase, stasjon, uke)
  // 404 og ikke en tom PDF: en fil med overskrift og ingenting under ser
  // ut som en uke der ingenting skjedde.
  if (!data) return NextResponse.json({ feil: 'Ingen data for uken.' }, { status: 404 })

  const brief = byggUkebrief(data)
  const pdf = await lagPdf(brief)

  return new NextResponse(new Uint8Array(pdf), {
    headers: {
      'content-type': 'application/pdf',
      'content-disposition': `attachment; filename="${filnavn(brief)}"`,
      'cache-control': 'no-store',
    },
  })
}
