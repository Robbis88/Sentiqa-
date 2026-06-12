// Produksjonsplan-motor (PROSJEKT.md §7). v2: prognose per produkt for en
// mål-dato basert på fjorårets samme ukedag (median ±2 uker) + nylig trend +
// værvarsel, med automatisk kampanje-deteksjon. Ren, testbar logikk — all
// datahenting skjer i kall-laget (page/handler), motoren regner.

export type Vaerdag = { temp_maks: number | null; nedbor_mm: number | null }

// ── Dato-hjelpere (UTC-middag unngår tidssone-drift) ───────────────────────
export function leggTilDager(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}
export function ukedag(iso: string): number {
  return new Date(`${iso}T12:00:00Z`).getUTCDay() // 0=søndag … 6=lørdag
}
function median(xs: number[]): number {
  if (xs.length === 0) return 0
  const s = [...xs].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}
function snitt(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0
}

// ── Værfaktor: forventet vær (mål) vs fjorårets vær på match-dagen ──────────
// Sammenligner det vi venter mot det som faktisk var, vektet av stasjonens
// værfølsomhet (0 = uberørt, 1 = full effekt) og produktgruppens karakter.
export function vaerfaktor(maal: Vaerdag | null, fjor: Vaerdag | null, folsomhet: number, varegruppeNavn: string): number {
  if (!maal || maal.temp_maks == null) return 1
  const navn = varegruppeNavn.toLowerCase()
  const kald = /(kaffe|varm|suppe|oppvarmet|sjokolade)/.test(navn)
  const varm = /(drikke|is|salat|kald)/.test(navn)
  let f = 1
  const fjorTemp = fjor?.temp_maks ?? maal.temp_maks // mangler fjor-vær → ingen delta
  const dTemp = maal.temp_maks - fjorTemp // + = varmere enn i fjor
  if (varm && dTemp !== 0) f *= 1 + Math.max(-0.4, Math.min(0.4, dTemp * 0.02))
  if (kald && dTemp !== 0) f *= 1 + Math.max(-0.4, Math.min(0.4, -dTemp * 0.02))
  // Regn demper utesalg/ferskvare litt
  const regn = maal.nedbor_mm != null && maal.nedbor_mm >= 5
  if (regn && varm) f *= 0.92
  // Skaler mot stasjonens lærte følsomhet
  return 1 + (f - 1) * Math.max(0, Math.min(1, folsomhet))
}

// ── Hovedmotor ─────────────────────────────────────────────────────────────
export type SalgsPunkt = {
  dato: string
  varenavn: string
  varegruppeKode: string | null
  varegruppeNavn: string | null
  antall: number
}
export type Flagg = 'fjor_kampanje' | 'paagaaende_kampanje' | 'ny' | 'fa_data'
export type ProduktForslag = {
  varenavn: string
  varegruppeKode: string | null
  varegruppeNavn: string | null
  fjorMedian: number | null
  nyligSnitt: number | null
  basis: number
  vaerfaktor: number
  trendfaktor: number
  samletfaktor: number
  foreslatt: number
  flagg: Flagg[]
}
export type PlanForslag = { forslag: ProduktForslag[]; advarsler: string[] }

const KAMPANJE_HOY = 1.7
const KAMPANJE_LAV = 0.5

