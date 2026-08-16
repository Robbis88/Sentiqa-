// =====================================================================
// Fra stempling til lønnsarter.
//
// En vakt er ikke én lønnslinje. Kelsar følger Energistasjons-
// overenskomsten, der tillegg for ubekvem tid er kroner per time innenfor
// faste bånd — og båndene er GJENSIDIG UTELUKKENDE etter dagtype, ikke
// stablende. En lørdagskveld gir lørdagstillegg og ikke kveldstillegg,
// fordi 1429/1430/1431 heter «hverdag».
//
// Reglene her er ikke utledet fra tariffteksten. De er lest ut av
// Kelsars egne lønnsfiler og verifisert mot mai 2026 på Bønes:
// 1,08 timers avvik av 522, altså 0,2 %.
//
// De to som ikke var åpenbare:
//
//   HELLIGDAG FØLGER FORRETNINGSDATOEN. En vakt som starter på Kristi
//   himmelfart er rød hele veien, også de 17 minuttene etter midnatt.
//
//   AFTENENE ER RØDE FRA 15. Julaften, nyttårsaften, påskeaften og
//   pinseaften. Dagen før 1. mai og 17. mai er det IKKE.
// =====================================================================

import { helligdagNavn } from '../helligdager'
import { aftenNavn } from '../dagtyper'

/** Lønnsartene som kommer ut av en vakt. Resten føres manuelt. */
export const LONNSART = {
  timelonn: '2',
  helligdag: '1410',
  hverdag1821: '1429',
  hverdag2124: '1430',
  hverdag0006: '1431',
  lordag: '1432',
  sondag0006: '1433',
  sondag0618: '1434',
  sondag1824: '1435',
} as const

// Fra hvilken klokketime lørdagstillegget løper. Lest ut av 63
// lørdagslinjer koblet mot faktiske stemplingstider: seksten
// observasjoner peker på 18, ingen på noe annet.
const LORDAG_FRA = 18
const AFTEN_FRA = 15

type Band = { kode: string; fra: number; til: number }
const BAND: Record<'hverdag' | 'lordag' | 'sondag', Band[]> = {
  hverdag: [
    { kode: LONNSART.hverdag1821, fra: 18, til: 21 },
    { kode: LONNSART.hverdag2124, fra: 21, til: 24 },
    { kode: LONNSART.hverdag0006, fra: 0, til: 6 },
  ],
  lordag: [{ kode: LONNSART.lordag, fra: LORDAG_FRA, til: 24 }],
  sondag: [
    { kode: LONNSART.sondag0006, fra: 0, til: 6 },
    { kode: LONNSART.sondag0618, fra: 6, til: 18 },
    { kode: LONNSART.sondag1824, fra: 18, til: 24 },
  ],
}

const iso = (d: Date) => d.toISOString().slice(0, 10)
const pluss = (dato: string, dager: number) =>
  iso(new Date(Date.parse(`${dato}T12:00:00Z`) + dager * 86400000))

const ukedag = (dato: string) => {
  const d = new Date(`${dato}T12:00:00Z`).getUTCDay()
  return d === 0 ? 7 : d
}

const minutter = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5))

const dagtype = (dato: string): 'hverdag' | 'lordag' | 'sondag' => {
  const u = ukedag(dato)
  return u === 6 ? 'lordag' : u === 7 ? 'sondag' : 'hverdag'
}

export type Stempling = { dato: string; fraTid: string; tilTid: string }

/**
 * Deler én vakt i lønnsarter, i minutter.
 *
 * `tilTid` «00:00» betyr midnatt — altså slutten av dagen, ikke starten.
 * Er sluttiden før starttiden, går vakten over midnatt.
 */
export function delVakt(v: Stempling): Map<string, number> {
  const start = minutter(v.fraTid)
  let slutt = v.tilTid === '00:00' || v.tilTid === '24:00' ? 24 * 60 : minutter(v.tilTid)
  // STRENGT mindre enn. Er fra og til like, er det en feilstempling paa
  // null minutter — noen stemplet inn og ut paa samme minutt. Med `<=`
  // ble den til en 24-timers vakt, og den ville gaatt rett i lonnsfila.
  // Slike finnes i ekte data: 05:00 -> 05:00, 0,00 t.
  if (slutt < start) slutt += 24 * 60

  const ut = new Map<string, number>()
  const legg = (kode: string) => ut.set(kode, (ut.get(kode) ?? 0) + 1)

  // Forretningsdatoen avgjør om HELE vakten er rød, også timene som
  // ligger etter midnatt på en vanlig dag.
  const rodHeleVakten = helligdagNavn(v.dato) !== null
  const erAften = aftenNavn(v.dato) !== null

  for (let m = start; m < slutt; m++) {
    const klokke = m % (24 * 60)
    const overMidnatt = Math.floor(m / (24 * 60))
    const dag = overMidnatt === 0 ? v.dato : pluss(v.dato, overMidnatt)

    legg(LONNSART.timelonn)

    if (rodHeleVakten || helligdagNavn(dag) !== null) { legg(LONNSART.helligdag); continue }
    // Aftenen gjelder bare selve aftensdøgnet, ikke timene etter midnatt
    // — da er det 1. juledag eller 1. nyttårsdag, som er rød uansett.
    if (erAften && overMidnatt === 0 && klokke >= AFTEN_FRA * 60) {
      legg(LONNSART.helligdag)
      continue
    }
    for (const b of BAND[dagtype(dag)]) {
      if (klokke >= b.fra * 60 && klokke < b.til * 60) legg(b.kode)
    }
  }
  return ut
}

export type Lonnslinje = { ansattNr: string; lonnsart: string; antall: number }

/**
 * Summerer et sett vakter til lønnslinjer per ansatt.
 *
 * Rekkefølgen er fast — timelønn først, så tilleggene stigende — så to
 * kjøringer av samme måned gir identiske filer. En fil som endrer seg
 * uten at tallene gjør det, er umulig å avstemme.
 */
export function tilLonnslinjer(
  vakter: (Stempling & { ansattNr: string })[],
): Lonnslinje[] {
  const sum = new Map<string, Map<string, number>>()
  for (const v of vakter) {
    const per = sum.get(v.ansattNr) ?? new Map<string, number>()
    for (const [kode, min] of delVakt(v)) per.set(kode, (per.get(kode) ?? 0) + min)
    sum.set(v.ansattNr, per)
  }

  const rekke = Object.values(LONNSART)
  const ut: Lonnslinje[] = []
  for (const ansattNr of [...sum.keys()].sort((a, b) => a.length - b.length || a.localeCompare(b))) {
    for (const lonnsart of rekke) {
      const min = sum.get(ansattNr)?.get(lonnsart) ?? 0
      // Under et halvt minutt er avrundingsstøy, ikke arbeid.
      if (min < 0.5) continue
      ut.push({ ansattNr, lonnsart, antall: Math.round((min / 60) * 100) / 100 })
    }
  }
  return ut
}
