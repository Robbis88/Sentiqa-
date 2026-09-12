// =====================================================================
// ÉN FASIT, TO IMPLEMENTASJONER
// =====================================================================
//
// Grunnlagsregelen finnes i `grunnlag.ts` (TypeScript) og i
// `public.v_svinn_grunnlag` (`0210`). To implementasjoner av én regel er
// en gjeld, og gjeld som ingen måler blir til drift.
//
// Denne fila er fasiten begge måles mot:
//
//   `kontrakt.test.ts`                  kjører TypeScript-siden i CI
//   `supabase/tests/svinn_grunnlag_kontrakt.sql`  kjører SQL-siden mot
//                                       en ekte base, i en transaksjon
//                                       som rulles tilbake
//
// SQL-probens innhold GENERERES fra denne lista
// (`OPPDATER_SVINNKONTRAKT=1 npx vitest run src/lib/svinn/kontrakt`),
// og en vakt i `kontrakt.test.ts` feiler hvis den committede fila ikke
// lenger stemmer med fasiten. Legger noen til et tilfelle her uten å
// regenerere, blir CI rød.
//
// ÆRLIG BEGRENSNING: vitest kan ikke nå produksjonsbasen (`.env.local`
// har bare anon-nøkkelen, og det er et bevisst valg). SQL-siden må
// derfor kjøres manuelt i SQL Editor, og den står i utrullingsplanen.
// CI beviser at fasiten og proben er i takt — ikke at proben er kjørt.
// =====================================================================

export type Kontraktsrad = {
  stasjon: 'a' | 'b'
  periode: string
  nivaa: 'gruppe' | 'produkt' | null
  analyseomraade: 'butikk' | 'drivstoff' | 'ukjent' | null
  kode: string
  salg: number | null
  kast: number | null
  usynlig_kr: number | null
}

export type Forventning = {
  /** Hvilket nivå regelen skal lande på for `stasjon`+`periode`. */
  grunnlag: 'gruppe' | 'produkt' | null
  datastatus: 'gruppe' | 'eldre_grunnlag' | 'utilgjengelig'
  /** Summer over radene valget landet på. */
  salg: number
  kast: number
  usynlig: number
  /** Antall rader som slipper gjennom. */
  rader: number
}

export type Tilfelle = {
  navn: string
  hvorfor: string
  rader: Kontraktsrad[]
  /** Nøkkel: `${stasjon}|${periode}`. */
  forvent: Record<string, Forventning>
}

const P = '1999-01-01' // fiktiv periode, kolliderer ikke med ekte data
const Q = '1999-02-01'

