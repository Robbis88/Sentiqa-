import 'server-only'
import type Anthropic from '@anthropic-ai/sdk'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { BUTIKKSJEF_KOSTNAD_KODER } from '@/lib/regnskap-tilgang'
import { UTELAT_KODER } from '@/lib/avdelinger'
import { byggSvar, type Verktoysvar } from './svar'
import { hentScope, velgStasjoner, etikettKart, type Stasjon } from './scope'
import { lagPeriode, idagOslo, manederIPeriode, type Periode, type Periodeinput } from './periode'
import { les, lesAlle, erLesefeil, type Leseresultat } from './les'

// =====================================================================
// Datakatalogen AI-en resonerer over.
//
// IKKE ETT VERKTØY PER SPØRSMÅL. Hvert verktøy tar stasjon(er) og en
// periode, slik at «hvordan ligger Dale an mot BP i august» og «hvilken
// av mine fem stasjoner ligger lengst bak BP i august» er det SAMME
// kallet med forskjellig scope. Det er også hvorfor eieren ikke trenger
// en egen bakdør: han har bare et større scope.
//
// RLS ER GRENSA, IKKE PROMPTEN. Alle verktøy kjører på brukerens egen
// Supabase-klient (anon-nøkkel + cookie-sesjon), aldri service_role.
// Ingen verktøy her tar imot en retailer_id eller et stasjon-id fra
// modellen — de tar butikknumre og slår dem opp i scopet først.
// =====================================================================

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>
export type VerktoyKtx = { supabase: Klient; bruker: InnloggetBruker }

export type Verktoy = {
  schema: Anthropic.Tool
  /** Handlingsverktøy som bare eier får se. Lesing gates av RLS, ikke her. */
  kunAdmin?: boolean
  kjor: (input: Record<string, unknown>, ktx: VerktoyKtx) => Promise<unknown>
}

// --- Felles skjemabiter ----------------------------------------------

const STASJON_FELT = {
  stasjoner: {
    type: 'array' as const,
    items: { type: 'string' as const },
    description:
      'Butikknummer eller stasjonsnavn. Utelat for ALLE stasjoner brukeren '
      + 'har tilgang til — det er slik du spør om hele clusteret.',
  },
}

const PERIODE_FELT = {
  fra: { type: 'string' as const, description: 'YYYY-MM-DD' },
  til: { type: 'string' as const, description: 'YYYY-MM-DD' },
  maaned: { type: 'string' as const, description: 'YYYY-MM — hele måneden' },
  aar: { type: 'number' as const, description: 'Årstall — hele året' },
}

function periodeInput(input: Record<string, unknown>): Periodeinput {
  return {
    fra: typeof input.fra === 'string' ? input.fra : undefined,
    til: typeof input.til === 'string' ? input.til : undefined,
    maaned: typeof input.maaned === 'string' ? input.maaned : undefined,
    aar: typeof input.aar === 'number' || typeof input.aar === 'string' ? input.aar : undefined,
  }
}

// --- Motoren bak hvert stasjonsverktøy -------------------------------

type Oppsett<R> = {
  domene: string
  kilder: string[]
  /**
   * Rollen som kreves for å lese domenet i det hele tatt. Speiler RLS —
   * den håndhever, dette forklarer. Uten den ville en butikksjef fått
   * `ingen_registrering` på et domene hun aldri hadde tilgang til, og
   * det leses som «alt er i orden».
   */
  kunEier?: boolean
  /** Hvorfor eier-kravet finnes, med kilde. Går rett til brukeren. */
  eierBegrunnelse?: string
  periodisert?: boolean
  standardPeriode?: (idag: string) => Periodeinput
  neste?: string[]
  merknad?: string[]
  hent: (a: {
    supabase: Klient
    stasjoner: Stasjon[]
    periode: Periode | null
    input: Record<string, unknown>
    idag: string
  }) => Promise<Leseresultat<R>>
  stasjonAv: (rad: R) => string | null | undefined
  form: (rader: R[], kart: Map<string, string>, periode: Periode | null) => unknown[]
  /** Sant når radene finnes, men alt som ER målingen er null. */
  erMaltNull?: (rader: R[]) => boolean
}

async function kjorStasjonsverktoy<R>(
  o: Oppsett<R>,
  input: Record<string, unknown>,
  { supabase, bruker }: VerktoyKtx,
): Promise<Verktoysvar> {
  const idag = idagOslo()

  const scope = await hentScope(supabase, bruker.rolle)
  if ('feil' in scope) {
    return byggSvar({ domene: o.domene, kilder: o.kilder, feil: scope.feil })
  }

  if (o.kunEier && !scope.erEier) {
    return byggSvar({
      domene: o.domene,
      kilder: o.kilder,
      ingenTilgang: true,
      neste: o.neste ?? [],
      merknad: [
        o.eierBegrunnelse
          ?? 'Dette domenet er forbeholdt eier/retailer_admin i databasen.',
      ],
    })
  }

  const { valgte, utenfor } = velgStasjoner(scope, input.stasjoner)

  // Ingenting av det brukeren skrev traff scopet. Da spør vi ikke basen
  // i det hele tatt — ikke fordi RLS ville sluppet noe gjennom, men
  // fordi svaret skal si «utenfor tilgang», ikke «ingen data».
  if (valgte.length === 0) {
    return byggSvar({
      domene: o.domene,
      kilder: o.kilder,
      scope: { forespurt: [], utenfor_tilgang: utenfor },
      neste: [],
    })
  }

  let periode: Periode | null = null
  if (o.periodisert !== false) {
    const p = lagPeriode(periodeInput(input), idag, o.standardPeriode?.(idag))
    if ('feil' in p) {
      return byggSvar({ domene: o.domene, kilder: o.kilder, feil: p.feil })
    }
    periode = p
  }

  const res = await o.hent({ supabase, stasjoner: valgte, periode, input, idag })
  if (erLesefeil(res)) {
    return byggSvar({
      domene: o.domene,
      kilder: o.kilder,
      scope: { forespurt: valgte.map((s) => s.butikknummer), utenfor_tilgang: utenfor },
      periode: periode ?? undefined,
      feil: res.feil,
      manglerKilde: res.manglerKilde,
      neste: o.neste ?? [],
    })
  }

  const kart = etikettKart(valgte)
  const medRad = new Set<string>()
  for (const r of res.rader) {
    const sid = o.stasjonAv(r)
    if (sid) medRad.add(sid)
  }

  const utenRegistrering = valgte
    .filter((s) => !medRad.has(s.id))
    .map((s) => `${s.butikknummer} ${s.navn}`)

  const alle = o.form(res.rader, kart, periode)
  const avkortet = alle.length > MAKS_RADER
  const data = avkortet ? alle.slice(0, MAKS_RADER) : alle

  return byggSvar({
    domene: o.domene,
    kilder: o.kilder,
    data,
    avkortet,
    merknad: [
      ...(o.merknad ?? []),
      ...(avkortet
        ? [
            `Viser de ${MAKS_RADER} viktigste av ${alle.length} rader. `
            + 'Si fra til brukeren at listen er avkortet, og foreslå en '
            + 'kortere periode eller færre stasjoner for hele bildet.',
          ]
        : []),
    ],
    scope: {
      forespurt: valgte.map((s) => s.butikknummer),
      besvart: valgte.filter((s) => medRad.has(s.id)).map((s) => s.butikknummer),
      uten_registrering: utenRegistrering,
      utenfor_tilgang: utenfor,
    },
    periode: periode ?? undefined,
    maltNull: res.rader.length > 0 && (o.erMaltNull?.(res.rader) ?? false),
    neste: o.neste ?? [],
  })
}

/** Kort hjelper: bygg et stasjonsverktøy med standard skjema. */
function stasjonsverktoy<R>(
  navn: string,
  beskrivelse: string,
  ekstraFelt: Record<string, unknown>,
  o: Oppsett<R>,
): Verktoy {
  return {
    schema: {
      name: navn,
      description: beskrivelse,
      input_schema: {
        type: 'object',
        properties: {
          ...STASJON_FELT,
          ...(o.periodisert === false ? {} : PERIODE_FELT),
          ...ekstraFelt,
        },
      },
    },
    kjor: (input, ktx) => kjorStasjonsverktoy(o, input, ktx),
  }
}

