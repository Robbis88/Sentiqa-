import 'server-only'
import { byggSvar } from './svar'
import { hentScope, velgStasjoner } from './scope'
import { hentA1Maaneder } from '@/lib/lonnskost/a1-maaneder'
import { hentKilder } from '@/lib/lonnskost/kilder'
import { hentAvtaler } from '@/lib/lonnskost/avtale'
import { a1ForStasjonsmaaned } from '@/lib/lonnskost/a1'
import { tilA1Kort } from '@/lib/lonnskost/a1-kort'
import { hentLonnskost } from '@/lib/lonnskost/hent'
import { styringsavvik, type Lonnsrom } from '@/lib/lonnskost/rom'
import type { Verktoy, VerktoyKtx } from './verktoy'

// =====================================================================
// AI-EN SKAL HENTE SANNHETEN, IKKE REKONSTRUERE DEN
// =====================================================================
//
// A1-motoren og lønnsrommet eier hver sin sannhet, begge bevist mot
// produksjon. Fram til nå hadde assistenten ingen vei inn til noen av
// dem: spurte noen «hva er forventet konto 503 på Bønes», måtte den
// enten si nei eller bygge regnestykket på nytt fra rådata.
//
// Det andre er verre enn det første. A1 er 572 linjer med
// identitetsregler, kryssregister, fastlønnsklassifisering og
// bevaring av betalte minutter. En modell som summerer lønnslinjer
// kommer fram til et tall som SER riktig ut og ikke er det — og den
// ville ikke hatt noen måte å vite det på.
//
// ---------------------------------------------------------------------
// INGEN RÅVEI INN
// ---------------------------------------------------------------------
//
// Det finnes med vilje INGEN verktøy som gir `lonnsregister`,
// `basisvakt` eller `ansatt_avtale` rått. Rekonstruksjon er derfor
// ikke bare frarådet i prompten — den er uoppnåelig gjennom
// verktøykatalogen. `verktoy.test.ts` vokter det.
//
// ---------------------------------------------------------------------
// PROVENIENS FØLGER MED
// ---------------------------------------------------------------------
//
// `sikkerhet` er A1-kontraktens egen: `beregnet` er eksakt under
// A1-modellen, `minst` er en nedre grense, og `ingen_grunnlag` har
// BOKSTAVELIG TALT ikke noe kronefelt. Mister modellen det skillet på
// vei inn i chatten, er hele B2d-porten omsonst.
//
// Lønnsrommet bærer sitt eget: `anslaatt` sier om brutto er lest av
// regnskapet eller anslått, og `bpLonnKr` er PLANEN - ikke en prognose.
//
// ---------------------------------------------------------------------
// TILGANG
// ---------------------------------------------------------------------
//
// `hentScope` leser `stasjoner` gjennom RLS. Lista ER det autoriserte
// settet; verktøyet utvider det aldri. Prompten er ikke sikkerhetslaget.
// =====================================================================

const MAANED = /^\d{4}-(0[1-9]|1[0-2])$/

/**
 * Kroner med to desimaler — eller `null`.
 *
 * Uten denne gikk `244412.89694656563` rett inn i modellen, og en modell
 * gjentar gjerne det den faar. Sytten signifikante siffer i et svar om
 * loenn ser ut som falsk presisjon, fordi det er det.
 */
const ore = (v: number | null | undefined): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? Math.round(v * 100) / 100 : null

const STASJONSFELT = {
  stasjoner: {
    type: 'array' as const,
    items: { type: 'string' as const },
    description:
      'Butikknummer eller navn. Utelat for alle stasjoner brukeren har tilgang til.',
  },
}

// =====================================================================
// hent_lonnskost — A1, forventet konto 503
// =====================================================================

type A1Rad = {
  stasjon: string
  maaned: string
  /** `beregnet` | `minst` | `ingen_grunnlag`. Se hodet. */
  sikkerhet: 'beregnet' | 'minst' | 'ingen_grunnlag'
  kroner: number | null
  mangler: string | null
  betalte_timer: number | null
  prisede_timer: number | null
  forklarte_timer: number | null
  uprisede_timer: number | null
  andel_priset_pst: number | null
  innlaant_kr: number | null
  uprisede_personer: { ansatt_nr: string; navn: string; timer: number; grunn: string }[]
  dubletter: number
  avviste_vakter: number
  helligdagstimer: number
  forbehold: string[]
}

