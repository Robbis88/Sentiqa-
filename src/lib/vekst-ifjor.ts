// =====================================================================
// Vekst mot fjoråret, med ukedagene på plass.
//
// PREMISSET: ukedag betyr mer enn dato i detaljhandel. En lørdag likner
// mer på fjorårets lørdag enn på fjorårets samme kalenderdato. Alt annet
// her følger av det valget.
//
// 364 dager = 52 uker = garantert samme ukedag.
//
// UNNTAKET: 364 dager tilbake fra 31. desember lander 1. januar SAMME
// år. Da tas ETT steg til — 31.12.2025 — i stedet for en hel uke.
// HELLIGDAG MOT HELLIGDAG gaar foran alt: julaften mot julaften,
// Skjaertorsdag mot Skjaertorsdag. Se `fjorSlutt`.
//
// FJORÅRSVINDUET BYGGES BAKFRA. Sluttdatoen finnes først, og starten
// regnes som slutt minus samme lengde som årets vindu. Brukes
// 364-regelen på BEGGE ender, får vinduene ulik lengde i romjula — og da
// sammenliknes 31 dager mot 24 uten at noe sier fra.
// =====================================================================

/**
 * Datoregning på rene `YYYY-MM-DD`-strenger, via UTC.
 *
 * ALDRI `new Date('2026-08-17T00:00:00')`. Den leses som LOKAL midnatt,
 * og `toISOString()` etterpå gir ett døgn feil øst for UTC. Kjører
 * produksjon på UTC, virker den feilen der og feiler bare lokalt — så
 * den overlever gjennomlesing og dukker opp først ved flytting.
 */
import { fjorHelligdag, helligdagNavn } from './helligdager'
import { aftenNavn, fjorAften } from './dagtyper'

export function minusDager(iso: string, dager: number): string {
  const [y, m, d] = iso.split('-').map(Number)
  const dt = new Date(Date.UTC(y, m - 1, d))
  dt.setUTCDate(dt.getUTCDate() - dager)
  return dt.toISOString().slice(0, 10)
}

/** Året i en `YYYY-MM-DD`-streng, uten å lage et Date. */
const aar = (iso: string) => iso.slice(0, 4)

/**
 * Fjorårets motsvarende dag.
 *
 * HELLIGDAG MOT HELLIGDAG, ellers ukedag mot ukedag.
 *
 * Robert 2026-08-22: «31 skal ikke måles mot 25. Her må du ta helligdag
 * mot helligdag. 24 mot 24.»
 *
 * Er dagen en helligdag eller en aften, slås fjorårets tilsvarende opp
 * på NAVN. Det løser både de faste og de bevegelige: julaften er 24.
 * desember begge år, mens Skjærtorsdag er 2. april i 2026 og 17. april
 * i 2025 — fem uker unna, og helt utenfor rekkevidde for en
 * dagsforskyvning.
 *
 * Ellers gjelder 364 dager: samme ukedag, og i praksis samme
 * kalenderdato ± en dag. 22.08.2026 → 23.08.2025.
 *
 * (Rundt et skuddår blir avstanden to dager — 01.03.2024 → 03.03.2023 —
 * fordi 29. februar ligger imellom. Ukedagen stemmer fortsatt.)
 *
 * SISTE UTVEI, for 31. desember som ikke er helligdag men aften: har vi
 * ingen navnetreff, og 364 dager lander i SAMME kalenderår, tas ett steg
 * til. Dagen før 1. januar er 31. desember året før.
 */
export function fjorSlutt(sisteDato: string): string {
  const navngitt = fjorHelligdag(sisteDato) ?? fjorAften(sisteDato)
  if (navngitt) return navngitt

  const kandidat = minusDager(sisteDato, 364)
  return aar(kandidat) === aar(sisteDato) ? minusDager(sisteDato, 365) : kandidat
}

/** Antall hele dager mellom to datoer. */
export function dagerMellom(fra: string, til: string): number {
  const t = (iso: string) => {
    const [y, m, d] = iso.split('-').map(Number)
    return Date.UTC(y, m - 1, d)
  }
  return Math.round((t(til) - t(fra)) / 86_400_000)
}

export type Vindu = { fra: string; til: string }

