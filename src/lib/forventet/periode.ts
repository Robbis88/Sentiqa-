import { forventetSalg, type Forventetinput, type Forventning } from './motor'
import { oppsummerTreff, type Treffinput, type Treffmaal } from './treffsikkerhet'
import { leggTilDager } from '@/lib/produksjonsplan'

// Målingen horisontbred.test.ts dekker h1–h13 og uker. Måned er utenfor.
export const MAKS_HORISONT_DAGER = 13
export const MAKS_PERIODE_DAGER = 7

export function forventetPeriode(inn: Omit<Forventetinput, 'maalDato'> & { prognoseDato: string; maaldatoer: readonly string[] }): {
  antall: number | null; dager: { dato: string; forventning: Forventning }[]
} {
  if (!inn.maaldatoer.length || inn.maaldatoer.length > MAKS_PERIODE_DAGER
    || inn.maaldatoer.some((d, i) => d <= inn.prognoseDato || d > leggTilDager(inn.prognoseDato, MAKS_HORISONT_DAGER)
      || (i > 0 && d !== leggTilDager(inn.maaldatoer[i - 1], 1)))) throw new Error('Prognosen krever 1–7 sammenhengende dager innenfor h1–h13')
  // Samme kunnskapstidspunkt for ALLE dager; ingen syntetiske salg mates tilbake.
  const salg = inn.salg.filter((r) => r.dato <= inn.prognoseDato)
  const dager = inn.maaldatoer.map((dato) => ({ dato, forventning: forventetSalg({ ...inn, salg, maalDato: dato }) }))
  const antall = dager.every((d) => d.forventning.slag === 'beregnet')
    ? dager.reduce((s, d) => s + (d.forventning.slag === 'beregnet' ? d.forventning.antall : 0), 0) : null
  return { antall, dager }
}

/** Hele perioder målt fra samme kunnskapstidspunkt som den kommende perioden. */
export function maalPeriodetreff(inn: Treffinput & { antallDager: number; horisontDager: number }): Treffmaal | null {
  if (!Number.isInteger(inn.antallDager) || inn.antallDager < 1 || inn.antallDager > MAKS_PERIODE_DAGER
    || !Number.isInteger(inn.horisontDager) || inn.horisontDager < 1 || inn.horisontDager + inn.antallDager - 1 > MAKS_HORISONT_DAGER) throw new Error('Ugyldig periode eller horisont for treffsikkerhet')
  const fasit = new Map<string, number>()
  for (const r of inn.salg) {
    if (r.stasjonId === inn.enhet.stasjonId && r.ean === inn.enhet.ean) fasit.set(r.dato, (fasit.get(r.dato) ?? 0) + r.antall)
  }
  const par: { forventet: number; faktisk: number }[] = []
  for (const slutt of inn.maaldatoer) {
    const start = leggTilDager(slutt, -(inn.antallDager - 1))
    const maaldatoer = Array.from({ length: inn.antallDager }, (_, i) => leggTilDager(start, i))
    const faktiske = maaldatoer.map((d) => fasit.get(d) ?? (inn.salgsdager?.has(d) ? 0 : undefined))
    if (faktiske.some((f) => f === undefined || !Number.isFinite(f))) continue
    const forventet = forventetPeriode({ ...inn, prognoseDato: leggTilDager(start, -inn.horisontDager), maaldatoer })
    if (forventet.antall === null) continue
    par.push({ forventet: forventet.antall, faktisk: faktiske.reduce<number>((s, f) => s + f!, 0) })
  }
  return oppsummerTreff(par)
}
