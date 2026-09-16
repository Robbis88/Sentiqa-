import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAlle } from '@/lib/supabase/sider'
import type { Betalingsfrekvens } from '@/lib/parsere/lonnsgrunnlag'
import { hentArbeidstid, type Arbeidstidsmaaned } from './arbeidstid'

// =====================================================================
// HAR DENNE STASJONSMÅNEDEN DE KILDENE A1 TRENGER?
//
// A1 kan ikke svare uten to periodiserte observasjoner fra easy@work:
//
//   basisvakt       hvem arbeidet hvor, og hvor lenge
//   lonnsregister   hva en time kostet den måneden
//
// Mangler den ene, finnes det ikke noe kostnadsresultat. Ikke `0 kr`,
// ikke «minimum 0» — ingen kostnadsrad i det hele tatt. Derfor er dette
// en discriminated union der bare ÉN variant bærer kildene videre:
// `beregnArbeidssted` skal ta `MedBeggeKilder`, og da lar den seg ikke
// kalle uten dem.
//
// MÅLT i produksjon 2026-09-16: FIRE stasjonsmåneder har noe som helst.
//
//   Bønes        2026-08    698,8 t    0 register
//   Laguneparken 2026-08   1290,5 t    0 register
//   Lone         2026-07        0 t   18 register
//   Lone         2026-08        0 t   20 register
//
// Hver annen (stasjon, måned) noen kan spørre om er `mangler_begge`.
// Den er ikke et hjørnetilfelle — den er normalen.
//
// ---------------------------------------------------------------------
// PORTEN ER STASJONENS EGET REGISTER. KRYSS ER DEKNING, IKKE PORT.
//
// Dette er B2c-avgjørelsen, og den er MÅLT:
//
//   Når stasjonen har sitt eget register — 20 stasjonsmåneder,
//   19 546,5 timer — dekkes 89,3 % av timene lokalt, 2,2 % av en annen
//   stasjons register, og 8,5 % av ingen.
//
//   Når stasjonen IKKE har sitt eget register, redder kryssoppslaget
//   NULL timer. Ikke få. Null. Kryssarbeid forekommer bare i måneder
//   som allerede har sitt eget register.
//
// Begrunnelsen er strukturell, ikke statistisk: lønnsgrunnlaget er per
// definisjon lista over STASJONENS EGNE ansatte. Målt over 27 filer står
// null numre i to stasjoners register samme måned. En annen stasjons fil
// kan derfor aldri dekke denne stasjonens arbeidsstokk — bare den som
// tilfeldigvis er innom.
//
// Produksjonstilfellet som avgjorde det: Bønes august har 698,8 timer og
// null eget register, mens Lones augustregister finnes og inneholder
// Carmen. Lot vi kryss åpne porten, ville måneden blitt godkjent med
// 24,7 av 698,6 timer dekket — 3,5 %, to personer av tretten — og et
// 503-tall som så helt normalt ut.
//
// Carmen viser at BEGGE trengs, ikke at den ene kan erstatte den andre:
// Bønes' egen fil priser de tolv, Lones fil priser henne.
//
// ---------------------------------------------------------------------
// `uslaatteNumre` BÆRER EN KJENT SKJEVHET, OG SKAL GJØRE DET
//
// `lonnsregister_les` krever `stasjon_id in (select mine_stasjoner())`.
// En butikksjef på Bønes kan derfor IKKE lese Lones registerrad, og
// Carmen ville blitt uslått for henne mens eieren slår henne opp — samme
// data, to svar, og forskjellen går i den farlige retningen: for lite
// lønn er for stort grønt rom.
//
// B2c2 fjerner forskjellen med en smal `security definer`-funksjon som
// bare returnerer registerrader for numre som FAKTISK finnes i
// `basisvakt` på en autorisert stasjon. Til da skal forskjellen være
// MÅLBAR, ikke usynlig — et felt ingen kan overse er forskjellen på en
// kjent mangel og en stille feil.
// =====================================================================

type Klient = SupabaseClient