// TAK PAA HVA SOM SENDES INN I MODELLEN.
//
// `hent_salg` har hittil-i-aar som standardperiode, og gruppert paa
// varegruppe kan det bli tusenvis av rader per stasjon. De gaar rett inn
// i samtalen som JSON, og over nok iterasjoner sprenger det konteksten -
// da feiler kallet mot modellen, og brukeren faar «noe gikk galt» paa et
// spoersmaal som var helt rimelig.
//
// Radene er allerede sortert etter det som betyr noe (omsetning ned,
// avvik mot BP opp), saa avkortingen tar halen. Og den SIER fra:
// `avkortet` gjoer `komplett` usann, saa modellen vet at den ikke saa alt.
const MAKS_RADER = 200

const sum = (rader: { [k: string]: unknown }[], felt: string) =>
  rader.reduce((a, r) => a + (Number(r[felt]) || 0), 0)

const rund = (v: number) => Math.round(v)

// =====================================================================
// KATALOGEN
// =====================================================================

export const VERKTOY: Record<string, Verktoy> = {
  // --- Orientering ---------------------------------------------------

  list_stasjoner: {
    schema: {
      name: 'list_stasjoner',
      description:
        'List stasjonene brukeren har tilgang til. Kall denne FØRST når du '
        + 'er usikker på hva brukeren kan se — listen ER det autoriserte '
        + 'scopet. Står ikke en stasjon her, har brukeren ikke tilgang til den.',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, { supabase, bruker }) {
      const scope = await hentScope(supabase, bruker.rolle)
      if ('feil' in scope) {
        return byggSvar({ domene: 'stasjoner', kilder: ['stasjoner'], feil: scope.feil })
      }
      return byggSvar({
        domene: 'stasjoner',
        kilder: ['stasjoner'],
        data: scope.stasjoner.map((s) => ({
          butikknummer: s.butikknummer,
          navn: s.navn,
          stasjonstype: s.stasjonstype,
        })),
        scope: {
          forespurt: scope.stasjoner.map((s) => s.butikknummer),
          besvart: scope.stasjoner.map((s) => s.butikknummer),
        },
        merknad: [
          scope.erEier
            ? 'Eier: hele clusteret. Du kan sammenligne, summere og rangere på tvers.'
            : 'Butikksjef: kun egne stasjoner. Andre stasjoner finnes ikke for denne brukeren.',
        ],
      })
    },
  },

  hent_datadekning: stasjonsverktoy(
    'hent_datadekning',
    'Hvilke datakilder som faktisk har data per stasjon, og til hvilken dato. '
    + 'KALL DENNE når et annet verktøy ga «ingen_registrering» og du trenger å '
    + 'vite om det skyldes manglende import eller at det virkelig ikke skjedde noe. '
    + 'Dette er verktøyet som skiller «målt null» fra «ikke registrert».',
    {},
    {
      domene: 'datadekning',
      kilder: ['v_datadekning'],
      periodisert: false,
      neste: ['hent_salg', 'hent_regnskap'],
      hent: ({ supabase, stasjoner }) =>
        les<{ kilde: string; stasjon_id: string; dager: number; siste_dato: string | null }>(
          supabase
            .from('v_datadekning')
            .select('kilde, stasjon_id, dager, siste_dato')
            .in('stasjon_id', stasjoner.map((s) => s.id)),
          'v_datadekning',
        ),
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          kilde: r.kilde,
          antall_perioder: r.dager,
          siste: r.siste_dato,
        })),
    },
  ),

  // --- Salg ----------------------------------------------------------

  hent_salg: stasjonsverktoy(
    'hent_salg',
    'Butikksalg PER STASJON: omsetning eks. mva, antall og bruttofortjeneste '
    + '(kroner og prosent) over en periode, valgfritt brutt ned paa avdeling '
    + 'eller varegruppe. BRUK DENNE til «sammenlign stasjonene», «hvem selger '
    + 'mest», «salg og brutto hittil i aar» — den gir én rad per stasjon og '
    + 'trenger ingen avlagt maaned. Drivstoff er holdt utenfor. fra/til '
    + 'dekker perioder som «hittil i aar» og «denne uka».',
    {
      grupper: {
        type: 'string',
        enum: ['stasjon', 'avdeling', 'varegruppe', 'dag'],
        description: 'Oppløsning. Standard: stasjon.',
      },
    },
    {
      domene: 'salg',
      kilder: ['v_butikksalg'],
      standardPeriode: (idag) => ({ fra: idag.slice(0, 4) + '-01-01', til: idag }),
      neste: ['hent_datadekning', 'hent_bp_status', 'hent_kassererstatistikk'],
      merknad: [
        'Drivstoff (avdeling ENERGI / kode 10) er ikke med. Det betjener seg '
        + 'selv på pumpa og måles ikke mot butikkens drift.',
      ],
      hent: ({ supabase, stasjoner, periode, input }) => {
        const grupper = String(input.grupper ?? 'stasjon')
        const felt =
          grupper === 'avdeling'
            ? 'stasjon_id, dato, avdeling_kode, avdeling_navn, omsetning_eks_mva, antall, bto_fortjeneste_kr'
            : grupper === 'varegruppe'
              ? 'stasjon_id, dato, varegruppe_kode, varegruppe_navn, omsetning_eks_mva, antall, bto_fortjeneste_kr'
              : 'stasjon_id, dato, omsetning_eks_mva, antall, bto_fortjeneste_kr'
        return les<Salgsrad>(
          supabase
            .from('v_butikksalg')
            .select(felt)
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('dato', periode!.fra)
            .lte('dato', periode!.til)
            .limit(50000)
            .overrideTypes<Salgsrad[]>(),
          'v_butikksalg',
        )
      },
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'omsetning_eks_mva') === 0,
      form: (rader, kart, periode) => {
        void periode
        // Aggregering i klienten framfor 50 000 rader inn i modellen.
        const grupperPer = new Map<string, AggRad>()
        for (const r of rader) {
          const nokkel = [
            r.stasjon_id,
            r.avdeling_kode ?? r.varegruppe_kode ?? '',
          ].join('|')
          const e = grupperPer.get(nokkel) ?? {
            stasjon_id: r.stasjon_id,
            gruppe_kode: r.avdeling_kode ?? r.varegruppe_kode ?? null,
            gruppe_navn: r.avdeling_navn ?? r.varegruppe_navn ?? null,
            omsetning: 0,
            antall: 0,
            brutto: 0,
            dager: new Set<string>(),
          }
          e.omsetning += Number(r.omsetning_eks_mva) || 0
          e.antall += Number(r.antall) || 0
          e.brutto += Number(r.bto_fortjeneste_kr) || 0
          if (r.dato) e.dager.add(r.dato)
          grupperPer.set(nokkel, e)
        }
        return [...grupperPer.values()]
          .map((e) => ({
            stasjon: kart.get(e.stasjon_id) ?? e.stasjon_id,
            gruppe_kode: e.gruppe_kode,
            gruppe: e.gruppe_navn,
            omsetning_eks_mva_kr: rund(e.omsetning),
            antall: rund(e.antall),
            brutto_kr: rund(e.brutto),
            brutto_pst: e.omsetning ? Math.round((e.brutto / e.omsetning) * 1000) / 10 : null,
            dager_med_salg: e.dager.size,
          }))
          .sort((a, b) => b.omsetning_eks_mva_kr - a.omsetning_eks_mva_kr)
      },
    },
  ),

  hent_timesalg: stasjonsverktoy(
    'hent_timesalg',
    'Salg og kunder per klokketime, summert over perioden. Til bemanning og '
    + 'åpningstider — viser når på døgnet omsetningen faktisk kommer.',
    {},
    {
      domene: 'timesalg',
      kilder: ['timesalg'],
      neste: ['hent_bemanning', 'hent_datadekning'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<{ stasjon_id: string; time: string; salg: number | null; antall_kunder: number | null }>(
          supabase
            .from('timesalg')
            .select('stasjon_id, time, salg, antall_kunder')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('dato', periode!.fra)
            .lte('dato', periode!.til)
            .is('slettet_tid', null)
            .limit(20000),
          'timesalg',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'salg') === 0,
      form: (rader, kart) => {
        const per = new Map<string, { salg: number; kunder: number }>()
        for (const r of rader) {
          const k = `${r.stasjon_id}|${r.time}`
          const e = per.get(k) ?? { salg: 0, kunder: 0 }
          e.salg += Number(r.salg) || 0
          e.kunder += Number(r.antall_kunder) || 0
          per.set(k, e)
        }
        return [...per.entries()]
          .map(([k, v]) => {
            const [sid, time] = k.split('|')
            return {
              stasjon: kart.get(sid) ?? sid,
              time,
              salg_kr: rund(v.salg),
              kunder: rund(v.kunder),
            }
          })
          .sort((a, b) => a.stasjon.localeCompare(b.stasjon) || a.time.localeCompare(b.time))
      },
    },
  ),

  hent_kassererstatistikk: stasjonsverktoy(
    'hent_kassererstatistikk',
    'Kassererstatistikk per stasjon: bonger, returer, makulerte og slettede linjer '
    + 'med beløp. Relevant for spørsmål om hva som er eller ikke er slått inn på kassa.',
    {},
    {
      domene: 'kassererstatistikk',
      kilder: ['kassererstatistikk'],
      neste: ['hent_kaffesvinn', 'hent_svinn', 'hent_datadekning'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<Kassererrad>(
          supabase
            .from('kassererstatistikk')
            .select(
              'stasjon_id, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger, '
              + 'retur_antall, retur_belop, makulerte_antall, makulerte_belop, '
              + 'slettede_antall, slettede_belop',
            )
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('dato', periode!.fra)
            .lte('dato', periode!.til)
            .is('slettet_tid', null)
            .limit(20000)
            .overrideTypes<Kassererrad[]>(),
          'kassererstatistikk',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'bonger') === 0,
      form: (rader, kart) => {
        const per = new Map<string, Record<string, number>>()
        for (const r of rader) {
          const e = per.get(r.stasjon_id) ?? {
            bonger: 0, retur_antall: 0, retur_belop: 0,
            makulerte_antall: 0, makulerte_belop: 0,
            slettede_antall: 0, slettede_belop: 0,
          }
          for (const f of Object.keys(e)) e[f] += Number(r[f as keyof Kassererrad]) || 0
          per.set(r.stasjon_id, e)
        }
        return [...per.entries()].map(([sid, e]) => ({
          stasjon: kart.get(sid) ?? sid,
          bonger: rund(e.bonger),
          returer: rund(e.retur_antall),
          retur_kr: rund(e.retur_belop),
          makulerte: rund(e.makulerte_antall),
          makulert_kr: rund(e.makulerte_belop),
          slettede: rund(e.slettede_antall),
          slettet_kr: rund(e.slettede_belop),
        }))
      },
    },
  ),

  // --- Businessplan / brutto -----------------------------------------

  hent_bp_status: stasjonsverktoy(
    'hent_bp_status',
    'BUSINESSPLAN / BP. Bruk ALLTID denne naar spoersmaalet nevner '
    + 'businessplan, BP, plan, «ligger bak», «ligger foran», «mot plan» '
    + 'eller «hvor taper vi brutto» — uansett hvilken maaned det gjelder. '
    + 'VIRKER MIDT I MAANEDEN: feltet burde_naa_omsetning sier hva stasjonen '
    + 'skulle ligget paa per i dag, saa en inneveaerende maaned kan besvares '
    + 'uten at regnskapet er avlagt. Gir BP mot faktisk i kroner og prosent '
    + '(mot_bp_kr, mot_bp_pst) og brutto mot budsjett (brutto_mot_bp_pp/_kr). '
    + 'periode_status sier om maaneden er avlagt, inneveaerende eller kommende. '
    + 'Ikke bruk hent_regnskap til BP-spoersmaal — det leser bokfoerte tall og '
    + 'er tomt for en maaned som ikke er avlagt.',
    {
      avdeling: {
        type: 'string',
        description: 'Avdelingskode, f.eks. 130 for varm drikke. Utelat for alle.',
      },
    },
    {
      domene: 'bp_status',
      kilder: ['v_bp_status_avdeling'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_salg', 'hent_regnskap', 'hent_datadekning'],
      merknad: [
        'Bruttoforventningen settes av St1 per år og kan gå ned. Den speiler '
        + 'varemiks, ikke dyktighet, og er ikke sammenlignbar mellom stasjoner '
        + 'med ulik miks. brutto_mot_bp_pp er stasjonens margin mot sin EGEN plan.',
      ],
      hent: ({ supabase, stasjoner, periode, input }) => {
        const maneder = manederIPeriode(periode!)
        let q = supabase
          .from('v_bp_status_avdeling')
          .select(
            'stasjon_id, maned, periode_status, gruppe_kode, gruppe_navn, '
            + 'bp_omsetning_kr, burde_naa_omsetning, faktisk_omsetning, mot_bp_kr, '
            + 'mot_bp_pst, mot_ifjor_pst, brutto_mot_bp_pp, brutto_mot_bp_kr, '
            + 'brutto_mot_bp_indeks, bp_brutto_fast, grunnlag, kobling',
          )
          .in('stasjon_id', stasjoner.map((s) => s.id))
          .in('maned', maneder)
        if (typeof input.avdeling === 'string' && input.avdeling.trim()) {
          q = q.eq('gruppe_kode', input.avdeling.trim())
        }
        return les<BpRad>(q.limit(5000).overrideTypes<BpRad[]>(), 'v_bp_status_avdeling')
      },
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader
          .map((r) => ({
            stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
            maned: r.maned,
            periode_status: r.periode_status,
            avdeling: r.gruppe_navn ?? r.gruppe_kode,
            bp_omsetning_kr: r.bp_omsetning_kr,
            burde_naa_kr: r.burde_naa_omsetning,
            faktisk_omsetning_kr: r.faktisk_omsetning,
            mot_bp_kr: r.mot_bp_kr,
            mot_bp_pst: r.mot_bp_pst,
            mot_ifjor_pst: r.mot_ifjor_pst,
            brutto_mot_bp_pp: r.brutto_mot_bp_pp,
            brutto_mot_bp_kr: r.brutto_mot_bp_kr,
            bp_brutto_fast: r.bp_brutto_fast,
            grunnlag: r.grunnlag,
          }))
          .sort((a, b) => (a.mot_bp_kr ?? 0) - (b.mot_bp_kr ?? 0)),
    },
  ),

  hent_regnskap: {
    schema: {
      name: 'hent_regnskap',
      description:
        'BOKFOERT REGNSKAP for en AVLAGT maaned: omsetning, bruttofortjeneste og '
        + 'kostnader med regnskap mot budsjett og avvik. Angi stasjoner for '
        + 'per-stasjonslinjer, eller niva="cluster" for kjedetotalen (kun eier). '
        + 'IKKE bruk denne til businessplan/BP-spoersmaal, og ikke til en maaned '
        + 'som ikke er avlagt — da er den tom, og tomheten betyr bare at '
        + 'regnskapet ikke er ferdig. Bruk hent_bp_status til BP og til '
        + 'inneveaerende maaned.',
      input_schema: {
        type: 'object',
        properties: {
          ...STASJON_FELT,
          ...PERIODE_FELT,
          niva: {
            type: 'string',
            enum: ['stasjon', 'kjedetotal'],
            description:
              'stasjon (STANDARD) gir én linje PER STASJON — bruk denne for aa '
              + 'sammenligne, rangere eller summere paa tvers. kjedetotal gir ÉN '
              + 'samlet linje for hele kjeden UTEN stasjonsfordeling, og kan '
              + 'ikke brukes til aa sammenligne stasjoner.',
          },
          seksjon: {
            type: 'string',
            description: 'omsetning | bruttofortjeneste | driftskostnader. Utelat for alle.',
          },
        },
      },
    },
    async kjor(input, ktx) {
      const { supabase, bruker } = ktx
      const idag = idagOslo()
      const kilder = ['regnskapslinjer']
      const erButikksjef = bruker.rolle !== 'retailer_admin'
      // «cluster» godtas fortsatt, men betyr det samme som kjedetotal.
      const niva = ['kjedetotal', 'cluster'].includes(String(input.niva ?? ''))
        ? 'kjedetotal'
        : 'stasjon'

      const p = lagPeriode(periodeInput(input), idag, { maaned: forrigeMaaned(idag) })
      if ('feil' in p) return byggSvar({ domene: 'regnskap', kilder, feil: p.feil })
      const maneder = manederIPeriode(p)

      // Cluster-linjene (stasjon_id null) er retailer_admin-only i RLS
      // (0067). Vi speiler det her for å kunne SI det, ikke for å vokte.
      if (niva === 'kjedetotal') {
        if (erButikksjef) {
          return byggSvar({
            domene: 'regnskap',
            kilder,
            ingenTilgang: true,
            periode: p,
            neste: ['hent_regnskap', 'hent_bp_status'],
            merknad: [
              'Kjedetotalen ligger på admin-nivå. Butikksjefen kan spørre om '
              + 'sin egen stasjon i stedet — bruk niva="stasjon".',
            ],
          })
        }
        const res = await les<Regnskapsrad>(
          supabase
            .from('regnskapslinjer')
            .select('seksjon, kode, post, regnskap, budsjett, avvik, index_pct, periode')
            .in('periode', maneder)
            .is('stasjon_id', null)
            .order('sortering'),
          'regnskapslinjer',
        )
        if (erLesefeil(res)) {
          return byggSvar({ domene: 'regnskap', kilder, periode: p, feil: res.feil, manglerKilde: res.manglerKilde })
        }
        return byggSvar({
          domene: 'regnskap',
          kilder,
          periode: p,
          data: res.rader,
          scope: {
            forespurt: ['kjedetotal'],
            besvart: res.rader.length ? ['kjedetotal'] : [],
          },
          neste: ['hent_regnskap', 'hent_salg', 'hent_bp_status'],
          merknad: [
            'Dette er ÉN samlet linje for hele kjeden. Den kan IKKE brukes til '
            + 'aa sammenligne stasjoner. Trenger du tall per stasjon, kall '
            + 'hent_regnskap igjen med niva="stasjon", eller hent_salg — '
            + 'begge gir omsetning og bruttofortjeneste per stasjon.',
          ],
        })
      }

      return kjorStasjonsverktoy<Regnskapsrad>(
        {
          domene: 'regnskap',
          kilder,
          standardPeriode: () => ({ maaned: forrigeMaaned(idag) }),
          neste: ['hent_bp_status', 'hent_salg', 'hent_datadekning'],
          merknad: erButikksjef
            ? [
                'Butikksjefen ser omsetning, bruttofortjeneste og PÅVIRKBARE '
                + 'kostnader. Royalty, husleie, finans, varekost-detaljer og '
                + 'selve resultatlinjen er filtrert bort og ligger på admin-nivå.',
              ]
            : [],
          hent: ({ supabase: sb, stasjoner }) => {
            let q = sb
              .from('regnskapslinjer')
              .select('stasjon_id, seksjon, kode, post, regnskap, budsjett, avvik, index_pct, periode')
              .in('stasjon_id', stasjoner.map((s) => s.id))
              .in('periode', maneder)
              .order('sortering')
            if (typeof input.seksjon === 'string' && input.seksjon.trim()) {
              q = q.eq('seksjon', input.seksjon.trim())
            }
            return les<Regnskapsrad>(q.limit(20000), 'regnskapslinjer')
          },
          stasjonAv: (r) => r.stasjon_id,
          form: (rader, kart) =>
            rader
              .filter((l) =>
                // Skjermingen er en PRODUKTREGEL, ikke en sikkerhetsgrense:
                // RLS gir butikksjefen alle seksjoner for egne stasjoner.
                // Kilden er `regnskap-tilgang.ts`, den samme /regnskap bruker.
                !erButikksjef
                || ((l.seksjon === 'omsetning' || l.seksjon === 'bruttofortjeneste')
                    && !UTELAT_KODER.has(l.kode ?? '') && l.kode !== '40')
                || (l.seksjon === 'driftskostnader' && BUTIKKSJEF_KOSTNAD_KODER.has(l.kode ?? '')),
              )
              .map((l) => ({
                stasjon: kart.get(l.stasjon_id ?? '') ?? l.stasjon_id,
                periode: l.periode,
                seksjon: l.seksjon,
                post: l.post,
                regnskap_kr: l.regnskap,
                budsjett_kr: l.budsjett,
                avvik_kr: l.avvik,
                index_pct: l.index_pct,
              })),
        },
        input,
        ktx,
      )
    },
  },

  hent_timeregnskap: stasjonsverktoy(
    'hent_timeregnskap',
    'Timeregnskap per stasjon og måned: budsjetterte timer, opptjente timer ut fra '
    + 'realisert brutto, brukte timer, timer over/under, og brutto per time. '
    + 'Timene er fortjent, ikke gitt.',
    {},
    {
      domene: 'timeregnskap',
      kilder: ['v_timeregnskap'],
      kunEier: true,
      eierBegrunnelse:
        'Timeregnskapet bygger på bemanning_aar, som er retailer_admin-only i '
        + 'databasen (0082), og /timeregnskap er admin-only i produktet. '
        + 'Butikksjefen kan spørre om planlagte og stemplede timer i stedet '
        + '(hent_bemanning, hent_stempling).',
      standardPeriode: (idag) => ({ maaned: forrigeMaaned(idag) }),
      neste: ['hent_bemanning', 'hent_stempling', 'hent_bp_status'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<Timeregnskapsrad>(
          supabase
            .from('v_timeregnskap')
            .select(
              'stasjon_id, maned, budsjett_timer, opptjente_timer, brukte_timer, '
              + 'timer_over, brutto_per_time, bp_brutto_per_time, realisert_brutto_kr, '
              + 'realisert_margin_pst, grunnlag, dager_med_salg, dager_i_maaned, lederdekning',
            )
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .in('maned', manederIPeriode(periode!))
            .limit(2000)
            .overrideTypes<Timeregnskapsrad[]>(),
          'v_timeregnskap',
        ),
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          maned: r.maned,
          budsjett_timer: r.budsjett_timer,
          opptjente_timer: r.opptjente_timer,
          brukte_timer: r.brukte_timer,
          timer_over: r.timer_over,
          brutto_per_time: r.brutto_per_time,
          bp_brutto_per_time: r.bp_brutto_per_time,
          realisert_margin_pst: r.realisert_margin_pst,
          // Måneden er ikke ferdig før alle salgsdagene er inne.
          delvis_maaned: r.dager_med_salg != null && r.dager_i_maaned != null
            ? r.dager_med_salg < r.dager_i_maaned
            : null,
          grunnlag: r.grunnlag,
        })),
    },
  ),

  // --- Bemanning og timer --------------------------------------------

  hent_bemanning: stasjonsverktoy(
    'hent_bemanning',
    'Planlagt bemanning per stasjon og måned (disponible timer) og registrert fravær. '
    + 'Bruk sammen med hent_stempling for planlagt mot faktisk.',
    {},
    {
      domene: 'bemanning',
      kilder: ['bemanning_maned', 'bemanning_fravaer'],
      standardPeriode: (idag) => ({ aar: Number(idag.slice(0, 4)) }),
      neste: ['hent_stempling', 'hent_timeregnskap', 'hent_timesalg'],
      hent: async ({ supabase, stasjoner, periode }) => {
        const ider = stasjoner.map((s) => s.id)
        const maneder = manederIPeriode(periode!)
        const aarene = [...new Set(maneder.map((m) => Number(m.slice(0, 4))))]
        const res = await lesAlle<[Bemanningsrad, Fravaersrad]>([
          [
            supabase
              .from('bemanning_maned')
              .select('stasjon_id, ar, maned, disponible_timer, beregnet_tid')
              .in('stasjon_id', ider)
              .in('ar', aarene)
              .limit(2000),
            'bemanning_maned',
          ],
          [
            supabase
              .from('bemanning_fravaer')
              .select('stasjon_id, fra_dato, til_dato, type')
              .in('stasjon_id', ider)
              .lte('fra_dato', periode!.til)
              .gte('til_dato', periode!.fra)
              .limit(2000),
            'bemanning_fravaer',
          ],
        ])
        if (erLesefeil(res)) return res
        const [plan, fravaer] = res.rader
        const mnd = new Set(maneder.map((m) => Number(m.slice(5, 7))))
        return {
          rader: plan
            .filter((p) => mnd.has(Number(p.maned)))
            .map((p) => ({
              ...p,
              fravaer: fravaer.filter((f) => f.stasjon_id === p.stasjon_id).length,
            })),
        }
      },
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'disponible_timer') === 0,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          ar: r.ar,
          maned: r.maned,
          disponible_timer: r.disponible_timer,
          beregnet_tid: r.beregnet_tid,
          fravaersperioder: r.fravaer,
        })),
    },
  ),

  hent_stempling: stasjonsverktoy(
    'hent_stempling',
    'Faktisk stemplede, betalte timer per ansatt og måned. Bruk mot hent_bemanning '
    + 'for planlagt mot faktisk, eller for å se hvor timene faktisk ligger.',
    {},
    {
      domene: 'stempling',
      kilder: ['v_stempling_ansatt_mnd'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_bemanning', 'hent_timeregnskap', 'hent_datadekning'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<{ stasjon_id: string; ansatt_nr: string; ansatt_navn: string | null; maaned: string; timer: number }>(
          supabase
            .from('v_stempling_ansatt_mnd')
            .select('stasjon_id, ansatt_nr, ansatt_navn, maaned, timer')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .in('maaned', manederIPeriode(periode!))
            .limit(5000),
          'v_stempling_ansatt_mnd',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'timer') === 0,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          ansatt_nr: r.ansatt_nr,
          ansatt: r.ansatt_navn,
          maaned: r.maaned,
          timer: Math.round((Number(r.timer) || 0) * 10) / 10,
        })),
    },
  ),

  // --- Svinn ---------------------------------------------------------

  hent_svinn: stasjonsverktoy(
    'hent_svinn',
    'Synlig svinn (registrerte varetransaksjoner: kast, brekkasje, internt forbruk) '
    + 'per stasjon over en periode, valgfritt brutt ned på årsakskode.',
    {
      grupper: {
        type: 'string',
        enum: ['stasjon', 'arsak', 'vare'],
        description: 'Oppløsning. Standard: stasjon.',
      },
    },
    {
      domene: 'synlig_svinn',
      kilder: ['synlig_svinn'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_kaffesvinn', 'hent_kassererstatistikk', 'hent_datadekning'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<Svinnrad>(
          supabase
            .from('synlig_svinn')
            .select('stasjon_id, arsakskode, transaksjonstype, varenavn, nettopris_total, antall')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('dato', periode!.fra)
            .lte('dato', periode!.til)
            .is('slettet_tid', null)
            .limit(20000),
          'synlig_svinn',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'nettopris_total') === 0,
      form: (rader, kart, _p) => {
        void _p
        const per = new Map<string, { sum: number; antall: number }>()
        for (const r of rader) {
          const e = per.get(r.stasjon_id) ?? { sum: 0, antall: 0 }
          e.sum += Number(r.nettopris_total) || 0
          e.antall += Number(r.antall) || 0
          per.set(r.stasjon_id, e)
        }
        return [...per.entries()].map(([sid, e]) => ({
          stasjon: kart.get(sid) ?? sid,
          svinn_kr: rund(e.sum),
          antall: rund(e.antall),
        }))
      },
    },
  ),

  hent_kaffesvinn: stasjonsverktoy(
    'hent_kaffesvinn',
    'Er påfyll av kaffe slått inn? Kaffe gitt bort på kaffeavtale gir manko på '
    + 'lageret (130xx); slås utdelingen inn, motposteres den. Svarer i ANTALL '
    + 'KOPPER som mangler å bli slått inn, ikke bare kroner. Bruk denne — ikke '
    + 'hent_svinn — på spørsmål om glemte kaffekopper.',
    {},
    {
      domene: 'kaffesvinn',
      kilder: ['v_kaffe_svinn'],
      standardPeriode: (idag) => ({ aar: Number(idag.slice(0, 4)) }),
      neste: ['hent_kassererstatistikk', 'hent_bp_status', 'hent_datadekning'],
      merknad: [
        'mangler_justering_kr over 0 betyr at utdelt kaffe ikke er slått inn. '
        + 'Negativt tall betyr mer talt enn ventet.',
      ],
      hent: ({ supabase, stasjoner, periode }) =>
        les<KaffesvinnRad>(
          supabase
            .from('v_kaffe_svinn')
            .select(
              'stasjon_id, aar, maaneder, fra, til, kaffe_kr, lojalitet_kr, '
              + 'mangler_kr, andel_ujustert_pst, vanligste_paafyll, maa_slaas_inn',
            )
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .eq('aar', `${periode!.fra.slice(0, 4)}-01-01`)
            .overrideTypes<KaffesvinnRad[]>(),
          'v_kaffe_svinn',
        ),
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          maaneder: r.maaneder,
          fra: r.fra,
          til: r.til,
          manko_paa_kaffe_kr: r.kaffe_kr,
          slaatt_inn_som_gitt_bort_kr: r.lojalitet_kr,
          mangler_justering_kr: r.mangler_kr,
          andel_ujustert_pst: r.andel_ujustert_pst,
          slaa_inn: r.maa_slaas_inn != null && r.vanligste_paafyll
            ? `${r.maa_slaas_inn} ${r.vanligste_paafyll}`
            : null,
          antall_kopper: r.maa_slaas_inn,
        })),
    },
  ),

  // --- Drift ---------------------------------------------------------

  hent_ikmat: stasjonsverktoy(
    'hent_ikmat',
    'IK-mat: kontrollpunkter per stasjon og temperaturavlesninger i perioden, med '
    + 'hvor mange som lå utenfor grensene. Svarer på «hva mangler i IK-mat».',
    {},
    {
      domene: 'ikmat',
      kilder: ['ik_kontrollpunkter', 'ik_avlesninger'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_avvik', 'hent_rutiner', 'hent_datadekning'],
      hent: async ({ supabase, stasjoner, periode }) => {
        const ider = stasjoner.map((s) => s.id)
        const res = await lesAlle<[Kontrollpunkt, Avlesning]>([
          [
            supabase
              .from('ik_kontrollpunkter')
              .select('id, stasjon_id, navn, type, frekvens, min_temp, max_temp')
              .in('stasjon_id', ider)
              .is('slettet_tid', null)
              .limit(2000),
            'ik_kontrollpunkter',
          ],
          [
            supabase
              .from('ik_avlesninger')
              .select('kontrollpunkt_id, stasjon_id, dato, temperatur, innenfor')
              .in('stasjon_id', ider)
              .gte('dato', periode!.fra)
              .lte('dato', periode!.til)
              .limit(20000),
            'ik_avlesninger',
          ],
        ])
        if (erLesefeil(res)) return res
        const [punkter, avlesninger] = res.rader
        return {
          rader: punkter.map((p) => {
            const mine = avlesninger.filter((a) => a.kontrollpunkt_id === p.id)
            return {
              ...p,
              avlesninger: mine.length,
              utenfor: mine.filter((a) => a.innenfor === false).length,
              siste: mine.map((a) => a.dato).sort().at(-1) ?? null,
            }
          }),
        }
      },
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          kontrollpunkt: r.navn,
          type: r.type,
          frekvens: r.frekvens,
          antall_avlesninger: r.avlesninger,
          // 0 avlesninger på et punkt som finnes er «ikke registrert»,
          // ikke «alt er i orden». Feltet sier det eksplisitt.
          status: r.avlesninger === 0 ? 'ingen_avlesninger_registrert' : 'har_avlesninger',
          utenfor_grense: r.utenfor,
          siste_avlesning: r.siste,
        })),
    },
  ),

  hent_rutiner: stasjonsverktoy(
    'hent_rutiner',
    'Rutiner per stasjon og hvor mange ganger de faktisk er utført i perioden. '
    + 'En rutine med null utføringer er ikke utført — det er ikke det samme som '
    + 'at rutinen ikke finnes.',
    {},
    {
      domene: 'rutiner',
      kilder: ['rutiner', 'rutine_utforinger'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_ikmat', 'hent_avvik', 'sla_opp_kunnskap'],
      hent: async ({ supabase, stasjoner, periode }) => {
        const ider = stasjoner.map((s) => s.id)
        const res = await lesAlle<[Rutine, Utforing]>([
          [
            supabase
              .from('rutiner')
              .select('id, stasjon_id, tittel, paakrevd_bilde')
              .in('stasjon_id', ider)
              .is('slettet_tid', null)
              .limit(2000),
            'rutiner',
          ],
          [
            supabase
              .from('rutine_utforinger')
              .select('rutine_id, stasjon_id, dato')
              .in('stasjon_id', ider)
              .gte('dato', periode!.fra)
              .lte('dato', periode!.til)
              .limit(20000),
            'rutine_utforinger',
          ],
        ])
        if (erLesefeil(res)) return res
        const [rutiner, utforinger] = res.rader
        return {
          rader: rutiner.map((r) => {
            const mine = utforinger.filter((u) => u.rutine_id === r.id)
            return { ...r, utfort: mine.length, siste: mine.map((u) => u.dato).sort().at(-1) ?? null }
          }),
        }
      },
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          rutine: r.tittel,
          ganger_utfort: r.utfort,
          status: r.utfort === 0 ? 'ikke_utfort_i_perioden' : 'utfort',
          siste_utforing: r.siste,
        })),
    },
  ),

  hent_avvik: stasjonsverktoy(
    'hent_avvik',
    'Registrerte avvik og åpne varsler per stasjon. Bruk for «hva krever '
    + 'oppmerksomhet» og «hvilke problemer bør jeg prioritere».',
    {},
    {
      domene: 'avvik_og_varsler',
      kilder: ['avvik', 'varsler'],
      standardPeriode: (idag) => ({ fra: idag.slice(0, 4) + '-01-01', til: idag }),
      neste: ['hent_ikmat', 'hent_rutiner', 'hent_bp_status'],
      hent: async ({ supabase, stasjoner, periode }) => {
        const ider = stasjoner.map((s) => s.id)
        const res = await lesAlle<[Avviksrad, Varselrad]>([
          [
            supabase
              .from('avvik')
              .select('stasjon_id, lopenr, kategori, dato, beskrivelse, frist, gjennomfort, gjennomfort_dato')
              .in('stasjon_id', ider)
              .gte('dato', periode!.fra)
              .lte('dato', periode!.til)
              .is('slettet_tid', null)
              .limit(2000),
            'avvik',
          ],
          [
            supabase
              .from('varsler')
              .select('stasjon_id, type, tittel, tekst, lest, opprettet_tid')
              .in('stasjon_id', ider)
              .is('slettet_tid', null)
              .order('opprettet_tid', { ascending: false })
              .limit(200),
            'varsler',
          ],
        ])
        if (erLesefeil(res)) return res
        const [avvik, varsler] = res.rader
        return {
          rader: [
            ...avvik.map((a) => ({
              stasjon_id: a.stasjon_id,
              slag: 'avvik' as const,
              tittel: `${a.kategori ?? 'Avvik'} ${a.lopenr ?? ''}`.trim(),
              tekst: a.beskrivelse,
              dato: a.dato,
              frist: a.frist,
              lukket: a.gjennomfort === true,
            })),
            ...varsler.map((v) => ({
              stasjon_id: v.stasjon_id,
              slag: 'varsel' as const,
              tittel: v.tittel,
              tekst: v.tekst,
              dato: v.opprettet_tid?.slice(0, 10) ?? null,
              frist: null,
              lukket: v.lest === true,
            })),
          ],
        }
      },
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id ?? '') ?? r.stasjon_id,
          slag: r.slag,
          tittel: r.tittel,
          tekst: r.tekst,
          dato: r.dato,
          frist: r.frist,
          status: r.lukket ? 'lukket' : 'apen',
        })),
    },
  ),

  hent_produksjonsplan: stasjonsverktoy(
    'hent_produksjonsplan',
    'Produksjonsplan per stasjon: hva systemet foreslo og hva som faktisk ble '
    + 'planlagt produsert, per vare. Motposten til salg når du skal vurdere om '
    + 'noe er produsert uten å bli slått inn.',
    {},
    {
      domene: 'produksjonsplan',
      kilder: ['produksjonsplan_linjer'],
      standardPeriode: (idag) => ({ maaned: idag.slice(0, 7) }),
      neste: ['hent_salg', 'hent_svinn', 'hent_kassererstatistikk'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<Produksjonsrad>(
          supabase
            .from('produksjonsplan_linjer')
            .select('stasjon_id, dato, varenavn, varegruppe_kode, varegruppe_navn, foreslatt, planlagt')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('dato', periode!.fra)
            .lte('dato', periode!.til)
            .limit(20000),
          'produksjonsplan_linjer',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'planlagt') === 0,
      form: (rader, kart) => {
        const per = new Map<string, { foreslatt: number; planlagt: number; navn: string }>()
        for (const r of rader) {
          const k = `${r.stasjon_id}|${r.varenavn}`
          const e = per.get(k) ?? { foreslatt: 0, planlagt: 0, navn: r.varenavn }
          e.foreslatt += Number(r.foreslatt) || 0
          e.planlagt += Number(r.planlagt) || 0
          per.set(k, e)
        }
        return [...per.entries()]
          .map(([k, v]) => ({
            stasjon: kart.get(k.split('|')[0]) ?? k.split('|')[0],
            vare: v.navn,
            foreslatt: rund(v.foreslatt),
            planlagt: rund(v.planlagt),
          }))
          .sort((a, b) => b.planlagt - a.planlagt)
      },
    },
  ),

  hent_malekort: stasjonsverktoy(
    'hent_malekort',
    'Målekort-oppsett for kjeden og registrerte skills-scorer per stasjon.',
    {},
    {
      domene: 'malekort',
      kilder: ['malekort', 'skills_score'],
      standardPeriode: (idag) => ({ aar: Number(idag.slice(0, 4)) }),
      neste: ['hent_salg', 'hent_bp_status'],
      hent: ({ supabase, stasjoner, periode }) =>
        les<{ stasjon_id: string; prosent: number | null; kommentar: string | null; registrert_tid: string }>(
          supabase
            .from('skills_score')
            .select('stasjon_id, prosent, kommentar, registrert_tid')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .gte('registrert_tid', `${periode!.fra}T00:00:00Z`)
            .lte('registrert_tid', `${periode!.til}T23:59:59Z`)
            .limit(2000),
          'skills_score',
        ),
      stasjonAv: (r) => r.stasjon_id,
      erMaltNull: (rader) => sum(rader, 'prosent') === 0,
      form: (rader, kart) =>
        rader.map((r) => ({
          stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
          prosent: r.prosent,
          kommentar: r.kommentar,
          registrert: r.registrert_tid?.slice(0, 10),
        })),
    },
  ),

  // --- Fokus og kunnskap ---------------------------------------------

  hent_fokus_status: {
    schema: {
      name: 'hent_fokus_status',
      description:
        'Aktive fokuspunkter per stasjon (satt etter regnskapet). Bruk når noen '
        + 'spør «hvordan går det», om oppfølging, eller hvordan det ligger an med '
        + 'fokuset. For å måle utviklingen: kall hent_bp_status eller hent_svinn '
        + 'for periodene fokuset gjelder.',
      input_schema: { type: 'object', properties: { ...STASJON_FELT } },
    },
    async kjor(input, ktx) {
      return kjorStasjonsverktoy<Fokusrad>(
        {
          domene: 'fokus',
          kilder: ['fokuspunkter'],
          periodisert: false,
          neste: ['hent_bp_status', 'hent_svinn', 'hent_regnskap'],
          // PORT 0-funn: den forrige versjonen hentet kast og usynlig manko
          // fra `regnskap_usynlig_svinn` og kalte summen stasjonens svinn.
          // Etter 0127 ser en butikksjef kun 130xx i den tabellen, så
          // kaffelinjene ble presentert som hele svinnbildet. Et troverdig
          // tall for feil grunnlag er verre enn ingen tall, så det er tatt
          // ut: fokuspunktene står for seg, og utviklingen måles med et
          // verktøy som vet hva det måler.
          hent: async ({ supabase, stasjoner }) => {
            const siste = await les<{ periode: string }>(
              supabase
                .from('fokuspunkter')
                .select('periode')
                .order('periode', { ascending: false })
                .limit(1),
              'fokuspunkter',
            )
            if (erLesefeil(siste)) return siste
            const periode = siste.rader[0]?.periode
            if (!periode) return { rader: [] }
            return les<Fokusrad>(
              supabase
                .from('fokuspunkter')
                .select('stasjon_id, periode, type, kategori, tittel, tekst')
                .eq('periode', periode)
                .in('stasjon_id', stasjoner.map((s) => s.id))
                .limit(500),
              'fokuspunkter',
            )
          },
          stasjonAv: (r) => r.stasjon_id,
          form: (rader, kart) =>
            rader.map((r) => ({
              stasjon: kart.get(r.stasjon_id) ?? r.stasjon_id,
              periode: r.periode,
              type: r.type,
              kategori: r.kategori,
              tittel: r.tittel,
              tekst: r.tekst,
            })),
        },
        input,
        ktx,
      )
    },
  },

  sla_opp_kunnskap: {
    schema: {
      name: 'sla_opp_kunnskap',
      description:
        'Slå opp i kunnskapsbasen: tariffavtale (Energistasjonsoverenskomsten), '
        + 'lønnssatser, arbeidsrett og interne rutiner/HMS/prosedyrer. Bruk ALLTID '
        + 'denne ved spørsmål om pauser, arbeidstid, overtid, tillegg, lønn, '
        + 'ansiennitet, ferie, sykepenger — eller «hvordan gjør vi X».',
      input_schema: {
        type: 'object',
        properties: { sporsmaal: { type: 'string', description: 'Søkeord eller spørsmål' } },
        required: ['sporsmaal'],
      },
    },
    async kjor(input, { supabase }) {
      const q = String(input.sporsmaal ?? '').trim()
      const kilder = ['kunnskap']
      if (!q) return byggSvar({ domene: 'kunnskap', kilder, feil: 'Tomt søk.' })

      const treff = await les<Kunnskapsrad>(
        supabase
          .from('kunnskap')
          .select('kategori, tittel, innhold, kilde')
          .textSearch('fts', q, { type: 'websearch', config: 'norwegian' })
          .limit(5),
        'kunnskap',
      )
      if (erLesefeil(treff)) {
        return byggSvar({ domene: 'kunnskap', kilder, feil: treff.feil, manglerKilde: treff.manglerKilde })
      }

      let rader = treff.rader
      // Fulltekstsøket er AND-basert og bommer på sammensatte ord. Bredere
      // OR-søk framfor å konkludere med at kunnskapen ikke finnes.
      if (rader.length === 0) {
        const ord = [...new Set(q.toLowerCase().split(/[^a-zæøå0-9]+/).filter((o) => o.length >= 4))].slice(0, 6)
        if (ord.length > 0) {
          const bredt = await les<Kunnskapsrad>(
            supabase
              .from('kunnskap')
              .select('kategori, tittel, innhold, kilde')
              .or(ord.map((o) => `innhold.ilike.%${o}%,tittel.ilike.%${o}%`).join(','))
              .limit(5),
            'kunnskap',
          )
          if (!erLesefeil(bredt)) rader = bredt.rader
        }
      }

      return byggSvar({
        domene: 'kunnskap',
        kilder,
        data: rader,
        scope: { forespurt: ['kunnskapsbasen'], besvart: rader.length ? ['kunnskapsbasen'] : [] },
        merknad:
          rader.length === 0
            ? [
                'Ingen treff. Si ærlig at du ikke har det dekket. For '
                + 'juridiske/tariff-spørsmål: henvis til HR eller Virke. Gjett aldri på satser.',
              ]
            : ['Oppgi § eller kilde i svaret.'],
      })
    },
  },

  // --- Oppgaver og konkurranser --------------------------------------

  list_oppgaver: stasjonsverktoy(
    'list_oppgaver',
    'Åpne oppgaver per stasjon, med frist. Bruk sammen med hent_avvik når '
    + 'noen spør hva som står igjen eller hva som bør prioriteres.',
    {},
    {
      domene: 'oppgaver',
      kilder: ['oppgaver'],
      periodisert: false,
      neste: ['hent_avvik'],
      hent: ({ supabase, stasjoner }) =>
        les<{ id: string; stasjon_id: string; tittel: string; frist: string | null; status: string }>(
          supabase
            .from('oppgaver')
            .select('id, stasjon_id, tittel, frist, status')
            .in('stasjon_id', stasjoner.map((s) => s.id))
            .is('slettet_tid', null)
            .eq('status', 'apen')
            .order('frist', { nullsFirst: false })
            .limit(200),
          'oppgaver',
        ),
      stasjonAv: (r) => r.stasjon_id,
      form: (rader, kart) =>
        rader.map((o) => ({
          id: o.id,
          stasjon: kart.get(o.stasjon_id) ?? o.stasjon_id,
          tittel: o.tittel,
          frist: o.frist,
        })),
    },
  ),

  list_konkurranser: {
    schema: {
      name: 'list_konkurranser',
      description:
        'Pågående og avsluttede konkurranser mellom stasjonene, med KPI, '
        + 'periode, premie og status. Bruk kar_vinner for å måle stillingen.',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, { supabase }) {
      const res = await les<Konkurranserad>(
        supabase
          .from('konkurranser')
          .select('id, navn, kpi, periode_start, periode_slutt, premie_kr, status')
          .is('slettet_tid', null)
          .order('opprettet_tid', { ascending: false })
          .limit(20),
        'konkurranser',
      )
      if (erLesefeil(res)) {
        return byggSvar({ domene: 'konkurranser', kilder: ['konkurranser'], feil: res.feil, manglerKilde: res.manglerKilde })
      }
      return byggSvar({
        domene: 'konkurranser',
        kilder: ['konkurranser'],
        data: res.rader,
        scope: { forespurt: ['konkurranser'], besvart: res.rader.length ? ['konkurranser'] : [] },
      })
    },
  },

  opprett_oppgave: {
    schema: {
      name: 'opprett_oppgave',
      description:
        'Opprett en oppgave for en stasjon. Krever butikknummer og tittel. '
        + 'Kall FØRST uten bekreftet for å vise hva du er i ferd med å gjøre.',
      input_schema: {
        type: 'object',
        properties: {
          butikknummer: { type: 'string' },
          tittel: { type: 'string' },
          beskrivelse: { type: 'string' },
          frist: { type: 'string', description: 'YYYY-MM-DD' },
          bekreftet: { type: 'boolean' },
        },
        required: ['butikknummer', 'tittel'],
      },
    },
    async kjor(input, { supabase, bruker }) {
      const scope = await hentScope(supabase, bruker.rolle)
      if ('feil' in scope) return { feil: scope.feil }
      const { valgte, utenfor } = velgStasjoner(scope, [String(input.butikknummer ?? '')])
      if (valgte.length === 0) {
        return {
          status: 'utenfor_scope',
          feil: `${utenfor.join(', ')} er ikke i ditt tilgangsområde. Ingen oppgave opprettet.`,
        }
      }
      const s = valgte[0]
      if (!input.bekreftet) {
        return {
          venter_paa_bekreftelse: true,
          oppsummering: `Opprette oppgave «${input.tittel}» på ${s.butikknummer} ${s.navn}`
            + `${input.frist ? `, frist ${input.frist}` : ''}. Bekreft for å opprette.`,
        }
      }
      const { data, error } = await supabase
        .from('oppgaver')
        .insert({
          retailer_id: bruker.retailerId,
          stasjon_id: s.id,
          tittel: String(input.tittel),
          beskrivelse: (input.beskrivelse as string) ?? null,
          frist: (input.frist as string) || null,
          opprettet_av: bruker.id,
        })
        .select('id')
        .single()
      if (error) return { feil: error.message }
      return { opprettet: true, id: data.id, stasjon: `${s.butikknummer} ${s.navn}` }
    },
  },

  opprett_konkurranse: {
    kunAdmin: true,
    schema: {
      name: 'opprett_konkurranse',
      description:
        'Opprett en konkurranse mellom stasjoner. To-stegs bekreftelse: kall først '
        + 'UTEN bekreftet for å vise oppsummering, deretter MED bekreftet=true.',
      input_schema: {
        type: 'object',
        properties: {
          navn: { type: 'string' },
          kpi: { type: 'string' },
          varegruppe_kode: { type: 'string' },
          maaltype: { type: 'string', enum: ['omsetning', 'antall'] },
          stasjoner: STASJON_FELT.stasjoner,
          periode_start: { type: 'string', description: 'YYYY-MM-DD' },
          periode_slutt: { type: 'string', description: 'YYYY-MM-DD' },
          premie_kr: { type: 'number' },
          bekreftet: { type: 'boolean' },
        },
        required: ['navn', 'kpi', 'periode_start', 'periode_slutt'],
      },
    },
    async kjor(input, { supabase, bruker }) {
      const { navn, kpi, periode_start, periode_slutt, premie_kr } = input
      const scope = await hentScope(supabase, bruker.rolle)
      if ('feil' in scope) return { feil: scope.feil }
      const { valgte, utenfor } = velgStasjoner(scope, input.stasjoner)
      if (utenfor.length > 0) {
        return { feil: `Utenfor tilgangen: ${utenfor.join(', ')}. Ingen konkurranse opprettet.` }
      }
      if (!input.bekreftet) {
        return {
          venter_paa_bekreftelse: true,
          oppsummering: `Opprette konkurranse «${navn}»: ${kpi}, ${periode_start}–${periode_slutt}`
            + `${premie_kr ? `, premie ${premie_kr} kr` : ''}, `
            + `${valgte.length} stasjoner. Bekreft for å opprette.`,
        }
      }
      const { data, error } = await supabase
        .from('konkurranser')
        .insert({
          retailer_id: bruker.retailerId,
          navn, kpi,
          varegruppe_kode: (input.varegruppe_kode as string) ?? null,
          maaltype: (input.maaltype as string) ?? 'omsetning',
          stasjon_ids: valgte.map((s) => s.id),
          periode_start, periode_slutt,
          premie_kr: (premie_kr as number) ?? null,
          opprettet_av: bruker.id,
        })
        .select('id')
        .single()
      if (error) return { feil: error.message }
      return { opprettet: true, id: data.id }
    },
  },

  kar_vinner: {
    kunAdmin: true,
    schema: {
      name: 'kar_vinner',
      description:
        'Mål en konkurranse fra butikksalget og kår vinner. To-stegs bekreftelse: '
        + 'kall først UTEN bekreftet for å vise stillingen.',
      input_schema: {
        type: 'object',
        properties: { konkurranse_id: { type: 'string' }, bekreftet: { type: 'boolean' } },
        required: ['konkurranse_id'],
      },
    },
    async kjor(input, { supabase, bruker }) {
      const id = String(input.konkurranse_id ?? '')
      const scope = await hentScope(supabase, bruker.rolle)
      if ('feil' in scope) return { feil: scope.feil }

      const k = await les<Konkurransedetalj>(
        supabase
          .from('konkurranser')
          .select('id, navn, varegruppe_kode, maaltype, stasjon_ids, periode_start, periode_slutt, status')
          .eq('id', id)
          .limit(1),
        'konkurranser',
      )
      if (erLesefeil(k)) return { feil: k.feil }
      const konk = k.rader[0]
      if (!konk) return { feil: 'Fant ikke konkurransen.' }

      let q = supabase
        .from('v_butikksalg')
        .select('stasjon_id, omsetning_eks_mva, antall')
        .gte('dato', konk.periode_start)
        .lte('dato', konk.periode_slutt)
        .is('slettet_tid', null)
      if (konk.varegruppe_kode) q = q.eq('varegruppe_kode', konk.varegruppe_kode)
      if (konk.stasjon_ids?.length > 0) q = q.in('stasjon_id', konk.stasjon_ids)

      const salg = await les<{ stasjon_id: string; omsetning_eks_mva: number | null; antall: number | null }>(
        q.limit(50000),
        'v_butikksalg',
      )
      if (erLesefeil(salg)) return { feil: salg.feil }

      const kart = etikettKart(scope.stasjoner)
      const per = new Map<string, number>()
      for (const r of salg.rader) {
        const v = konk.maaltype === 'antall' ? (r.antall ?? 0) : (r.omsetning_eks_mva ?? 0)
        per.set(r.stasjon_id, (per.get(r.stasjon_id) ?? 0) + Number(v))
      }
      const stilling = [...per.entries()]
        .map(([sid, verdi]) => ({ stasjon_id: sid, stasjon: kart.get(sid) ?? sid, verdi: rund(verdi) }))
        .sort((a, b) => b.verdi - a.verdi)

      if (stilling.length === 0) {
        return {
          status: 'ingen_registrering',
          feil: 'Ingen salgsdata i konkurranseperioden. Det betyr at ingenting er '
            + 'registrert — ikke at alle står på null. Sjekk hent_datadekning.',
        }
      }
      const vinner = stilling[0]
      if (!input.bekreftet) {
        return { venter_paa_bekreftelse: true, stilling, foreslaatt_vinner: vinner.stasjon }
      }
      const { error } = await supabase
        .from('konkurranser')
        .update({ status: 'avsluttet', vinner_stasjon_id: vinner.stasjon_id })
        .eq('id', id)
      if (error) return { feil: error.message }
      return { kaaret: true, vinner: vinner.stasjon, stilling }
    },
  },
}

