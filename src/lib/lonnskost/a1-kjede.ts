import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { manedAar } from '@/lib/format'
import { hentA1Maaneder } from './a1-maaneder'
import { hentKilder } from './kilder'
import { hentAvtaler } from './avtale'
import { a1ForStasjonsmaaned } from './a1'
import { tilA1Kort, type A1Kort } from './a1-kort'

// =====================================================================
// KJEDESTRIPA — ÉN MÅNED, FLERE STASJONER, TRE SANNHETER
//
// B2e.1 svarer «hva er forventet konto 503 for DENNE stasjonen». Denne
// fila svarer «hvordan ser det ut over stasjonene jeg har ansvar for» —
// uten å slå sammen ting som ikke kan slås sammen.
//
// ---------------------------------------------------------------------
// TRE SANNHETER SOM IKKE ER DEN SAMME
//
//   MÅNED      hvilken periode snakker vi om
//   DEKNING    hvor mange av stasjonene har i det hele tatt en kroneverdi
//   SIKKERHET  er kronene eksakte, eller er de en nedre grense
//
// De blandes aldri. En full dekning kan være en nedre grense; en delvis
// dekning kan være eksakt for det den dekker. Derfor er `slag` og
// `sikkerhet` to uavhengige felter, ikke én status med fem verdier.
//
// ---------------------------------------------------------------------
// EN MANGLENDE STASJON ER IKKE 0 KRONER
//
// `ingen_grunnlag` har BOKSTAVELIG TALT ikke et `kroner`-felt, og
// `delvis` kan ikke skrives uten `dekkede`, `totalt` og `utenGrunnlag`.
// Vi prøver ikke å huske at dekningsgraden må med — vi gjør setningen
// uten den umulig å uttrykke. Samme grep som `Kilder` og `A1Kort`.
//
// ---------------------------------------------------------------------
// ÉN STRIPE = ÉN FELLES ISO-MÅNED
//
// Bønes august + Lone juli er ikke «kjeden», det er en kategorifeil.
// Alle radene gjelder samme måned, og en stasjon som ikke har den
// måneden vises som «ingen kilder» — ALDRI utelatt. En utelatt stasjon
// ser nøyaktig ut som en stasjon som ikke finnes.
//
// ---------------------------------------------------------------------
// INGEN FASTLØNNSLOGIKK HER
//
// Stripa konsumerer `A1Kort`. Stig på Bønes bidrar med 4 080 forklarte
// minutter og NULL kroner uten at denne fila vet at fastlønn finnes.
// Trenger den noen gang å vite det, er arkitekturen feil.
// =====================================================================

export type Stasjonsrad = {
  id: string
  butikknummer: string
  navn: string
}

export type Kjederad = Stasjonsrad & { kort: A1Kort }

/**
 * Hva kjeden kan si om kronene, uten å lyve.
 *
 * `slag` er DEKNING, `sikkerhet` er ØKONOMISK SIKKERHET. To akser.
 */
export type Kjedesum =
  /** Hver eneste autoriserte stasjon har en kroneverdi. */
  | {
    slag: 'hele_kjeden'
    sikkerhet: 'beregnet' | 'minst'
    kroner: number
    stasjoner: number
  }
  /**
   * Noen har kroneverdi, andre mangler grunnlag.
   *
   * `kroner` er summen av DE DEKKEDE — aldri en nedre grense for hele
   * kjeden, og aldri et tall der de manglende teller som null.
   */
  | {
    slag: 'delvis'
    sikkerhet: 'beregnet' | 'minst'
    kroner: number
    dekkede: number
    totalt: number
    /** Navnene, så de kan nevnes i stedet for bare telles. */
    utenGrunnlag: string[]
  }
  /** Ingen stasjon har kroneverdi. Har ikke noe `kroner`-felt. */
  | { slag: 'ingen_grunnlag'; totalt: number }

export type Kjedemaaling = {
  stasjoner: number
  /** Faktiske databasekall og RPC-er, talt der de gjoeres. */
  rundturer: number
  motorMs: number
  totaltMs: number
}

export type Kjede = {
  /** `null` naar ingen autorisert stasjon har en eneste kilde. */
  maaned: string | null
  rader: Kjederad[]
  sum: Kjedesum
  maaling: Kjedemaaling
}