export const hentLonnskostVerktoy: Verktoy = {
  schema: {
    name: 'hent_lonnskost',
    description:
      'Forventet konto 503 (timelønn og tillegg) per stasjon og måned, regnet '
      + 'av Sentiqas A1-motor ut fra stemplet arbeidstid og lønnsgrunnlaget fra '
      + 'easy@work. BRUK ALLTID DENNE når spørsmålet gjelder konto 503, '
      + 'lønnskost per stasjon, uprisede timer eller hvorfor et lønnstall er '
      + 'usikkert. Regn ALDRI dette ut selv fra andre kilder — motoren eier '
      + 'svaret, og den kjenner identitetsregler, innlånte ansatte og '
      + 'fastlønnsklassifisering du ikke har tilgang til. '
      + 'Feltet `sikkerhet` er avgjørende: `beregnet` er et eksakt tall under '
      + 'A1-modellen, `minst` er en NEDRE GRENSE (det faktiske beløpet er '
      + 'høyere), og `ingen_grunnlag` betyr at kildene mangler — da finnes '
      + 'det ingen kroneverdi, og du skal ikke si 0. '
      + 'Overtid (lønnsart 96 og 97) er ikke med i noen av tilfellene.',
    input_schema: {
      type: 'object',
      properties: {
        ...STASJONSFELT,
        maaned: {
          type: 'string',
          description: 'YYYY-MM. Utelat for nyeste måned per stasjon.',
        },
      },
    },
  },
  kjor: async (input, ktx) => kjorLonnskost(input, ktx),
}

async function kjorLonnskost(input: Record<string, unknown>, ktx: VerktoyKtx) {
  const scope = await hentScope(ktx.supabase, ktx.bruker.rolle)
  if ('feil' in scope) {
    return byggSvar<A1Rad>({ domene: 'lonnskost', kilder: [], feil: scope.feil })
  }
  const { valgte, utenfor } = velgStasjoner(scope, input.stasjoner)

  const bedtOmMaaned = typeof input.maaned === 'string' ? input.maaned : null
  if (bedtOmMaaned !== null && !MAANED.test(bedtOmMaaned)) {
    return byggSvar<A1Rad>({
      domene: 'lonnskost',
      kilder: [],
      feil: `Ugyldig måned «${bedtOmMaaned}». Forventet YYYY-MM.`,
    })
  }

  const rader: A1Rad[] = []
  const utenRegistrering: string[] = []
  const merknad: string[] = []

  for (const s of valgte) {
    const maaneder = await hentA1Maaneder(ktx.supabase, s.id)
    if (maaneder.length === 0) {
      utenRegistrering.push(s.butikknummer)
      continue
    }
    const maaned = bedtOmMaaned ?? maaneder[0]
    if (!maaneder.includes(maaned)) {
      // MÅNEDEN FINNES IKKE FOR DENNE STASJONEN. Det er ikke det samme
      // som at den koster null — og det skal ikke se slik ut.
      utenRegistrering.push(s.butikknummer)
      merknad.push(
        `${s.butikknummer} ${s.navn} har ingen arbeidstid eller lønnsgrunnlag `
        + `for ${maaned}. Registrerte måneder: ${maaneder.join(', ')}.`,
      )
      continue
    }

    const avtale = await hentAvtaler(ktx.supabase, [s.id])
    const kilder = await hentKilder(ktx.supabase, s.id, maaned)
    const kort = tilA1Kort(a1ForStasjonsmaaned(kilder, avtale))

    if (kort.status === 'kildemangel') {
      rader.push({
        stasjon: `${s.butikknummer} ${s.navn}`,
        maaned,
        sikkerhet: 'ingen_grunnlag',
        kroner: null,
        mangler: kort.mangler === 'register'
          ? 'lønnsgrunnlaget fra easy@work'
          : kort.mangler === 'arbeidstid'
            ? 'arbeidstiden fra easy@work'
            : 'både arbeidstid og lønnsgrunnlag',
        betalte_timer: kort.timer ?? null,
        prisede_timer: null,
        forklarte_timer: null,
        uprisede_timer: null,
        andel_priset_pst: null,
        innlaant_kr: null,
        uprisede_personer: [],
        dubletter: 0,
        avviste_vakter: 0,
        helligdagstimer: 0,
        forbehold: [],
      })
      continue
    }

    rader.push({
      stasjon: `${s.butikknummer} ${s.navn}`,
      maaned,
      sikkerhet: kort.status === 'minimum' ? 'minst' : 'beregnet',
      kroner: kort.kroner,
      mangler: null,
      betalte_timer: kort.betalteTimer,
      prisede_timer: kort.prisedeTimer,
      forklarte_timer: kort.forklarteTimer,
      uprisede_timer: kort.upriseteTimer,
      andel_priset_pst: kort.andelPriset,
      innlaant_kr: kort.innlaantKr,
      uprisede_personer: kort.uprisetePersoner.map((p) => ({
        ansatt_nr: p.ansattNr, navn: p.navn, timer: p.timer, grunn: p.grunn,
      })),
      dubletter: kort.dataavvik.dubletter,
      avviste_vakter: kort.dataavvik.avvisteVakter,
      helligdagstimer: kort.helligdagstimer,
      forbehold: kort.forbehold,
    })
  }

  return byggSvar<A1Rad>({
    domene: 'lonnskost',
    kilder: ['basisvakt', 'lonnsregister', 'ansatt_avtale'],
    data: rader,
    scope: {
      forespurt: valgte.map((s) => s.butikknummer),
      besvart: valgte
        .filter((s) => rader.some((r) => r.stasjon.startsWith(s.butikknummer)))
        .map((s) => s.butikknummer),
      uten_registrering: utenRegistrering,
      utenfor_tilgang: utenfor,
    },
    merknad: [
      ...merknad,
      'Overtid (lønnsart 96 og 97) er ikke med i A1.',
      '`minst` betyr at noe kjent arbeid ikke kunne prises. Det faktiske '
      + 'beløpet er høyere — aldri lavere.',
    ],
    neste: ['hent_lonnsrom', 'hent_timeregnskap', 'hent_datadekning'],
  })
}

