// Salgsprognose for i morgen, per AVDELING (omsetning). Samme metode som
// produksjonsplanen (fjorårets samme ukedag ±2 uker som median + nylig trend +
// værfaktor + ukedag/stasjonstype), men for omsetning per kategori i stedet for
// produksjonsmengder. Ren, testbar logikk — datahenting skjer i kall-laget.
import { leggTilDager, ukedag, vaerfaktor, produksjonsfaktor, type Vaerdag } from './produksjonsplan'

export type AvdSalg = { dato: string; avdelingKode: string; avdelingNavn: string; omsetning: number }
export type AvdForslag = { kode: string; navn: string; forventet: number; basis: number; endringPst: number; vaerfaktor: number }
export type SalgsPrognose = { maalDato: string; ukedag: number; forslag: AvdForslag[]; totalBasis: number; totalForventet: number; advarsler: string[] }

function median(xs: number[]): number {
  if (xs.length === 0) return 0
  const s = [...xs].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}
function snitt(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0
}

export function lagSalgsprognose(opts: {
  maalDato: string
  sisteSalgsdato: string
  salg: AvdSalg[]
  vaerMaal: Vaerdag | null
  vaerFjor: Vaerdag | null
  vaerfolsomhet: number
  stasjonstype: string
  helligdag?: boolean // mål-dagen er helligdag → kun selve fjor-helligdagen, ingen naboer
}): SalgsPrognose {
  const { maalDato, sisteSalgsdato, salg, vaerMaal, vaerFjor, vaerfolsomhet, stasjonstype } = opts
  const advarsler: string[] = []
  const wd = ukedag(maalDato)
  const fjorBase = leggTilDager(maalDato, -364)
  const fjorSett = opts.helligdag ? new Set([fjorBase]) : new Set([-14, -7, 0, 7, 14].map((d) => leggTilDager(fjorBase, d)))
  const nyligStart = leggTilDager(sisteSalgsdato, -27)

  type Agg = { navn: string; fjor: Map<string, number>; nylig: { dato: string; oms: number }[] }
  const per = new Map<string, Agg>()
  let trendNaa = 0, trendFjor = 0
  for (const r of salg) {
    if (!r.avdelingKode) continue
    let a = per.get(r.avdelingKode)
    if (!a) { a = { navn: r.avdelingNavn, fjor: new Map(), nylig: [] }; per.set(r.avdelingKode, a) }
    if (fjorSett.has(r.dato)) a.fjor.set(r.dato, (a.fjor.get(r.dato) ?? 0) + r.omsetning)
    if (r.dato >= nyligStart && r.dato <= sisteSalgsdato) { a.nylig.push({ dato: r.dato, oms: r.omsetning }); trendNaa += r.omsetning }
    if (r.dato >= leggTilDager(nyligStart, -364) && r.dato <= leggTilDager(sisteSalgsdato, -364)) trendFjor += r.omsetning
  }

  const trendfaktor = trendFjor > 0 ? Math.max(0.6, Math.min(1.6, trendNaa / trendFjor)) : 1
  if (vaerMaal?.temp_maks == null) advarsler.push('Mangler værvarsel for mål-dagen — prognosen bruker kun salgshistorikk + trend.')
  if (sisteSalgsdato < leggTilDager(maalDato, -10)) advarsler.push(`Salgsdataene er fra ${sisteSalgsdato} — prognosen kan være mindre presis.`)

  const forslag: AvdForslag[] = []
  for (const [kode, a] of per.entries()) {
    const fjorV = [...a.fjor.values()].filter((v) => v > 0)
    const fjorMedian = fjorV.length ? median(fjorV) : null
    const sameWd = a.nylig.filter((p) => ukedag(p.dato) === wd).map((p) => p.oms)
    const alle = a.nylig.map((p) => p.oms)
    const nyligSnitt = sameWd.length >= 2 ? snitt(sameWd) : (alle.length ? snitt(alle) : null)

    let basis: number
    if (fjorMedian != null) basis = fjorMedian
    else if (nyligSnitt != null) basis = nyligSnitt
    else continue

    const vf = vaerfaktor(vaerMaal, vaerFjor, vaerfolsomhet, a.navn)
    const tf = produksjonsfaktor(stasjonstype, vaerMaal, wd, a.navn)
    const forventet = Math.max(0, Math.round(basis * vf * tf * trendfaktor))
    forslag.push({
      kode, navn: a.navn, forventet, basis: Math.round(basis),
      endringPst: Math.round((vf * tf - 1) * 100), // vær- + ukedag-effekt (uten ren trend)
      vaerfaktor: Math.round(vf * 100) / 100,
    })
  }
  forslag.sort((a, b) => b.forventet - a.forventet)
  return {
    maalDato, ukedag: wd, forslag,
    totalBasis: forslag.reduce((s, f) => s + f.basis, 0),
    totalForventet: forslag.reduce((s, f) => s + f.forventet, 0),
    advarsler,
  }
}