const MAANED = /^\d{4}-(0[1-9]|1[0-2])$/

/** To desimaler, som motoren. Uten den driver flyttallene i en sum. */
const rund = (v: number): number => Math.round(v * 100) / 100

/**
 * Seneste ISO-maaned der MINST EN autorisert stasjon har en kilde.
 *
 * ALGORITME A, og valget er en KONTRAKT - ikke en maaling. Maalt mot
 * produksjon 2026-09-16 gir A, B og C alle `2026-08`, saa dataene
 * skiller dem ikke. Begrunnelsen er en annen:
 *
 *   B («flest har en kilde») og C («flest har begge») kan SKJULE den
 *   nyeste maaneden. Kommer september med en stasjon mens august har
 *   fire, velger C august - og eieren ser aldri at september har
 *   begynt aa komme inn. Det er «det som mangler roper ikke».
 *
 * A viser alltid den nyeste maaneden som finnes. Svakheten - at den kan
 * vaere tynt dekket - er allerede noeytralisert av `Kjedesum`, som ikke
 * KAN vise et delvis tall uten aa si «N av M».
 */
export function velgKjedeMaaned(perStasjon: readonly (readonly string[])[]): string | null {
  let siste: string | null = null
  for (const maaneder of perStasjon) {
    for (const m of maaneder) {
      if (!MAANED.test(m)) continue
      if (siste === null || m > siste) siste = m
    }
  }
  return siste
}

/**
 * Hva kjeden kan si, gitt radene.
 *
 * Rekkefolgen paa sjekkene er kontrakten: ingen dekning foerst, ellers
 * ville et tomt aggregat blitt til «beregnet 0 kr».
 */
export function kjedesum(rader: readonly Kjederad[]): Kjedesum {
  const totalt = rader.length
  const dekkede = rader.filter((r) => r.kort.status !== 'kildemangel')

  if (dekkede.length === 0) return { slag: 'ingen_grunnlag', totalt }

  const kroner = rund(dekkede.reduce(
    (s, r) => s + (r.kort.status === 'kildemangel' ? 0 : r.kort.kroner), 0,
  ))
  // ETT `minimum`-ledd gjoer HELE summen til en nedre grense. Det er
  // ikke en avrunding av sannheten - en sum som inneholder et
  // minimumstall ER et minimumstall.
  const sikkerhet = dekkede.some((r) => r.kort.status === 'minimum')
    ? 'minst' as const
    : 'beregnet' as const

  if (dekkede.length === totalt) {
    return { slag: 'hele_kjeden', sikkerhet, kroner, stasjoner: totalt }
  }
  return {
    slag: 'delvis',
    sikkerhet,
    kroner,
    dekkede: dekkede.length,
    totalt,
    utenGrunnlag: rader
      .filter((r) => r.kort.status === 'kildemangel')
      .map((r) => `${r.butikknummer} ${r.navn}`),
  }
}

export type Kjedetekst = { hoved: string; tillegg: string | null }

/** Kroner uten oerer, med hardt mellomrom - som resten av huset. */
const kroneformat = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })
const kr = (v: number) => `${kroneformat.format(v)} kr`
const maanedsnavn = (m: string) => manedAar.format(new Date(`${m}-01`))

/**
 * Oekonomisk spraak, ikke tilfeldig JSX.
 *
 * Fem kombinasjoner, fem setninger, testet hver for seg. Ordet «total
 * loennskost» forekommer ingen steder: A1 er konto 503 uten overtid.
 */
export function kjedesumtekst(sum: Kjedesum, maaned: string): Kjedetekst {
  if (sum.slag === 'ingen_grunnlag') {
    return {
      hoved: `Ingen beregnet konto 503 for ${maanedsnavn(maaned)}`,
      tillegg: `${sum.totalt} stasjoner mangler grunnlag.`,
    }
  }

  if (sum.slag === 'hele_kjeden') {
    const ledd = sum.sikkerhet === 'minst' ? 'Minst' : 'Beregnet'
    return {
      hoved: `${ledd} ${kr(sum.kroner)} for ${sum.stasjoner} stasjoner`,
      tillegg: sum.sikkerhet === 'minst'
        ? 'Noe kjent arbeid kunne ikke prises sikkert. Det faktiske beløpet er høyere.'
        : null,
    }
  }

  // DELVIS. Dekningen staar FOERST i setningen, saa tallet aldri kan
  // leses som en verdi for hele kjeden.
  const ledd = sum.sikkerhet === 'minst' ? 'minst' : 'beregnet'
  const mangler = sum.totalt - sum.dekkede
  const stasjonsord = mangler === 1 ? 'stasjon mangler' : 'stasjoner mangler'
  return {
    hoved: `For ${sum.dekkede} av ${sum.totalt} stasjoner: ${ledd} ${kr(sum.kroner)}`,
    tillegg: `${mangler} ${stasjonsord} grunnlag for ${maanedsnavn(maaned)}.`
      + (sum.sikkerhet === 'minst'
        ? ' Noe arbeid på de dekkede stasjonene kunne ikke prises.'
        : ''),
  }
}