function forrigeMaaned(idag: string): string {
  const [a, m] = idag.slice(0, 7).split('-').map(Number)
  const d = new Date(Date.UTC(a, m - 2, 1))
  return d.toISOString().slice(0, 7)
}

export function verktoyForRolle(erAdmin: boolean): Anthropic.Tool[] {
  return Object.values(VERKTOY)
    .filter((v) => erAdmin || !v.kunAdmin)
    .map((v) => v.schema)
}

/** Alle verktøynavn — katalogvakten leser denne. */
export const VERKTOYNAVN = Object.keys(VERKTOY)

// --- Radtyper --------------------------------------------------------

type Salgsrad = {
  stasjon_id: string
  dato: string | null
  avdeling_kode?: string | null
  avdeling_navn?: string | null
  varegruppe_kode?: string | null
  varegruppe_navn?: string | null
  omsetning_eks_mva: number | null
  antall: number | null
  bto_fortjeneste_kr: number | null
}
type AggRad = {
  stasjon_id: string
  gruppe_kode: string | null
  gruppe_navn: string | null
  omsetning: number
  antall: number
  brutto: number
  dager: Set<string>
}
type Kassererrad = {
  stasjon_id: string
  kasserer_nr: string
  kasserer_navn: string | null
  omsetning_ink_mva: number | null
  bonger: number | null
  retur_antall: number | null
  retur_belop: number | null
  makulerte_antall: number | null
  makulerte_belop: number | null
  slettede_antall: number | null
  slettede_belop: number | null
}
type BpRad = {
  stasjon_id: string
  maned: string
  periode_status: string
  gruppe_kode: string | null
  gruppe_navn: string | null
  bp_omsetning_kr: number | null
  burde_naa_omsetning: number | null
  faktisk_omsetning: number | null
  mot_bp_kr: number | null
  mot_bp_pst: number | null
  mot_ifjor_pst: number | null
  brutto_mot_bp_pp: number | null
  brutto_mot_bp_kr: number | null
  brutto_mot_bp_indeks: number | null
  bp_brutto_fast: boolean | null
  grunnlag: string | null
  kobling: string | null
}
type Regnskapsrad = {
  stasjon_id?: string | null
  periode: string
  seksjon: string
  kode: string | null
  post: string
  regnskap: number | null
  budsjett: number | null
  avvik: number | null
  index_pct: number | null
}
type Timeregnskapsrad = {
  stasjon_id: string
  maned: string
  budsjett_timer: number | null
  opptjente_timer: number | null
  brukte_timer: number | null
  timer_over: number | null
  brutto_per_time: number | null
  bp_brutto_per_time: number | null
  realisert_brutto_kr: number | null
  realisert_margin_pst: number | null
  grunnlag: string | null
  dager_med_salg: number | null
  dager_i_maaned: number | null
  lederdekning: number | null
}
type Bemanningsrad = {
  stasjon_id: string
  ar: number
  maned: number
  disponible_timer: number | null
  beregnet_tid: number | null
  fravaer?: number
}
type Fravaersrad = { stasjon_id: string; fra_dato: string; til_dato: string; type: string | null }
type Svinnrad = {
  stasjon_id: string
  arsakskode: string | null
  transaksjonstype: string | null
  varenavn: string | null
  nettopris_total: number | null
  antall: number | null
}
type KaffesvinnRad = {
  stasjon_id: string
  aar: string
  maaneder: number | null
  fra: string | null
  til: string | null
  kaffe_kr: number | null
  lojalitet_kr: number | null
  mangler_kr: number | null
  andel_ujustert_pst: number | null
  vanligste_paafyll: string | null
  maa_slaas_inn: number | null
}
type Kontrollpunkt = {
  id: string
  stasjon_id: string
  navn: string
  type: string | null
  frekvens: string | null
  min_temp: number | null
  max_temp: number | null
  avlesninger?: number
  utenfor?: number
  siste?: string | null
}
type Avlesning = {
  kontrollpunkt_id: string
  stasjon_id: string
  dato: string
  temperatur: number | null
  innenfor: boolean | null
}
type Rutine = {
  id: string
  stasjon_id: string
  tittel: string
  paakrevd_bilde: boolean | null
  utfort?: number
  siste?: string | null
}
type Utforing = { rutine_id: string; stasjon_id: string; dato: string }
type Avviksrad = {
  stasjon_id: string
  lopenr: number | null
  kategori: string | null
  dato: string | null
  beskrivelse: string | null
  frist: string | null
  gjennomfort: boolean | null
  gjennomfort_dato: string | null
}
type Varselrad = {
  stasjon_id: string | null
  type: string | null
  tittel: string
  tekst: string | null
  lest: boolean | null
  opprettet_tid: string
}
type Produksjonsrad = {
  stasjon_id: string
  dato: string
  varenavn: string
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  foreslatt: number | null
  planlagt: number | null
}
type Fokusrad = {
  stasjon_id: string
  periode: string
  type: string
  kategori: string | null
  tittel: string | null
  tekst: string
}
type Kunnskapsrad = { kategori: string; tittel: string; innhold: string; kilde: string | null }
type Konkurranserad = {
  id: string
  navn: string
  kpi: string
  periode_start: string
  periode_slutt: string
  premie_kr: number | null
  status: string
}
type Konkurransedetalj = {
  id: string
  navn: string
  varegruppe_kode: string | null
  maaltype: string
  stasjon_ids: string[]
  periode_start: string
  periode_slutt: string
  status: string
}