/**
 * De to vinduene som skal sammenliknes.
 *
 * `fraIAar` klippes til `sisteDato`: henger importen så langt etter at
 * siste salgsdag ligger i forrige måned, ville vinduet ellers vært tomt
 * og widgeten vist 0 mot 0.
 */
export function vinduer(sisteDato: string, mndStart: string): { iAar: Vindu; iFjor: Vindu } {
  const fraIAar = mndStart < sisteDato ? mndStart : sisteDato
  const til = fjorSlutt(sisteDato)
  return {
    iAar: { fra: fraIAar, til: sisteDato },
    // BAKFRA, med samme lengde. Ikke `fjorSlutt(mndStart)`.
    iFjor: { fra: minusDager(til, dagerMellom(fraIAar, sisteDato)), til },
  }
}

export type Dagsrad = { dato: string; verdi: number | null }

/**
 * Sum og DAGTELLING for et vindu.
 *
 * Dagtellingen er ikke pynt. Summering over rader som ikke finnes gir 0,
 * ikke feil — var butikken stengt i fjor, eller kom aldri importen, ser
 * veksten strålende ut uten at noen får vite hvorfor.
 */
export function summer(rader: Dagsrad[], v: Vindu): { kr: number; dager: number } {
  const dager = new Set<string>()
  let kr = 0
  for (const r of rader) {
    if (r.dato < v.fra || r.dato > v.til) continue
    kr += r.verdi ?? 0
    dager.add(r.dato)
  }
  return { kr, dager: dager.size }
}

export type Sammenlikning = {
  iAar: number
  iFjor: number
  diff: number
  /** Null når fjoråret er 0 — da finnes ingen prosent, og «+100 %» lyver. */
  pct: number | null
  vinduIAar: Vindu
  vinduIFjor: Vindu
  dagerIAar: number
  dagerIFjor: number
  /** Dager fjoråret mangler av årets. 0 når det ikke mangler noe. */
  manglerDager: number
}

/**
 * Hele sammenlikningen for ett vindu.
 *
 * AVRUNDING FØR SUBTRAKSJON. Rundes hver sum for seg og differansen
 * regnes av de RÅ tallene, viser skjermen 19 182 − 18 022 = +1 161.
 * Brukere kontrollregner, og mister tillit til hele modulen.
 */
export function sammenlikn(
  rader: Dagsrad[], sisteDato: string, mndStart: string,
): Sammenlikning {
  const v = vinduer(sisteDato, mndStart)
  const a = summer(rader, v.iAar)
  const f = summer(rader, v.iFjor)

  const iAar = Math.round(a.kr)
  const iFjor = Math.round(f.kr)
  const diff = iAar - iFjor

  return {
    iAar,
    iFjor,
    diff,
    pct: iFjor > 0 ? Math.round((diff / iFjor) * 1000) / 10 : null,
    vinduIAar: v.iAar,
    vinduIFjor: v.iFjor,
    dagerIAar: a.dager,
    dagerIFjor: f.dager,
    manglerDager: Math.max(0, a.dager - f.dager),
  }
}

const UKEDAGER = ['søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag']

/**
 * Ukedagen en dato faller på, utledet av datoen.
 *
 * ALDRI HARDKODET. Undertittelen sa «torsdag mot torsdag» som fast
 * tekst. Den var riktig den dagen koden ble skrevet, og feil resten av
 * uka. Alt som beskriver dataene må utledes fra dataene.
 */
export function ukedag(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return UKEDAGER[new Date(Date.UTC(y, m - 1, d)).getUTCDay()]
}

/** «17.08.26», til vindusetiketten. */
export function kortDato(iso: string): string {
  const [y, m, d] = iso.split('-')
  return `${d}.${m}.${y.slice(2)}`
}

/**
 * Navnet på dagen, når den har et.
 *
 * TIL ETIKETTEN, og det er ikke pynt. Undertittelen sier ellers «søndag
 * mot lørdag» på 17. mai — og det ser ut som en feil i stedet for det
 * det er: nasjonaldagen målt mot nasjonaldagen. Beskrivelsen må si
 * hvilken regel som faktisk ble brukt, ellers mister tallet under den
 * tilliten sin.
 */
export function dagsnavn(iso: string): string | null {
  return helligdagNavn(iso) ?? aftenNavn(iso)
}
