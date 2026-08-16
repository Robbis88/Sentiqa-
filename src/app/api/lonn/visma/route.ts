import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { tilLonnslinjer } from '@/lib/lonn/tidsband'
import { byggVismafil, medBom, vismaFilnavn } from '@/lib/lonn/vismafil'

// Fila lastes NED, aldri vises. Åpnes den i norsk Excel og lagres, blir
// 9.00 til 9,00 og anførselstegnene forsvinner — og da må Azets legge inn
// alt manuelt. Derfor octet-stream og Content-Disposition: attachment.
export async function GET(req: NextRequest) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return NextResponse.json({ feil: 'Ikke tilgang.' }, { status: 403 })
  }

  const p = req.nextUrl.searchParams
  const stasjonId = p.get('stasjon') ?? ''
  const ar = Number(p.get('ar'))
  const maned = Number(p.get('maned'))
  if (!stasjonId || !ar || !maned || maned < 1 || maned > 12) {
    return NextResponse.json({ feil: 'Mangler stasjon, år eller måned.' }, { status: 400 })
  }

  const supabase = await lagSupabaseServerKlient()
  // RLS avgjør om brukeren får se stasjonen — treffer den ingenting, har
  // hun ikke tilgang, og da er 404 riktigere enn 403.
  const { data: stasjon } = await supabase
    .from('stasjoner').select('butikknummer').eq('id', stasjonId)
    .maybeSingle<{ butikknummer: string }>()
  if (!stasjon) return NextResponse.json({ feil: 'Ukjent stasjon.' }, { status: 404 })

  const mm = String(maned).padStart(2, '0')
  const sisteDag = new Date(Date.UTC(ar, maned, 0)).getUTCDate()
  const { data } = await supabase
    .from('stempling')
    .select('ansatt_nr, dato, fra_tid, til_tid')
    .eq('stasjon_id', stasjonId)
    .eq('betalt', true)
    .gte('dato', `${ar}-${mm}-01`)
    .lte('dato', `${ar}-${mm}-${sisteDag}`)
    .order('dato')

  const rader = (data ?? []) as
    { ansatt_nr: string; dato: string; fra_tid: string; til_tid: string }[]
  if (rader.length === 0) {
    return NextResponse.json({ feil: 'Ingen stemplinger i perioden.' }, { status: 404 })
  }

  const linjer = tilLonnslinjer(rader.map((r) => ({
    ansattNr: r.ansatt_nr,
    dato: r.dato,
    fraTid: r.fra_tid.slice(0, 5),
    tilTid: r.til_tid.slice(0, 5),
  })))

  // Kostnadsstedet ER butikknummeret — bekreftet mot Timefordeling for
  // alle fem stasjonene (4177 Lone, 4185 Dale, 9038 Laguneparken,
  // 9145 Varden, 9467 Bønes).
  const kropp = medBom(byggVismafil(linjer, stasjon.butikknummer))
  return new NextResponse(kropp as unknown as BodyInit, {
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition':
        `attachment; filename="${vismaFilnavn(stasjon.butikknummer, ar, maned)}"`,
      'Cache-Control': 'no-store',
    },
  })
}
