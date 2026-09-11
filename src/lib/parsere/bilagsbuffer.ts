// Bilagslinjene som alltid har ligget i regnskapsfila.
//
// =====================================================================
// TOLV MÅNEDER MED LEVERANDØRNAVN, SOM INGEN HAR LEST
// =====================================================================
//
// `Kostnader`-arket i regnskapsrapporten er en PIVOTTABELL, og en
// pivottabell lagrer en kopi av kildedataene inne i selve fila. Kilden er
// tolv måneders bilagslinjer — ikke bare måneden rapporten gjelder.
//
// Arket viser bare én butikk fordi filteret står på `9900 Admin`. Hele
// datasettet følger med uansett: `xl/pivotCache/pivotCacheRecords1.xml`.
//
// Kelsars sju månedsfiler (januar–juli 2026) bar til sammen **202502–
// 202607, 11 737 unike bilagslinjer** med leverandørnavn på hver.
//
// ---------------------------------------------------------------------
// HVORFOR DET BETYR NOE
//
// Uten dette er «renhold er høyt» alt systemet kan si. Med det er det
// «ASKO Vest, 29 825 på Lone, mot Vardens 7 207» — og det er forskjellen
// mellom en rapport og en plan.
//
// Det var også bilagsteksten som avgjorde klassifiseringen: `634 Rep &
// vedlikehold` er 82 % WashTec på stasjonene med vask, altså maskinen og
// ikke butikksjefens valg — men på Dale, som ikke har vask, er den null
// WashTec. En kode er ikke en spak eller en følge. En leverandør er det.
//
// ---------------------------------------------------------------------
// KONTOEN ER IDENTITETEN
//
// Bufferen bærer BÅDE `Rapportlinje` og `Konto`. Rapportlinja flyttet seg
// i februar 2026 (se `kontoregister.ts`); kontoen sto stille — 75 av 80
// peker på samme begrep før og etter. Derfor lagres kontoen, og den er
// nøkkelen når de to er uenige.
//
// ---------------------------------------------------------------------
// FORMATET
//
// `pivotCacheDefinition1.xml` gir feltnavnene i rekkefølge, og for hvert
// felt eventuelle «shared items» — verdiene som gjentar seg, lagret én
// gang. `pivotCacheRecords1.xml` har én `<r>` per rad, med ett barn per
// felt i samme rekkefølge:
//
//   <x v="3"/>   indeks inn i feltets shared items
//   <n v="123"/> tall
//   <s v="..."/> streng lagret inline
//   <m/>         tomt
//
// Rekkefølgen er hele koblingen: det finnes ingen feltnavn i selve
// radene. Et felt som faller ut forskyver alt etter seg, og da blir
// beløpet til en dato uten at noe roper. Derfor felles en rad med feil
// antall barn i stedet for å tolkes.

import { ParserFeil } from './felles'
import { delnavn, lesDel, lesDelStrom } from './xlsx-rader'

const DEF = 'xl/pivotCache/pivotCacheDefinition1.xml'
const REC = 'xl/pivotCache/pivotCacheRecords1.xml'

export type Bilagslinje = {
  /** «4177 ST1 Lone» eller «9900 Admin», slik fila skriver det. */
  butikk: string
  /** «627 Renhold». Flyttet seg i februar 2026 — se `kontoregister.ts`. */
  rapportlinje: string
  /** «6270 Renhold». Den durable identiteten. */
  konto: string
  /** «202607» */
  periode: string
  /** Bilagsteksten: leverandørnavn, eller det den som førte skrev. */
  tekst: string
  belopKr: number
}

const avkod = (s: string) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'").replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)))
    .replace(/&amp;/g, '&')

/** Feltnavnene i rekkefølge, med sine delte verdier. */
function feltene(xml: string): { navn: string; delte: (string | null)[] }[] {
  const ut: { navn: string; delte: (string | null)[] }[] = []
  for (const f of xml.matchAll(/<cacheField\b([^>]*)>([\s\S]*?)<\/cacheField>|<cacheField\b([^>]*)\/>/g)) {
    const attr = f[1] ?? f[3] ?? ''
    const navn = avkod(/name="([^"]*)"/.exec(attr)?.[1] ?? '')
    const delte: (string | null)[] = []
    const si = /<sharedItems\b[^>]*>([\s\S]*?)<\/sharedItems>/.exec(f[2] ?? '')
    if (si) {
      for (const it of si[1].matchAll(/<(s|n|b|d|m)\b([^>]*)\/?>/g)) {
        if (it[1] === 'm') { delte.push(null); continue }
        delte.push(avkod(/v="([^"]*)"/.exec(it[2])?.[1] ?? ''))
      }
    }
    ut.push({ navn, delte })
  }
  return ut
}

/** Finner feltets posisjon på navn. Kaster — rekkefølgen er koblingen. */
function indeks(felt: { navn: string }[], ...alternativer: string[]): number {
  for (const a of alternativer) {
    const i = felt.findIndex((f) => f.navn.toLowerCase() === a.toLowerCase())
    if (i >= 0) return i
  }
  throw new ParserFeil(
    `Bilagsbufferen mangler feltet «${alternativer[0]}». `
    + `Fant: ${felt.map((f) => f.navn).join(', ')}.`,
  )
}

