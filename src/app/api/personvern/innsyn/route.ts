import { NextResponse, type NextRequest } from 'next/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import {
  innsynFilnavn, innsynTilMarkdown, type Seksjon,
} from '@/lib/personvern/innsyn'
import { loggOppslag } from '@/lib/personvern/logg'

// Innsyn etter GDPR art. 15 for én ansatt.
//
// Samler fra alle tre identitetene personen har i systemet — ansattnummer,
// PIN-en på nettbrettet, og fritekst navn — og merker hver del med hvordan
// den ble funnet. Se src/lib/personvern/innsyn.ts for hvorfor det er
// nødvendig.
export async function GET(req: NextRequest) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return NextResponse.json({ feil: 'Ikke tilgang.' }, { status: 403 })
  }
  const p = req.nextUrl.searchParams
  const stasjonId = p.get('stasjon') ?? ''
  const ansattNr = p.get('ansatt') ?? ''
  if (!stasjonId || !ansattNr) {
    return NextResponse.json({ feil: 'Mangler stasjon eller ansatt.' }, { status: 400 })
  }

  const supabase = await lagSupabaseServerKlient()
  const [{ data: stasjon }, { data: retailer }, { data: person }] = await Promise.all([
    supabase.from('stasjoner').select('navn').eq('id', stasjonId)
      .maybeSingle<{ navn: string }>(),
    supabase.from('retailers').select('navn, oppbevaring_maaneder')
      .maybeSingle<{ navn: string; oppbevaring_maaneder: number }>(),
    supabase.from('v_persondata_alder').select('navn, sist_aktivitet')
      .eq('stasjon_id', stasjonId).eq('ansatt_nr', ansattNr)
      .maybeSingle<{ navn: string; sist_aktivitet: string }>(),
  ])
  if (!stasjon) return NextResponse.json({ feil: 'Ukjent stasjon.' }, { status: 404 })
  if (!person) {
    return NextResponse.json(
      { feil: 'Fant ingen opplysninger om denne ansatte.' }, { status: 404 })
  }
  const navn = person.navn

  // Navnetreffet er ETT navn, og navn er ikke en nøkkel. Derfor merkes
  // alt som hentes på denne måten som usikkert i dokumentet.
  const [
    { data: avtale }, { data: stempl }, { data: kontrakter },
    { data: fravaer }, { data: fasteVakter }, { data: tabletBruker },
  ] = await Promise.all([
    supabase.from('ansatt_avtale')
      .select('navn, fodselsdato, stillingstittel, stillingsprosent, timesats, skiftordning, lonnsform, har_rammeavtale, oppdatert_tid')
      .eq('stasjon_id', stasjonId).eq('ansatt_nr', ansattNr).maybeSingle(),
    supabase.from('stempling')
      .select('dato, fra_tid, til_tid, minutter, betalt')
      .eq('stasjon_id', stasjonId).eq('ansatt_nr', ansattNr)
      .order('dato', { ascending: false }).limit(2000),
    supabase.from('ansatt_kontrakt')
      .select('opprettet_tid, gjelder_fra, status, mal_versjon, signert_tid, verdier')
      .eq('stasjon_id', stasjonId).eq('ansatt_nr', ansattNr)
      .order('opprettet_tid', { ascending: false }),
    supabase.from('bemanning_fravaer')
      .select('fra_dato, til_dato, arsak').eq('stasjon_id', stasjonId).eq('navn', navn),
    supabase.from('bemanning_fast_vakt')
      .select('ukedag, fra_time, til_time, timelonnet')
      .eq('stasjon_id', stasjonId).eq('navn', navn),
    supabase.from('ansatte')
      .select('id, aktiv, opprettet_tid').eq('stasjon_id', stasjonId).eq('navn', navn)
      .is('slettet_tid', null).maybeSingle<{ id: string; aktiv: boolean; opprettet_tid: string }>(),
  ])

  const a = avtale as {
    fodselsdato: string | null; stillingstittel: string | null
    stillingsprosent: number | null; timesats: number | null
    skiftordning: string | null; lonnsform: string | null
    har_rammeavtale: boolean; oppdatert_tid: string
  } | null

  const seksjoner: Seksjon[] = []

  seksjoner.push({
    tittel: 'Ansattkort',
    kobling: 'ansattnummer',
    hva: 'Opplysningene arbeidsavtalen din bygger på',
    kolonner: ['Opplysning', 'Registrert'],
    rader: a ? [
      ['Fødselsdato', a.fodselsdato],
      ['Stillingstittel', a.stillingstittel],
      ['Stillingsprosent', a.stillingsprosent != null ? `${a.stillingsprosent} %` : null],
      ['Timesats', a.timesats != null ? String(a.timesats) : null],
      ['Ukentlig arbeidstid', a.skiftordning === 'to_skift' ? '35,5 t' : a.skiftordning ? '37,5 t' : null],
      ['Lønnsform', a.lonnsform],
      ['Rammeavtale om tilkalling', a.har_rammeavtale ? 'Ja' : 'Nei'],
      ['Sist endret', a.oppdatert_tid.slice(0, 10)],
    ] : [],
  })

  const st = (stempl ?? []) as {
    dato: string; fra_tid: string; til_tid: string; minutter: number; betalt: boolean
  }[]
  seksjoner.push({
    tittel: 'Stemplinger',
    kobling: 'ansattnummer',
    hva: 'Når du har stemplet inn og ut, fra easy@work',
    kolonner: ['Dato', 'Fra', 'Til', 'Minutter', 'Betalt'],
    rader: st.map((r) => [
      r.dato, r.fra_tid.slice(0, 5), r.til_tid.slice(0, 5), r.minutter,
      r.betalt ? 'Ja' : 'Nei',
    ]),
  })

  const kt = (kontrakter ?? []) as {
    opprettet_tid: string; gjelder_fra: string | null; status: string
    mal_versjon: number | null; signert_tid: string | null
    verdier: Record<string, string>
  }[]
  seksjoner.push({
    tittel: 'Arbeidsavtaler',
    kobling: 'ansattnummer',
    hva: 'Avtaler som er skrevet for deg, og verdiene som ble fylt inn',
    kolonner: ['Skrevet', 'Gjelder fra', 'Status', 'Mal', 'Signert', 'Innhold'],
    rader: kt.map((k) => [
      k.opprettet_tid.slice(0, 10), k.gjelder_fra, k.status,
      k.mal_versjon != null ? `v${k.mal_versjon}` : null,
      k.signert_tid ? k.signert_tid.slice(0, 10) : null,
      Object.entries(k.verdier ?? {}).map(([f, v]) => `${f}: ${v}`).join('; '),
    ]),
  })

  const fv = (fravaer ?? []) as { fra_dato: string; til_dato: string; arsak: string | null }[]
  seksjoner.push({
    tittel: 'Ferie og fravær',
    kobling: 'navn',
    hva: 'Registrert fravær i bemanningsplanen',
    kolonner: ['Fra', 'Til', 'Årsak'],
    rader: fv.map((f) => [f.fra_dato, f.til_dato, f.arsak]),
  })

  const UKEDAG = ['', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag', 'søndag']
  const fvk = (fasteVakter ?? []) as {
    ukedag: number; fra_time: number; til_time: number; timelonnet: boolean
  }[]
  seksjoner.push({
    tittel: 'Faste vakter',
    kobling: 'navn',
    hva: 'Vakter du står oppført med fast i bemanningsplanen',
    kolonner: ['Dag', 'Fra', 'Til', 'Lønnsform'],
    rader: fvk.map((v) => [
      UKEDAG[v.ukedag] ?? String(v.ukedag),
      `${String(v.fra_time).padStart(2, '0')}:00`,
      `${String(v.til_time).padStart(2, '0')}:00`,
      v.timelonnet ? 'Timelønn' : 'Fastlønn',
    ]),
  })

  // Nettbrettidentiteten. Finnes den, henger rutiner, sjekkpunkt,
  // IK-avlesninger og merker på DEN, ikke på ansattnummeret.
  const tb = tabletBruker
  const tabletRader: (string | number | null)[][] = []
  if (tb) {
    const [{ count: nRutiner }, { count: nSjekk }, { count: nIk }, { count: nMerker }, { count: nPuls }] =
      await Promise.all([
        supabase.from('rutine_utforinger').select('id', { count: 'exact', head: true })
          .eq('ansatt_id', tb.id),
        supabase.from('sjekkpunkt_svar').select('id', { count: 'exact', head: true })
          .eq('ansatt_id', tb.id),
        supabase.from('ik_avlesninger').select('id', { count: 'exact', head: true })
          .eq('ansatt_id', tb.id),
        supabase.from('tildelte_merker').select('id', { count: 'exact', head: true })
          .eq('ansatt_id', tb.id),
        supabase.from('puls_svar').select('id', { count: 'exact', head: true })
          .eq('ansatt_id', tb.id),
      ])
    tabletRader.push(
      ['Registrert på nettbrettet', tb.opprettet_tid.slice(0, 10)],
      ['Aktiv', tb.aktiv ? 'Ja' : 'Nei'],
      ['Utførte rutiner', nRutiner ?? 0],
      ['Besvarte sjekkpunkt', nSjekk ?? 0],
      ['IK-mat-avlesninger', nIk ?? 0],
      ['Tildelte merker', nMerker ?? 0],
      ['Puls-svar', nPuls ?? 0],
    )
  }
  seksjoner.push({
    tittel: 'Aktivitet på nettbrettet',
    kobling: 'navn',
    hva: 'Registreringer gjort med din PIN. Antall — be om detaljene hvis du vil se dem',
    kolonner: ['Opplysning', 'Verdi'],
    rader: tabletRader,
  })

  const iDag = new Date().toISOString().slice(0, 10)
  const md = innsynTilMarkdown({
    navn,
    ansattNr,
    stasjon: stasjon.navn,
    kjede: retailer?.navn ?? '',
    laget: iDag,
    oppbevaringMaaneder: retailer?.oppbevaring_maaneder ?? 60,
    seksjoner,
  })

  await loggOppslag(supabase, {
    retailerId: bruker.retailerId ?? '',
    stasjonId,
    ansattNr,
    ansattNavn: navn,
    handling: 'innsyn',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { seksjoner: seksjoner.filter((s) => s.rader.length > 0).length },
  })

  return new NextResponse(md, {
    headers: {
      'Content-Type': 'text/markdown; charset=utf-8',
      'Content-Disposition':
        `attachment; filename*=UTF-8''${encodeURIComponent(innsynFilnavn(navn, iDag))}`,
      'Cache-Control': 'no-store',
    },
  })
}