export function lagProduksjonsplan(opts: {
  maalDato: string
  sisteSalgsdato: string // siste dag med faktisk salg (ikke «i dag»)
  salg: SalgsPunkt[] // alt relevant salg (fjor-vindu + siste 28 dager)
  vaerMaal: Vaerdag | null
  vaerFjor: Vaerdag | null
  vaerfolsomhet: number
  ekskluderte?: Set<string>
  helligdag?: boolean // mål-dagen er helligdag → kun selve fjor-helligdagen, ingen naboer
}): PlanForslag {
  const { maalDato, sisteSalgsdato, salg, vaerMaal, vaerFjor, vaerfolsomhet } = opts
  const ekskluderte = opts.ekskluderte ?? new Set<string>()
  const advarsler: string[] = []

  const malUkedag = ukedag(maalDato)
  // Fjor-match: samme ukedag for 52 uker siden (364 dager).
  const fjorBase = leggTilDager(maalDato, -364)
  const fjorDatoer = opts.helligdag ? [fjorBase] : [-14, -7, 0, 7, 14].map((d) => leggTilDager(fjorBase, d))
  const fjorSett = new Set(fjorDatoer)
  // Nylig: siste 28 dager fram til siste salgsdag.
  const nyligStart = leggTilDager(sisteSalgsdato, -27)

  // Indekser salget per produkt.
  type Agg = { kode: string | null; gruppe: string | null; fjor: Map<string, number>; nylig: { dato: string; antall: number }[] }
  const per = new Map<string, Agg>()
  let trendNaa = 0
  let trendFjor = 0
  for (const r of salg) {
    const navn = (r.varenavn ?? '').trim()
    if (!navn) continue
    let a = per.get(navn)
    if (!a) { a = { kode: r.varegruppeKode, gruppe: r.varegruppeNavn, fjor: new Map(), nylig: [] }; per.set(navn, a) }
    if (!a.kode && r.varegruppeKode) a.kode = r.varegruppeKode
    if (!a.gruppe && r.varegruppeNavn) a.gruppe = r.varegruppeNavn
    if (fjorSett.has(r.dato)) a.fjor.set(r.dato, (a.fjor.get(r.dato) ?? 0) + r.antall)
    if (r.dato >= nyligStart && r.dato <= sisteSalgsdato) a.nylig.push({ dato: r.dato, antall: r.antall })
    // Trend: total siste 28 dager vs samme 28-dagers vindu i fjor.
    if (r.dato >= nyligStart && r.dato <= sisteSalgsdato) trendNaa += r.antall
    if (r.dato >= leggTilDager(nyligStart, -364) && r.dato <= leggTilDager(sisteSalgsdato, -364)) trendFjor += r.antall
  }

  const trendfaktor = trendFjor > 0 ? Math.max(0.6, Math.min(1.6, trendNaa / trendFjor)) : 1
  if (vaerMaal?.temp_maks == null) advarsler.push('Mangler værvarsel for mål-dagen — bruker kun salgshistorikk.')
  if (sisteSalgsdato < leggTilDager(maalDato, -10)) advarsler.push(`Salgsdataene er fra ${sisteSalgsdato} — kan være utdaterte.`)

  const forslag: ProduktForslag[] = []
  for (const [varenavn, a] of per.entries()) {
    if (ekskluderte.has(varenavn)) continue
    const flagg: Flagg[] = []

    // Fjor-median (kun dager produktet faktisk solgte i vinduet).
    const fjorVerdier = [...a.fjor.values()].filter((v) => v > 0)
    let fjorMedian: number | null = fjorVerdier.length ? median(fjorVerdier) : null

    // Kampanje i fjor: match-dagen unormalt høy mot naboukene → bruk nabo-median.
    if (!opts.helligdag && fjorMedian != null) {
      const matchDag = a.fjor.get(fjorBase) ?? 0
      const naboer = [-14, -7, 7, 14].map((d) => a.fjor.get(leggTilDager(fjorBase, d)) ?? 0).filter((v) => v > 0)
      const naboMed = naboer.length ? median(naboer) : matchDag
      if (matchDag > 0 && naboMed > 0 && matchDag > KAMPANJE_HOY * naboMed) {
        fjorMedian = naboMed
        flagg.push('fjor_kampanje')
      }
    }

    // Nylig snitt: samme ukedag siste 28 dager; for få → alle dager.
    const sammeUkedag = a.nylig.filter((p) => ukedag(p.dato) === malUkedag).map((p) => p.antall)
    const alleNylig = a.nylig.map((p) => p.antall)
    const nyligSnitt = sammeUkedag.length >= 2 ? snitt(sammeUkedag) : (alleNylig.length ? snitt(alleNylig) : null)

    // Basis: fjor-median (hvis fortsatt i salg) ellers nylig (nytt produkt).
    let basis: number
    if (fjorMedian != null && nyligSnitt != null) {
      basis = fjorMedian
      // Pågående kampanje: nylig avviker mye fra fjor → vekt 50/50.
      if (nyligSnitt > KAMPANJE_HOY * fjorMedian || nyligSnitt < KAMPANJE_LAV * fjorMedian) {
        basis = 0.5 * fjorMedian + 0.5 * nyligSnitt
        flagg.push('paagaaende_kampanje')
      }
    } else if (nyligSnitt != null) {
      basis = nyligSnitt
      if (fjorMedian == null) flagg.push('ny')
    } else {
      continue // hverken fjor eller nylig salg → utgått, hopp over
    }

    if (fjorVerdier.length + sammeUkedag.length < 3) flagg.push('fa_data')

    const vf = vaerfaktor(vaerMaal, vaerFjor, vaerfolsomhet, a.gruppe ?? '')
    const samletfaktor = vf * trendfaktor
    const foreslatt = Math.max(0, Math.round(basis * samletfaktor))

    forslag.push({
      varenavn, varegruppeKode: a.kode, varegruppeNavn: a.gruppe,
      fjorMedian: fjorMedian != null ? Math.round(fjorMedian * 10) / 10 : null,
      nyligSnitt: nyligSnitt != null ? Math.round(nyligSnitt * 10) / 10 : null,
      basis: Math.round(basis * 10) / 10, vaerfaktor: Math.round(vf * 100) / 100,
      trendfaktor: Math.round(trendfaktor * 100) / 100, samletfaktor: Math.round(samletfaktor * 100) / 100,
      foreslatt, flagg,
    })
  }

  if (forslag.some((f) => f.flagg.includes('fjor_kampanje'))) advarsler.push('Noen produkter hadde kampanje på match-dagen i fjor (🚩) — justert ned mot normalnivå.')
  if (forslag.some((f) => f.flagg.includes('paagaaende_kampanje'))) advarsler.push('Mulig pågående kampanje (🎯) — forslaget vekter nåsalg og fjorår 50/50.')
  if (ekskluderte.size > 0) advarsler.push(`${ekskluderte.size} produkt(er) er ekskludert fra planen.`)

  forslag.sort((x, y) => y.foreslatt - x.foreslatt)
  return { forslag, advarsler }
}

// ── Bakoverkompatibel enkel værfaktor (brukt av v1-fallback om nødvendig) ──
export function produksjonsfaktor(stasjonstype: string, vaer: Vaerdag | null, ukedagN: number, varegruppeNavn: string): number {
  let f = 1
  const erHelg = ukedagN === 0 || ukedagN === 6
  const varmt = vaer?.temp_maks != null && vaer.temp_maks >= 18
  const kaldt = vaer?.temp_maks != null && vaer.temp_maks < 5
  const regn = vaer?.nedbor_mm != null && vaer.nedbor_mm >= 5
  const navn = varegruppeNavn.toLowerCase()
  if (stasjonstype === 'utfart') { if (erHelg && varmt) f *= 1.2; else if (!erHelg) f *= 0.9 }
  else if (stasjonstype === 'pendler') { if (erHelg) f *= 0.75 }
  else if (stasjonstype === 'sentrum') { if (erHelg) f *= 1.1 }
  if (varmt && /(drikke|is|salat)/.test(navn)) f *= 1.15
  if (kaldt && /(kaffe|varm|suppe|oppvarmet)/.test(navn)) f *= 1.1
  if (regn && /(oppvarmet|kaffe|varm)/.test(navn)) f *= 1.1
  return f
}