/**
 * Handlingsbehov foerst. ALDRI etter kronebeloep.
 *
 *   1  mangler kilder            - ingen forsvarlig kroneverdi
 *   2  har kroner, men upriset arbeid
 *   3  ferdige
 *
 * Forklarte timer flytter INGENTING. De er informasjon, ikke et
 * handlingsbehov: arbeidet er gjort rede for, det er bare ikke
 * timepriset. En stasjon med 68 forklarte timer staar blant de ferdige.
 */
export function gruppeFor(kort: A1Kort): 1 | 2 | 3 {
  if (kort.status === 'kildemangel') return 1
  return kort.upriseteTimer > 0 ? 2 : 3
}

export function sorterKjede(rader: readonly Kjederad[]): Kjederad[] {
  return [...rader].sort((a, b) =>
    gruppeFor(a.kort) - gruppeFor(b.kort)
    // Stabilt innen gruppa: butikknummer, aldri kroner.
    || a.butikknummer.localeCompare(b.butikknummer, 'nb-NO'))
}

/**
 * Hele stripa for de autoriserte stasjonene.
 *
 * `stasjoner` SKAL komme fra serverens RLS-filtrerte liste. Funksjonen
 * utvider aldri settet og henter ingen stasjoner selv — den er ikke et
 * sikkerhetslag, og skal ikke se ut som ett.
 *
 * NAIV MED VILJE. `5N + 1` rundturer, sekvensielt. Batching er mulig
 * (leserne tar allerede lister), men «kryss» er relativt per stasjon,
 * og en optimalisering foer vi har maalt ville vaert en gjetning.
 */
export async function hentKjede(
  supabase: SupabaseClient,
  stasjoner: readonly Stasjonsrad[],
): Promise<Kjede> {
  const t0 = performance.now()
  let rundturer = 0
  let motorMs = 0

  const maanederPer: string[][] = []
  for (const s of stasjoner) {
    maanederPer.push(await hentA1Maaneder(supabase, s.id))
    rundturer += 2 // basisvakt + lonnsregister
  }

  const maaned = velgKjedeMaaned(maanederPer)
  if (maaned === null) {
    return {
      maaned: null,
      rader: [],
      sum: { slag: 'ingen_grunnlag', totalt: stasjoner.length },
      maaling: {
        stasjoner: stasjoner.length, rundturer, motorMs: 0,
        totaltMs: performance.now() - t0,
      },
    }
  }

  // EN gang for alle stasjonene. Oppslaget er stasjonsbundet inni.
  const avtale = await hentAvtaler(supabase, stasjoner.map((s) => s.id))
  rundturer += 1

  const rader: Kjederad[] = []
  for (const s of stasjoner) {
    const kilder = await hentKilder(supabase, s.id, maaned)
    // 2 spoerringer alltid, + RPC-en naar det finnes arbeidstid.
    rundturer += kilder.status === 'begge' || kilder.status === 'mangler_register' ? 3 : 2
    const t = performance.now()
    const res = a1ForStasjonsmaaned(kilder, avtale)
    motorMs += performance.now() - t
    rader.push({ ...s, kort: tilA1Kort(res) })
  }

  const sortert = sorterKjede(rader)
  return {
    maaned,
    rader: sortert,
    sum: kjedesum(sortert),
    maaling: {
      stasjoner: stasjoner.length,
      rundturer,
      motorMs: Math.round(motorMs * 100) / 100,
      totaltMs: Math.round((performance.now() - t0) * 100) / 100,
    },
  }
}