const MAANED = /^\d{4}-\d{2}$/

/** Én rad i `lonnsregister`, uendret. */
export type Registerrad = {
  stasjonId: string
  ansattNr: string
  navn: string
  timesats: number | null
  betalingsfrekvens: Betalingsfrekvens | null
}

export type Registermaaned = {
  maaned: string
  /** Stasjonens EGNE rader. Dette er porten. */
  egne: Registerrad[]
  /**
   * Rader fra ANDRE stasjoner, for numre som faktisk arbeidet her.
   *
   * Utvider dekningen inne i en måned som allerede har bestått porten.
   * Åpner den aldri.
   */
  kryss: Registerrad[]
  /**
   * Numre som arbeidet her og ikke lot seg slå opp noe sted.
   *
   * Bærer også RLS-skjevheten: en butikksjef ser flere av disse enn en
   * `retailer_admin`, av samme data, til B2c2 er på plass.
   */
  uslaatteNumre: string[]
}

export type Kilder =
  | {
    status: 'begge'
    stasjonId: string
    maaned: string
    arbeidstid: Arbeidstidsmaaned
    register: Registermaaned
  }
  | {
    status: 'mangler_register'
    stasjonId: string
    maaned: string
    /** Arbeidstiden finnes og skal kunne vises. Den er bare ikke prisbar. */
    arbeidstid: Arbeidstidsmaaned
    /** Kjente betalte timer uten sats. Bønes august: 698,8. */
    timer: number
    /** Personer bak de timene. */
    personer: number
    /**
     * Registerrader som FINNES for disse personene på andre stasjoner.
     *
     * Med vilje her, og med vilje uten makt: de forklarer hvorfor
     * måneden likevel ikke slipper gjennom porten.
     */
    kryss: Registerrad[]
  }
  | {
    status: 'mangler_arbeidstid'
    stasjonId: string
    maaned: string
    register: Registermaaned
  }
  | { status: 'mangler_begge'; stasjonId: string; maaned: string }

/**
 * Den ENESTE varianten som kan gi et kostnadstall.
 *
 * `beregnArbeidssted` skal ta denne, ikke `Kilder`. Da er «503 = 0 fordi
 * kilden manglet» ikke en tilstand noen kan skrive ved et uhell — de tre
 * andre variantene bærer ikke noe kostnadsfelt i det hele tatt.
 */
export type MedBeggeKilder = Extract<Kilder, { status: 'begge' }>

const frekvens = (v: unknown): Betalingsfrekvens | null =>
  v === 'time' || v === 'maaned' ? v : null

const VELG = 'stasjon_id, ansatt_nr, navn, timesats, betalingsfrekvens'

type RaaRegister = {
  stasjon_id: string; ansatt_nr: string; navn: string
  timesats: number | string | null; betalingsfrekvens: string | null
}

function tilRader(data: RaaRegister[]): Registerrad[] {
  return data.map((r) => ({
    stasjonId: r.stasjon_id,
    ansattNr: r.ansatt_nr,
    navn: r.navn,
    timesats: r.timesats === null || r.timesats === undefined ? null : Number(r.timesats),
    betalingsfrekvens: frekvens(r.betalingsfrekvens),
  }))
}

/** Stasjonens EGNE registerrader for maaneden. Porten. */
async function egneRader(
  supabase: Klient, stasjonId: string, maaned: string,
): Promise<Registerrad[]> {
  return tilRader(await hentAlle<RaaRegister>(() => supabase
    .from('lonnsregister')
    .select(VELG)
    .eq('kilde_maaned', maaned)
    .eq('stasjon_id', stasjonId)))
}

