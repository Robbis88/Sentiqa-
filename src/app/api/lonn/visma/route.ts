import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { LONNSART, tilLonnslinjer } from '@/lib/lonn/tidsband'
import { delEtterLonnsform, type Lonnsform } from '@/lib/lonn/lonnsform'
import { byggVismafil, medBom, vismaFilnavn } from '@/lib/lonn/vismafil'
import { hentAapneVakter } from '@/lib/stempling/aapne'
import { kanLageLonnsfil } from '@/lib/stempling/avled'
import { loggOppslag } from '@/lib/personvern/logg'

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
  // v_stempling_aktiv, ikke `stempling`: under parallellkjoring finnes
  // samme vakt to ganger, en fra easy@work og en fra nettbrettet, og de
  // kolliderer ikke fordi minuttene er ulike. Viewet holder den kilden
  // som teller for stasjonen (0111). Leses tabellen direkte, dobles
  // timene i lonnsfila.
  const { data } = await supabase
    .from('v_stempling_aktiv')
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

  // ÅPEN VAKT SPERRER FILA. En vakt uten utstempling har ingen sluttid,
  // og å gjette den ville betydd å gjette hva noen skal ha betalt.
  // Sperren står her og ikke bare i knappen, av samme grunn som
  // lønnsformsperren under: URL-en kan kalles direkte.
  //
  // `null` er ikke tom liste. Klarer vi ikke svare på om det finnes åpne
  // vakter, lager vi ikke fila — «jeg vet ikke» skal aldri passere som
  // «alt er i orden» på vei inn i lønn.
  const aapne = await hentAapneVakter(supabase, stasjonId, ar, maned)
  if (aapne === null) {
    return NextResponse.json(
      { feil: 'Fikk ikke sjekket om noen står innstemplet. Fila lages ikke.' },
      { status: 503 })
  }
  if (!kanLageLonnsfil(aapne)) {
    return NextResponse.json({
      feil: `${aapne.length} ${aapne.length === 1 ? 'vakt står' : 'vakter står'} `
        + 'uten utstempling. Lukk dem på /lonn før fila lages.',
      ansatte: [...new Set(aapne.map((v) => v.ansattNr))],
    }, { status: 409 })
  }

  const linjer = tilLonnslinjer(rader.map((r) => ({
    ansattNr: r.ansatt_nr,
    dato: r.dato,
    fraTid: r.fra_tid.slice(0, 5),
    tilTid: r.til_tid.slice(0, 5),
  })))

  // Fastlønnede og tilkallingsvikarer stempler, men skal ikke i fila.
  // Sperren ligger her, ikke bare i knappen på siden: en URL kan kalles
  // direkte, og en fil med feil innhold er verre enn ingen fil.
  const { data: avtaler } = await supabase
    .from('ansatt_avtale')
    .select('ansatt_nr, lonnsform')
    .eq('stasjon_id', stasjonId)
  const lonnsform = new Map<string, Lonnsform | null>(
    ((avtaler ?? []) as { ansatt_nr: string; lonnsform: Lonnsform | null }[])
      .map((a) => [a.ansatt_nr, a.lonnsform]))

  const fordeling = delEtterLonnsform(linjer, lonnsform, LONNSART.timelonn)
  if (fordeling.uavklart.length > 0) {
    return NextResponse.json({
      feil: `${fordeling.uavklart.length} ansatte mangler lønnsform. `
        + 'Sett den på /lonn før fila lages.',
      ansatte: fordeling.uavklart.map((u) => u.ansattNr),
    }, { status: 409 })
  }
  if (fordeling.med.length === 0) {
    return NextResponse.json(
      { feil: 'Ingen timelønnede med timer i perioden.' }, { status: 404 })
  }

  // Kostnadsstedet ER butikknummeret — bekreftet mot Timefordeling for
  // alle fem stasjonene (4177 Lone, 4185 Dale, 9038 Laguneparken,
  // 9145 Varden, 9467 Bønes).
  await loggOppslag(supabase, {
    retailerId: bruker.retailerId ?? '',
    stasjonId,
    handling: 'lonnsfil_lastet_ned',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { ar, maned, ansatte: new Set(fordeling.med.map((l) => l.ansattNr)).size },
  })

  const kropp = medBom(byggVismafil(fordeling.med, stasjon.butikknummer))
  return new NextResponse(kropp as unknown as BodyInit, {
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition':
        `attachment; filename="${vismaFilnavn(stasjon.butikknummer, ar, maned)}"`,
      'Cache-Control': 'no-store',
    },
  })
}