// =====================================================================
// hent_lonnsrom — PLAN mot rom mot faktisk
// =====================================================================

type Romrad = {
  stasjon: string
  maaned: string
  /** PLANEN: BP-ens eget lønnstall. Ikke et anslag på hva som skjer. */
  bp_lonn_kr: number | null
  /** Rommet: BP-ens lønnsandel ganget med faktisk brutto. */
  lonnsrom_kr: number | null
  brutto_kr: number | null
  /** Sant når brutto er ANSLÅTT, ikke lest av regnskapet. */
  brutto_anslaatt: boolean
  /** FASIT: måneden er avlagt i regnskapet. */
  avlagt: boolean
  faktisk_lonn_kr: number | null
  styringskost_kr: number | null
  avvik_kr: number | null
  avvik_andel_av_rom: number | null
  /**
   * `normal` | `endring` | `handling` — eller NULL når det ikke er vurdert.
   *
   * Motorens `tomt()` returnerer `alvor: 'normal'` i FEM forskjellige
   * «lar seg ikke regne»-tilfeller. Der betyr `normal` «ingen
   * alvorstilstand er beregnet», ikke «avviket er normalt». Sendte vi
   * ordet videre rått, kunne modellen sagt «lønnskostnaden ser normal
   * ut» om en måned der lønnstallet ikke har kommet.
   */
  alvor: 'normal' | 'endring' | 'handling' | null
  avvik_mangler: string | null
  ekstra_svinn_kr: number
}

/**
 * Fra motorens `Lonnsrom` til raden modellen ser.
 *
 * EGEN FUNKSJON, OG DET ER IKKE KOSMETIKK. Kartleggingen er stedet
 * proveniensen kan gaa tapt: hardkodes `brutto_anslaatt` til `false`,
 * blir en prognose til fasit uten at noe annet endrer seg. Som ren
 * funksjon kan den vaktes uten aa bygge en fake for ti tabeller.
 */
export function tilRomrad(
  stasjon: string,
  rom: Lonnsrom,
  mnd: { avlagt?: boolean; lonnskostKr?: number | null; niva?: { styringskostKr: number | null } | null } | null,
): Romrad {
  const styringskost = mnd?.niva?.styringskostKr ?? null
  const avvik = styringsavvik(rom, styringskost)
  const avlagt = mnd?.avlagt ?? false
  return {
    stasjon,
    maaned: rom.maaned,
    bp_lonn_kr: ore(rom.bpLonnKr),
    lonnsrom_kr: ore(rom.romKr),
    brutto_kr: ore(rom.bruttoKr),
    // PROVENIENS. Motorens eget flagg, aldri en konstant.
    brutto_anslaatt: rom.anslaatt,
    avlagt,
    // ===================================================================
    // BARE EN AVLAGT MAANED HAR EN FAKTISK LOENN
    // ===================================================================
    //
    // `maaned.ts:226` er eksplisitt: for en AAPEN maaned summerer
    // `lonnskostKr` budsjettlinjer, ikke bokfoert kostnad — «for en aapen
    // maaned finnes det ingen bokfoert kostnad i det hele tatt».
    //
    // Foerste utgave sendte den videre som `faktisk_lonn_kr` uansett. Maalt
    // mot produksjon 2026-09-16 ga det `faktisk_lonn_kr` = `bp_lonn_kr`
    // paa kronen for Boenes august — altsaa PLANEN merket som FAKTISK, i
    // samme svar som `avvik_mangler` sa at loennstallet ikke var kommet.
    // To motstridende paastander i en rad modellen skulle stole paa.
    faktisk_lonn_kr: avlagt ? ore(mnd?.lonnskostKr ?? null) : null,
    styringskost_kr: ore(styringskost),
    avvik_kr: ore(avvik.kroner),
    avvik_andel_av_rom: avvik.andelAvRom,
    // INGEN DOM UTEN GRUNNLAG. `mangler` og `alvor` kommer alltid sammen
    // fra motoren, men hver for seg er `normal` tvetydig.
    alvor: avvik.mangler === null ? avvik.alvor : null,
    avvik_mangler: avvik.mangler ?? null,
    ekstra_svinn_kr: ore(rom.ekstraSvinnKr) ?? 0,
  }
}