export const TILFELLER: readonly Tilfelle[] = [
  {
    navn: 'bare produktrader',
    hvorfor: 'Produksjonsbasen i dag: 588 rader, alle produkt, uten område.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: null, kode: '12010', salg: 1000, kast: 100, usynlig_kr: 50 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: null, kode: '12020', salg: 500, kast: 40, usynlig_kr: -10 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', salg: 1500, kast: 140, usynlig: 40, rader: 2 } },
  },
  {
    navn: 'komplett grupperad, gruppe og produkt sammen',
    hvorfor: 'Etter reimport. Gruppen eier totalen; produktene skal ikke legges til.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', salg: 1500, kast: 140, usynlig_kr: 40 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', salg: 1000, kast: 100, usynlig_kr: 50 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '12020', salg: 500, kast: 40, usynlig_kr: -10 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'gruppe', datastatus: 'gruppe', salg: 1500, kast: 140, usynlig: 40, rader: 1 } },
  },
  {
    navn: 'gruppe på én stasjon, produktfallback på en annen',
    hvorfor: 'Midt i en reimport kan to stasjoner ligge i ulik fase.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', salg: 1500, kast: 140, usynlig_kr: 40 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', salg: 1500, kast: 140, usynlig_kr: 40 },
      { stasjon: 'b', periode: P, nivaa: 'produkt', analyseomraade: null, kode: '13010', salg: 800, kast: 0, usynlig_kr: 200 },
    ],
    forvent: {
      'a|1999-01-01': { grunnlag: 'gruppe', datastatus: 'gruppe', salg: 1500, kast: 140, usynlig: 40, rader: 1 },
      'b|1999-01-01': { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', salg: 800, kast: 0, usynlig: 200, rader: 1 },
    },
  },
  {
    navn: 'ufullstendig grupperad',
    hvorfor:
      'Bare én av gruppene har grupperad. VALGT ATFERD: gruppenivå brukes '
      + 'likevel, fordi gruppen eier totalen for de gruppene den dekker. '
      + 'Differansen mellom gruppe og produkt er et FUNN som vises, ikke '
      + 'en grunn til å falle tilbake — se de 64 gruppedifferansene.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', salg: 1500, kast: 140, usynlig_kr: 40 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '13010', salg: 800, kast: 20, usynlig_kr: 5 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'gruppe', datastatus: 'gruppe', salg: 1500, kast: 140, usynlig: 40, rader: 1 } },
  },
  {
    navn: 'drivstoff og ukjent holdes ute',
    hvorfor: '19 drivstoffrader og 1 ukjent per måned. De lagres navngitt og blokkeres.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', salg: 1000, kast: 100, usynlig_kr: 50 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'drivstoff', kode: '1490', salg: 900000, kast: 0, usynlig_kr: 9999 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'ukjent', kode: '99910', salg: 72, kast: 0, usynlig_kr: -45 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', salg: 1000, kast: 100, usynlig: 50, rader: 1 } },
  },
  {
    navn: 'kast uten salg — 16015 KAMPANJE',
    hvorfor:
      'Laguneparken april: salg 0, usynlig 0, kast 3 655,42. Raden skal '
      + 'lagres og telle i gruppe 160. Kastprosenten er ikke beregnbar.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '16015', salg: 0, kast: 3655.42, usynlig_kr: 0 },
      { stasjon: 'a', periode: P, nivaa: 'produkt', analyseomraade: 'butikk', kode: '12010', salg: 1000, kast: 100, usynlig_kr: 50 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', salg: 1000, kast: 3755.42, usynlig: 50, rader: 2 } },
  },
  {
    navn: 'gruppe 120 Mat og gruppe 160 side om side',
    hvorfor:
      'Kampanjeraden hører til 160. Den skal ikke røre Mat 120, og Mat 120 '
      + 'skal fortsatt avstemme til 0 differanse.',
    rader: [
      { stasjon: 'a', periode: P, nivaa: 'gruppe', analyseomraade: 'butikk', kode: '120', salg: 1500, kast: 140, usynlig_kr: 40 },
      { stasjon: 'a', periode: P, nivaa: 'gruppe', analyseomraade: 'butikk', kode: '160', salg: 0, kast: 3655.42, usynlig_kr: 0 },
    ],
    forvent: { 'a|1999-01-01': { grunnlag: 'gruppe', datastatus: 'gruppe', salg: 1500, kast: 3795.42, usynlig: 40, rader: 2 } },
  },
  {
    navn: 'desember uten nødvendige felter',
    hvorfor:
      'Eldre rapportformat, ingen svinnrader i det hele tatt. Perioden er '
      + 'utilgjengelig — ikke 0, og ikke et startpunkt for en retning.',
    rader: [
      { stasjon: 'a', periode: Q, nivaa: 'produkt', analyseomraade: null, kode: '12010', salg: 1000, kast: 100, usynlig_kr: 50 },
    ],
    // Desember (`1999-01-01` her) har INGEN rader; januar (`Q`) har.
    forvent: {
      'a|1999-01-01': { grunnlag: null, datastatus: 'utilgjengelig', salg: 0, kast: 0, usynlig: 0, rader: 0 },
      'a|1999-02-01': { grunnlag: 'produkt', datastatus: 'eldre_grunnlag', salg: 1000, kast: 100, usynlig: 50, rader: 1 },
    },
  },
]