/**
 * Leser bilagslinjene. `null` når fila ikke har en pivotbuffer — noen
 * månedsfiler mangler den, og det er ikke en feil ved fila.
 *
 * `paaLinje` kalles per rad. Ingen array bygges her: bufferen kan være
 * over en megabyte, og den som kaller vet om den vil summere eller lagre.
 */
export function lesBilagsbuffer(
  data: Uint8Array | ArrayBuffer,
  paaLinje: (l: Bilagslinje) => void,
): { antall: number; perioder: string[] } | null {
  const deler = delnavn(data)
  if (!deler.includes(DEF) || !deler.includes(REC)) return null

  const felt = feltene(lesDel(data, DEF))
  if (felt.length === 0) return null

  const iButikk = indeks(felt, 'Butikk')
  const iLinje = indeks(felt, 'Rapportlinje')
  const iKonto = indeks(felt, 'Konto')
  const iPeriode = indeks(felt, 'Periode')
  const iTekst = indeks(felt, 'Tekst')
  const iBelop = indeks(felt, 'Beløp', 'Belop', 'Beloep')

  let antall = 0
  const perioder = new Set<string>()
  let rest = ''

  const verdi = (barn: RegExpMatchArray[], i: number): string | null => {
    const b = barn[i]
    if (!b) return null
    const tag = b[1]
    if (tag === 'm') return null
    const v = /v="([^"]*)"/.exec(b[2])?.[1]
    if (v === undefined) return null
    // `<x v="3"/>` peker inn i feltets delte verdier. De andre bærer
    // verdien selv.
    return tag === 'x' ? (felt[i].delte[Number(v)] ?? null) : avkod(v)
  }

  const behandle = (tekst: string, ferdig: boolean) => {
    rest += tekst
    let siste = 0
    for (const m of rest.matchAll(/<r>([\s\S]*?)<\/r>/g)) {
      siste = (m.index ?? 0) + m[0].length
      const barn = [...m[1].matchAll(/<(x|n|s|b|d|e|m)\b([^>]*?)\/?>/g)]
      // ET FELT SOM FALLER UT FORSKYVER ALT ETTER SEG. Da blir beløpet
      // til en dato, uten at noe roper. Heller felle raden.
      if (barn.length !== felt.length) {
        throw new ParserFeil(
          `Bilagsbufferen: en rad har ${barn.length} felter, arket sier ${felt.length}. `
          + 'Rekkefølgen er hele koblingen mellom rad og feltnavn.',
        )
      }
      const belop = Number(verdi(barn, iBelop) ?? '')
      if (!Number.isFinite(belop)) continue
      const periode = verdi(barn, iPeriode) ?? ''
      const linje: Bilagslinje = {
        butikk: verdi(barn, iButikk) ?? '',
        rapportlinje: verdi(barn, iLinje) ?? '',
        konto: verdi(barn, iKonto) ?? '',
        periode,
        tekst: (verdi(barn, iTekst) ?? '').trim(),
        belopKr: belop,
      }
      if (periode) perioder.add(periode)
      antall++
      paaLinje(linje)
    }
    rest = ferdig ? '' : rest.slice(siste)
  }

  lesDelStrom(data, REC, behandle)
  return { antall, perioder: [...perioder].sort() }
}

// =====================================================================
// SUMMERING
// =====================================================================
//
// Kornet vi lagrer på: butikk × periode × konto × tekst. Det er det
// grovest mulige kornet som fortsatt svarer på «hvem gikk pengene til»,
// og det som gjør «ASKO Vest 29 825 mot Vardens 7 207» mulig.
//
// `antall` er med fordi det er et eget signal: fire fakturaer fra samme
// leverandør er en avtale, atten er en vane.

export type Leverandorsum = {
  butikk: string
  periode: string
  rapportlinje: string
  konto: string
  tekst: string
  belopKr: number
  antall: number
}

export function summerPerLeverandor(linjer: Iterable<Bilagslinje>): Leverandorsum[] {
  const m = new Map<string, Leverandorsum>()
  for (const l of linjer) {
    // Uten tekst er raden fortsatt et beløp på en konto, og skal med —
    // men den skal ikke slås sammen med en navngitt leverandør.
    const tekst = l.tekst || '(uten tekst)'
    const n = `${l.butikk}|${l.periode}|${l.konto}|${tekst}`
    const f = m.get(n)
    if (f) { f.belopKr += l.belopKr; f.antall++; continue }
    m.set(n, {
      butikk: l.butikk, periode: l.periode, rapportlinje: l.rapportlinje,
      konto: l.konto, tekst, belopKr: l.belopKr, antall: 1,
    })
  }
  return [...m.values()]
}

/** Butikknummeret foran navnet: «4177 ST1 Lone» → «4177». */
export function butikknummer(butikk: string): string | null {
  const m = /^(\d{3,5})\b/.exec(butikk.trim())
  return m ? m[1] : null
}
