import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { fyllUt } from '@/lib/kontrakt/docx'
import {
  byggVerdier, erMindreaarig, type Ansettelsesform, type Rolle,
} from '@/lib/kontrakt/felter'
import { loggOppslag } from '@/lib/personvern/logg'

// Genererer én kontrakt og laster den ned. Malen hentes fra Storage og
// fylles ut — den skrives aldri om. Ordlyden er juridisk gjennomgått, og
// den er hele grunnen til å bruke Virkes maler.
//
// POST, ikke GET: hver generering skriver en rad i ansatt_kontrakt, og en
// GET-lenke ville blitt hentet på forhånd av nettleseren. Da lå det et
// utkast der ingen hadde bedt om.
const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']

/** «2026-09-01» → «1. september 2026». Malen ber om dato, måned og år. */
const norskDato = (iso: string) =>
  `${Number(iso.slice(8, 10))}. ${MND[Number(iso.slice(5, 7)) - 1]} ${iso.slice(0, 4)}`

export async function POST(req: NextRequest) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return NextResponse.json({ feil: 'Ikke tilgang.' }, { status: 403 })
  }

  const fd = await req.formData()
  const tekst = (n: string) => {
    const v = fd.get(n)
    return typeof v === 'string' ? v.trim() : ''
  }
  const stasjonId = tekst('stasjon')
  const ansattNr = tekst('ansatt')
  const form = (tekst('form') || 'fast') as Ansettelsesform
  const rolle = (tekst('rolle') || 'ansatt') as Rolle
  if (!stasjonId || !ansattNr) {
    return NextResponse.json({ feil: 'Mangler stasjon eller ansatt.' }, { status: 400 })
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: retailer }, { data: stasjon }, { data: avtale }] = await Promise.all([
    supabase.from('retailers')
      .select('navn, org_nr, tariffbundet, kontrakt_standardfelt')
      .maybeSingle<{
        navn: string; org_nr: string | null; tariffbundet: boolean
        kontrakt_standardfelt: Record<string, string>
      }>(),
    supabase.from('stasjoner').select('navn, adresse').eq('id', stasjonId)
      .maybeSingle<{ navn: string; adresse: string | null }>(),
    supabase.from('ansatt_avtale')
      .select('navn, fodselsdato, stillingsprosent, timesats, skiftordning, stillingstittel')
      .eq('stasjon_id', stasjonId).eq('ansatt_nr', ansattNr)
      .maybeSingle<{
        navn: string; fodselsdato: string | null; stillingsprosent: number | null
        timesats: number | null; skiftordning: 'ordinaer' | 'to_skift' | null
        stillingstittel: string | null
      }>(),
  ])
  if (!stasjon) return NextResponse.json({ feil: 'Ukjent stasjon.' }, { status: 404 })
  if (!avtale) {
    return NextResponse.json(
      { feil: 'Ingen ansattkort. Fyll ut fødselsdato og stilling først.' }, { status: 404 })
  }

  // Mindreårig måles på tiltredelsesdatoen, ikke på i dag: skriver du en
  // kontrakt i mai for en som fyller 18 i juni, er det juni-reglene som
  // gjelder fra tiltredelsen.
  const tiltredelse = /^\d{4}-\d{2}-\d{2}$/.test(tekst('tiltredelse'))
    ? tekst('tiltredelse') : null
  const mindreaarig = erMindreaarig(
    avtale.fodselsdato, tiltredelse ?? new Date().toISOString().slice(0, 10))

  const { data: mal } = await supabase
    .from('kontraktmal')
    .select('id, versjon, storage_sti, filnavn')
    .eq('ansettelsesform', form)
    .eq('rolle', rolle)
    .eq('mindreaarig', mindreaarig)
    .eq('tariffbundet', retailer?.tariffbundet ?? true)
    .eq('aktiv', true)
    .order('versjon', { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string; versjon: number; storage_sti: string; filnavn: string }>()
  if (!mal) {
    return NextResponse.json({
      feil: `Ingen mal for ${form}/${rolle}${mindreaarig ? '/mindreårig' : ''}. `
        + 'Last den opp under Maler.',
    }, { status: 404 })
  }

  const ned = await supabase.storage.from('raa-filer').download(mal.storage_sti)
  if (ned.error || !ned.data) {
    return NextResponse.json({ feil: 'Fant ikke malfila i Storage.' }, { status: 404 })
  }

  const svar: Record<string, string> = {}
  for (const [k, v] of fd.entries()) {
    if (k.startsWith('f.') && typeof v === 'string' && v.trim()) svar[k.slice(2)] = v.trim()
  }
  if (avtale.stillingstittel && !svar.stillingstittel) {
    svar.stillingstittel = avtale.stillingstittel
  }
  // Tiltredelsen kommer som dato, ikke som fritekst: den skal både stå i
  // dokumentet og lagres som gjelder_fra.
  if (tiltredelse) svar['dato, måned, år'] = norskDato(tiltredelse)

  const verdier = byggVerdier({
    kjede: {
      navn: retailer?.navn ?? '',
      orgNr: retailer?.org_nr ?? null,
      standardfelt: retailer?.kontrakt_standardfelt ?? {},
    },
    stasjon: { navn: stasjon.navn, adresse: stasjon.adresse },
    ansatt: {
      navn: avtale.navn,
      fodselsdato: avtale.fodselsdato,
      stillingsprosent: avtale.stillingsprosent,
      timesats: avtale.timesats != null ? Number(avtale.timesats) : null,
      skiftordning: avtale.skiftordning,
    },
    svar,
  })

  const ut = fyllUt(new Uint8Array(await ned.data.arrayBuffer()), verdier)

  // Lagre HVA som ble generert, ikke bare at noe ble det. Uten verdiene
  // og malversjonen kan dokumentet ikke gjenskapes, og da er en signatur
  // bare et tidsstempel uten tekst.
  const { error } = await supabase.from('ansatt_kontrakt').insert({
    stasjon_id: stasjonId,
    ansatt_nr: ansattNr,
    ansatt_navn: avtale.navn,
    mal_id: mal.id,
    mal_versjon: mal.versjon,
    verdier,
    gjelder_fra: tiltredelse,
    status: 'utkast',
    opprettet_av: bruker.id,
  })
  if (error) return NextResponse.json({ feil: error.message }, { status: 500 })

  await loggOppslag(supabase, {
    retailerId: bruker.retailerId ?? '',
    stasjonId,
    ansattNr,
    ansattNavn: avtale.navn,
    handling: 'kontrakt_generert',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { form, rolle, malVersjon: mal.versjon },
  })

  const navn = `${avtale.navn.replace(/[^\wÆØÅæøå -]/g, '')} - ${form}.docx`
  return new NextResponse(ut as unknown as BodyInit, {
    headers: {
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(navn)}`,
      'Cache-Control': 'no-store',
    },
  })
}
