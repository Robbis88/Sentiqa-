import { describe, it, expect } from 'vitest'
import { finnAaret, type Matbudsjett } from './delingsfil-aar'
import type { Delingsrad } from '@/lib/parsere/delingsfil'

// =====================================================================
// Tallene er Kelsars egne. `Budsjettert matomsetning` i delingsfila er
// BP-ens Mat paa krona:
//
//   SHELL LAGUNEPARKEN   4 651 908  =  BP 2025 kode 120
//   SHELL VARDEN         2 119 896
//   SHELL BOENES         1 700 096
//
// OG NAVNENE STEMMER IKKE. Stasjonene byttet fra Shell til St1 mot
// slutten av 2025, saa 2025-fila sier "SHELL" mens basen sier "St1".
// Det er hele grunnen til at beloepet er noekkelen og navnet bare en
// kryssjekk.
// =====================================================================

const rad = (butikknavn: string, timebudsjett: number, matomsetning: number): Delingsrad =>
  ({ butikknavn, timebudsjett, matomsetning, kostPerTime: null, kronebudsjett: null })

const FILA: Delingsrad[] = [
  rad('SHELL BØNES', 6654, 1700095.8050394272),
  rad('SHELL LAGUNEPARKEN', 13212.84, 4651907.996552096),
  rad('SHELL VARDEN', 8957.42, 2119896.3105635946),
]

const budsjett = (per: Record<number, Record<string, number>>): Matbudsjett =>
  new Map(Object.entries(per).map(([ar, s]) => [Number(ar), new Map(Object.entries(s))]))

const BASEN = budsjett({
  2025: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
  2026: { bones: 1_900_000, laguneparken: 5_000_000, varden: 2_300_000 },
})

const INGEN_NAVN = new Map<string, string>()

describe('finnAaret', () => {
  it('KANARIFUGL: finner år OG stasjon uten å bruke navnet', () => {
    // Stasjonene byttet navn fra Shell til St1 mot slutten av 2025.
    // Ville koblingen hvilt paa navnet, ville den ryket ved neste
    // merkebytte - og den ville ryket i stillhet.
    const svar = finnAaret(FILA, INGEN_NAVN, BASEN)
    expect(svar.ar).toBe(2025)
    if (svar.ar === null) throw new Error('skulle funnet aaret')
    expect(svar.kobling.get('shell laguneparken')).toBe('laguneparken')
    expect(svar.kobling.get('shell varden')).toBe('varden')
    expect(svar.kobling.get('shell bønes')).toBe('bones')
    expect(svar.ukoblet).toEqual([])
  })

  it('velger årgangen som forklarer flest rader', () => {
    // Et enkelt tall kan tilfeldigvis staa likt to aar paa rad. Aaret som
    // forklarer FLEST rader er det fila hoerer til.
    const overlapp = budsjett({
      2025: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
      2026: { bones: 1700095.81, laguneparken: 5_000_000, varden: 2_300_000 },
    })
    expect(finnAaret(FILA, INGEN_NAVN, overlapp).ar).toBe(2025)
  })

  it('KANARIFUGL: to årganger som forklarer like mange gir INGEN plassering', () => {
    // «Velg det nyeste» ville vaert en gjetning forkledd som en regel.
    const tvetydig = budsjett({
      2025: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
      2026: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
    })
    const svar = finnAaret(FILA, INGEN_NAVN, tvetydig)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/2025 og 2026/)
  })

  it('KANARIFUGL: toleransen er én krone, ikke «omtrent»', () => {
    // Tallene kommer fra samme kilde og skal vaere identiske. Slingring
    // ville gjort det lettere aa treffe feil stasjon.
    const tiKronerFeil = budsjett({
      2025: { bones: 1700105.81, laguneparken: 4651908, varden: 2119896.31 },
    })
    const svar = finnAaret(FILA, INGEN_NAVN, tiKronerFeil)
    expect(svar.ar).toBe(2025)
    // Boenes faller ut - de to andre kobles.
    if (svar.ar === null) throw new Error('skulle funnet aaret')
    expect(svar.kobling.size).toBe(2)
    expect(svar.ukoblet).toEqual(['SHELL BØNES'])
  })

  it('KANARIFUGL: to stasjoner med samme Mat-budsjett kobles ikke', () => {
    // Da peker beloepet to steder, og et treff er en gjetning.
    const likt = budsjett({
      2025: { a: 4651908, b: 4651908 },
    })
    const svar = finnAaret([rad('SHELL X', 5000, 4651908)], INGEN_NAVN, likt)
    expect(svar.ar).toBeNull()
  })

  it('KANARIFUGL: navnet og beløpet må være enige', () => {
    // To uavhengige kjennemerker som peker hver sin vei betyr at ett av
    // dem er feil - og vi vet ikke hvilket. Da skrives ingenting.
    const navnSierFeil = new Map([['shell laguneparken', 'varden']])
    const svar = finnAaret(FILA, navnSierFeil, BASEN)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/peker på én stasjon etter navnet/)
  })

  it('godtar at navnet er ukjent — det er bare en kryssjekk', () => {
    const bareEn = new Map([['shell varden', 'varden']])
    expect(finnAaret(FILA, bareEn, BASEN).ar).toBe(2025)
  })

  it('sier fra når ingen BP er lastet', () => {
    const svar = finnAaret(FILA, INGEN_NAVN, new Map())
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/BP-en må komme først/)
  })

  it('lar stasjoner vi ikke driver være — de er ikke en feil', () => {
    // St1 sender ofte hele klyngen.
    const medFremmed = [...FILA, rad('SHELL EN ANNEN', 5000, 123456)]
    const svar = finnAaret(medFremmed, INGEN_NAVN, BASEN)
    expect(svar.ar).toBe(2025)
    if (svar.ar === null) throw new Error('skulle funnet aaret')
    expect(svar.ukoblet).toEqual(['SHELL EN ANNEN'])
  })
})