export const hentLonnsromVerktoy: Verktoy = {
  schema: {
    name: 'hent_lonnsrom',
    description:
      'Lønnsrommet per stasjon og måned: BP-ens planlagte lønn, hvor stort '
      + 'lønnsrommet faktisk ble da brutto ble kjent, og styringsavviket mot '
      + 'det. BRUK DENNE når spørsmålet er «ligger vi over eller under på '
      + 'lønn», «hvorfor er lønnsrommet mindre enn planlagt» eller «hvor mye '
      + 'har vi å gå på». Regn ALDRI rommet selv som BP-lønn delt på '
      + 'BP-brutto ganget med brutto — motoren kjenner kalibrering, ekstra '
      + 'svinn og bilvaskbidrag som du ikke ser. '
      + 'Proveniens: `brutto_anslaatt: true` betyr at brutto er en PROGNOSE, '
      + 'ikke fasit. `avlagt: true` betyr at måneden er bokført — da er '
      + 'lønnstallet FASIT. `bp_lonn_kr` er PLANEN, ikke en prognose. '
      + '`faktisk_lonn_kr` finnes BARE for en avlagt måned; er den null, er '
      + 'lønnen ikke bokført ennå, og du skal ikke bruke BP-tallet i stedet. '
      + '`alvor: null` betyr IKKE VURDERT — da står grunnen i `avvik_mangler`, '
      + 'og du skal aldri si at lønnskostnaden ser normal ut.',
    input_schema: {
      type: 'object',
      properties: {
        ...STASJONSFELT,
        maaned: { type: 'string', description: 'YYYY-MM. Utelat for alle kjente måneder.' },
      },
    },
  },
  kjor: async (input, ktx) => kjorLonnsrom(input, ktx),
}

async function kjorLonnsrom(input: Record<string, unknown>, ktx: VerktoyKtx) {
  const scope = await hentScope(ktx.supabase, ktx.bruker.rolle)
  if ('feil' in scope) {
    return byggSvar<Romrad>({ domene: 'lonnsrom', kilder: [], feil: scope.feil })
  }
  const { valgte, utenfor } = velgStasjoner(scope, input.stasjoner)

  const bedtOmMaaned = typeof input.maaned === 'string' ? input.maaned : null
  if (bedtOmMaaned !== null && !MAANED.test(bedtOmMaaned)) {
    return byggSvar<Romrad>({
      domene: 'lonnsrom', kilder: [],
      feil: `Ugyldig måned «${bedtOmMaaned}». Forventet YYYY-MM.`,
    })
  }

  // Tolv måneder bakover er nok til å se en utvikling uten å dra hele
  // historikken inn i samtalen.
  const fra = new Date()
  fra.setUTCMonth(fra.getUTCMonth() - 12)
  const fraIso = `${fra.toISOString().slice(0, 8)}01`

  const rader: Romrad[] = []
  const utenRegistrering: string[] = []

  for (const s of valgte) {
    const bilde = await hentLonnskost(ktx.supabase, s.id, fraIso)
    const aktuelle = bedtOmMaaned
      ? bilde.rom.filter((r) => r.maaned === bedtOmMaaned)
      : bilde.rom
    if (aktuelle.length === 0) {
      utenRegistrering.push(s.butikknummer)
      continue
    }
    for (const rom of aktuelle) {
      const mnd = bilde.maaneder.find((m) => m.maaned === rom.maaned)
      rader.push(tilRomrad(`${s.butikknummer} ${s.navn}`, rom, mnd ?? null))
    }
  }

  return byggSvar<Romrad>({
    domene: 'lonnsrom',
    kilder: ['regnskapslinjer', 'bp_linje', 'v_butikksalg', 'bilvask_abonnement'],
    data: rader,
    scope: {
      forespurt: valgte.map((s) => s.butikknummer),
      besvart: valgte
        .filter((s) => rader.some((r) => r.stasjon.startsWith(s.butikknummer)))
        .map((s) => s.butikknummer),
      uten_registrering: utenRegistrering,
      utenfor_tilgang: utenfor,
    },
    merknad: [
      'Et manglende lønnstall er IKKE et avvik på null — da står '
      + '`avvik_mangler` med grunnen.',
      '`bp_lonn_kr` er PLANEN. `brutto_anslaatt: true` gjør rommet til en '
      + 'PROGNOSE. `avlagt: true` gjør lønnstallet til FASIT.',
    ],
    neste: ['hent_lonnskost', 'hent_bp_status', 'hent_regnskap'],
  })
}
