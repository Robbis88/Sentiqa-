// easy@work lønnsarteksport — timer OG kroner per ansatt per dag.
//
// Dette er ikke Basis Export. De to filene kommer fra samme system og
// ligner på hverandre, men svarer på hvert sitt spørsmål:
//
//     Basis Export      når var noen på jobb        → `stempling.ts`
//     lønnsarter        hva kostet timen            → denne
//
// Basis Export har en navngitt topprad og datoer som «13 aug 2026».
// Denne har ingen topprad i det hele tatt, ISO-datoer, og ni kolonner i
// fast rekkefølge. `erStemplingFil` ser etter ordene «Forretningsdato»
// og «Stemplingsnummer»; ingen av dem finnes her, så fila ble meldt som
// ukjent format og nådde aldri en parser.
//
// PARSEREN TOLKER IKKE. Den leser lønnsarten som den står og lar
// koblingen mot kontoplanen ligge i `lib/lonnskost/easyatwork.ts`. Rå
// data lagres rått: endrer St1 hvilken konto en lønnsart hører til,
// skal det ikke kreve at hver fil lastes opp på nytt.

import type { Rapporttype } from './typer'

/** Kolonnene, i den rekkefølgen easy@work skriver dem. */
const KOL = {
  lokasjon: 0,
  navn: 1,
  ansattNr: 2,
  dato: 3,
  planlagt: 4,
  faktisk: 5,
  lonnsart: 6,
  timer: 7,
  belop: 8,
} as const

const ANTALL_KOLONNER = 9

export type Lonnsartlinje = {
  ansattNr: string
  ansattNavn: string
  dato: string // ISO yyyy-mm-dd
  /** Koden alene: «2», «12», «96», «97», «1429» … */
  lonnsart: string
  /** Hele etiketten, kode og alt. NØKKELEN — se under. */
  lonnsartTekst: string
  timer: number
  belopKr: number
  lokasjon: string // «St1 - Dale» — per rad, ikke per fil
}

export type LonnsartResultat = {
  rapporttype: 'easyatwork_lonnsart'
  // Flertall med vilje, som i `stempling.ts`: en eksport KAN dekke flere
  // stasjoner, og en parser som returnerte «lokasjonen» ville lagt alle
  // radene på den første.
  lokasjoner: string[]
  fraDato: string
  tilDato: string
  linjer: Lonnsartlinje[]
}

// Minimal CSV-lesing: siterte felt med komma inni, «""» som escapet
// anførselstegn. Samme form som i `stempling.ts` — å dele en avhengighet
// mellom to parsere ville bundet dem sammen for lite gevinst.
function csvRader(tekst: string): string[][] {
  const rader: string[][] = []
  let rad: string[] = []
  let felt = ''
  let iSitat = false
  for (let i = 0; i < tekst.length; i++) {
    const c = tekst[i]
    if (iSitat) {
      if (c === '"' && tekst[i + 1] === '"') { felt += '"'; i++ }
      else if (c === '"') iSitat = false
      else felt += c
    } else if (c === '"') iSitat = true
    else if (c === ',') { rad.push(felt); felt = '' }
    else if (c === '\n') { rad.push(felt); rader.push(rad); rad = []; felt = '' }
    else if (c !== '\r') felt += c
  }
  if (felt !== '' || rad.length > 0) { rad.push(felt); rader.push(rad) }
  return rader.filter((r) => r.some((f) => f.trim() !== ''))
}

const ISO_DATO = /^(\d{4}-\d{2}-\d{2})(?:[ T]|$)/
const LONNSART = /^\s*(\d+)\s+(\S.*)$/

/**
 * Tall slik easy@work skriver dem: «1 542.00», «-305.66», «7.47».
 *
 * Tusenskillet er mellomrom — noen ganger et vanlig, noen ganger et hardt
 * (U+00A0), avhengig av hvor eksporten er laget. Begge må bort før
 * `Number` ser strengen, ellers blir «1 542.00» til NaN og linja til
 * null kroner uten at noe klager.
 */
function tall(s: string): number {
  const rent = (s ?? '').replace(/[\s ]/g, '').replace(',', '.')
  const n = Number(rent)
  return Number.isFinite(n) ? n : NaN
}