/**
 * Registerkandidatene for NUMRE SOM FAKTISK ARBEIDET HER.
 *
 * Gaar gjennom `a1_registeroppslag` (0221), ikke gjennom en vanlig
 * `select`. Grunnen er ikke bekvemmelighet, den er en maalt skjevhet:
 *
 *   `lonnsregister_les` krever `stasjon_id in (select mine_stasjoner())`.
 *   En butikksjef paa Boenes kan derfor ikke lese Lones registerrad, og
 *   Carmen - som arbeidet 79,82 timer paa Boenes i juli 2026 - ville
 *   vaert uslaatt for henne mens eieren slaar henne opp. Samme data, to
 *   svar, og forskjellen gaar i den farlige retningen: for lite loenn
 *   er for stort groent rom.
 *
 * RPC-en tar INGEN ansattnumre. Den utleder dem selv fra `basisvakt` paa
 * de autoriserte stasjonene, saa den kan ikke brukes til aa spoerre om
 * en person som ikke har arbeidet hos kalleren. Se `0221`.
 *
 * KASTER paa feil. En autorisasjonsfeil er en FEIL, ikke datamangel -
 * ble den gjort om til `[]`, ville den blitt til `uslaatteNumre` eller
 * `mangler_register`, altsaa til noe som ser ut som gyldige data.
 */
async function kryssRader(
  supabase: Klient, stasjonId: string, maaned: string, numre: readonly string[],
): Promise<Registerrad[]> {
  // Ingen arbeidstid, ingen kandidater. RPC-en ville uansett svart tomt,
  // men et kall uten hensikt er et kall som kan feile uten grunn.
  if (numre.length === 0) return []

  // `supabase.rpc` KASTER IKKE. Den returnerer feilen i `error`, og en
  // try/catch rundt kallet fanger ingenting.
  const { data, error } = await supabase.rpc('a1_registeroppslag', {
    p_maaned: maaned,
    p_stasjon_ider: [stasjonId],
  })
  if (error) {
    throw new Error(
      `a1_registeroppslag feilet for ${maaned}: ${error.message}`,
    )
  }

  return tilRader((data ?? []) as RaaRegister[])
    .filter((r) => r.stasjonId !== stasjonId)
}

/**
 * Hvilke kilder finnes for ÉN stasjon i ÉN måned?
 *
 * Rekkefølgen på sjekkene er kontrakten: uten arbeidstid OG uten eget
 * register er svaret `mangler_begge` — aldri én av de to, som ville
 * skjult halve mangelen.
 */
export async function hentKilder(
  supabase: Klient,
  stasjonId: string,
  maaned: string,
): Promise<Kilder> {
  if (!MAANED.test(maaned)) {
    throw new Error(`Ugyldig måned «${maaned}». Forventet yyyy-mm.`)
  }

  const arbeidstid = await hentArbeidstid(supabase, maaned, [stasjonId])
  const egne = await egneRader(supabase, stasjonId, maaned)

  // BEGGE MANGLER. Sjekkes dette ikke først, ville tilstanden blitt
  // rapportert som én av de to og halve mangelen forsvunnet.
  if (!arbeidstid && egne.length === 0) {
    return { status: 'mangler_begge', stasjonId, maaned }
  }

  if (!arbeidstid) {
    return {
      status: 'mangler_arbeidstid',
      stasjonId,
      maaned,
      register: { maaned, egne, kryss: [], uslaatteNumre: [] },
    }
  }

  // Numrene som faktisk arbeidet her. Kryssoppslaget er avgrenset til
  // dem — vi henter aldri en annen stasjons register i sin helhet.
  const numre = arbeidstid.personer
  const kryss = await kryssRader(supabase, stasjonId, maaned, numre)

  const kjent = new Set([...egne, ...kryss].map((r) => r.ansattNr))
  const uslaatteNumre = numre.filter((n) => !kjent.has(n))

  // PORTEN. Kryss har ingen stemme her — se hodet.
  if (egne.length === 0) {
    return {
      status: 'mangler_register',
      stasjonId,
      maaned,
      arbeidstid,
      timer: Math.round(arbeidstid.betalteMinutter / 60 * 10) / 10,
      personer: numre.length,
      kryss,
    }
  }

  return {
    status: 'begge',
    stasjonId,
    maaned,
    arbeidstid,
    register: { maaned, egne, kryss, uslaatteNumre },
  }
}