/**
 * Ser dette ut som lønnsarteksporten?
 *
 * Kravene er stilt mot FORMEN, ikke mot et ord i en topprad — fila har
 * ingen. Ni kolonner, ISO-dato i den fjerde og «<tall> <tekst>» i den
 * sjuende er tilsammen spesifikt nok til at ingen annen fil vi leser
 * treffer, og løst nok til at et nytt navn på en lønnsart ikke bryter
 * gjenkjenningen.
 */
export function erLonnsartFil(tekst: string): boolean {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  const forste = rader[0]
  if (!forste || forste.length !== ANTALL_KOLONNER) return false
  return ISO_DATO.test((forste[KOL.dato] ?? '').trim())
    && LONNSART.test(forste[KOL.lonnsart] ?? '')
    && Number.isFinite(tall(forste[KOL.timer] ?? ''))
}

export function gjenkjennLonnsart(tekst: string): Rapporttype {
  return erLonnsartFil(tekst) ? 'easyatwork_lonnsart' : 'ukjent'
}

/**
 * Leser alle lønnsartlinjer ut av teksten.
 *
 * KASTER PÅ EN RAD DEN IKKE FORSTÅR, i stedet for å hoppe over den. En
 * fil som mangler en tiendedel av linjene ser ut som en rolig måned, og
 * det er nøyaktig slik stemplingsparseren mistet 25 % av postene uten at
 * noen så det på tre måneder. Her er innsatsen kroner: en droppet linje
 * blir til lønnskost som ikke finnes.
 */
export function lesLonnsart(tekst: string): LonnsartResultat {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  if (rader.length === 0) throw new Error('Lønnsartfila er tom.')

  const linjer = rader.map((r, n) => {
    const linjenr = n + 1
    if (r.length !== ANTALL_KOLONNER) {
      throw new Error(`Rad ${linjenr}: ventet ${ANTALL_KOLONNER} kolonner, fant ${r.length}.`)
    }
    const d = (r[KOL.dato] ?? '').trim().match(ISO_DATO)
    if (!d) throw new Error(`Rad ${linjenr}: forsto ikke datoen «${r[KOL.dato]}».`)

    const art = (r[KOL.lonnsart] ?? '').replace(/\s+/g, ' ').trim().match(LONNSART)
    if (!art) throw new Error(`Rad ${linjenr}: forsto ikke lønnsarten «${r[KOL.lonnsart]}».`)

    const timer = tall(r[KOL.timer] ?? '')
    const belopKr = tall(r[KOL.belop] ?? '')
    if (!Number.isFinite(timer)) throw new Error(`Rad ${linjenr}: forsto ikke timetallet «${r[KOL.timer]}».`)
    if (!Number.isFinite(belopKr)) throw new Error(`Rad ${linjenr}: forsto ikke beløpet «${r[KOL.belop]}».`)

    const ansattNr = (r[KOL.ansattNr] ?? '').trim()
    if (ansattNr === '') throw new Error(`Rad ${linjenr}: ansattnummeret mangler.`)

    return {
      ansattNr,
      ansattNavn: (r[KOL.navn] ?? '').replace(/\s+/g, ' ').trim(),
      dato: d[1],
      lonnsart: art[1],
      // HELE ETIKETTEN, IKKE BARE KODEN.
      //
      // Lønnsart 97 finnes i fire varianter, og to av dem kan treffe
      // samme person samme dag — målt på Dale august 2026 skjedde det to
      // ganger. Nøkkelen i basen er denne strengen; på koden alene ville
      // 400 rader blitt til 398, og 5 273 kroner søndagsovertid
      // forsvunnet i en `23505` som ser ut som en avvisning.
      lonnsartTekst: (r[KOL.lonnsart] ?? '').replace(/\s+/g, ' ').trim(),
      timer,
      belopKr,
      lokasjon: (r[KOL.lokasjon] ?? '').replace(/\s+/g, ' ').trim(),
    }
  })

  const datoer = linjer.map((l) => l.dato).sort()
  return {
    rapporttype: 'easyatwork_lonnsart',
    lokasjoner: [...new Set(linjer.map((l) => l.lokasjon).filter((l) => l !== ''))].sort(),
    fraDato: datoer[0],
    tilDato: datoer[datoer.length - 1],
    linjer,
  }
}
