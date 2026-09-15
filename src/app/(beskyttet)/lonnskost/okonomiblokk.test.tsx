import { describe, expect, it } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { createElement as h } from 'react'
import { Lonnsblokk } from './okonomiblokk'
import { kr } from '@/lib/format'
import { byggOkonomibilde, type Bildeinput, type Dekning } from '@/lib/okonomi/bilde'
import type { Lonnsrom } from '@/lib/lonnskost/rom'

// =====================================================================
// DET SKAL VAERE UMULIG AA SE LOENNSROMMET UTEN AA SE MAANEDEN
// =====================================================================
//
// FUNN I PRODUKSJON 2026-09-15. Overskriften sto uten maaned, og rett
// under viste noekkeltallene «Loenn av brutto · august 2026» med
// «Rommet er 346 285 kr» - mens blokken sa «Loennsrom 137 489 kr».
//
// De gjaldt ULIKE MAANEDER. Noekkeltallene krever easy@work-data og
// faller paa siste avlagte maaned; blokken viser nyeste maaned med et
// rom, altsaa den inneveerende og halvgaatte. Uten maaneden i
// overskriften ser det ut som to svar paa samme spoersmaal.
//
// Testene under beviser tre ting:
//   1  maaneden STAAR i overskriften
//   2  den kommer fra `bilde.maaned`, ikke fra dagens dato eller noe annet
//   3  den foelger med naar maaneden endres - saa en hardkodet streng
//      eller en utledet «naa» ikke kan bestaa
// =====================================================================

const ANDEL = 383285 / 1201000

const ROM = (o: Partial<Lonnsrom> = {}): Lonnsrom => ({
  maaned: '2026-09',
  bruttoKr: 189406,
  anslaatt: true,
  lonnsandel: ANDEL,
  romKr: 137489,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 2100000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
  ...o,
})

const DEKNING: Dekning = {
  salgsdager: { har: 14, av: 14 },
  bilvaskUker: { har: 2, av: 2 },
  lonnsfil: false,
  regnskap: false,
  mangler: [],
  retningPaaFeil: 'ukjent',
}

const BILDE = (maaned: string) => byggOkonomibilde({
  stasjonId: 's1',
  maaned,
  rom: ROM({ maaned }),
  regnskap: null,
  easyatworkLonnKr: null,
  dagligOmsetningKr: 2100000,
  dekning: DEKNING,
} satisfies Bildeinput)

const tegn = (maaned: string) =>
  renderToStaticMarkup(h(Lonnsblokk, { bilde: BILDE(maaned) }))

describe('maaneden staar i overskriften', () => {
  it('september 2026 navngis', () => {
    expect(tegn('2026-09')).toContain('september 2026')
  })

  it('KANARIFUGL: maaneden FOELGER `bilde.maaned`, den er ikke fast', () => {
    // Uten denne ville en hardkodet streng - eller en utledning av
    // dagens dato - bestaatt testen over. Da ville overskriften vaert
    // like feil som da den manglet helt, bare vanskeligere aa se.
    const mars = tegn('2026-03')
    expect(mars).toContain('mars 2026')
    expect(mars).not.toContain('september')
  })

  it('aarstallet foelger ogsaa med', () => {
    // Samme maaned i to aar er to forskjellige tall. En overskrift som
    // bare sier «september» skiller dem ikke.
    expect(tegn('2025-09')).toContain('september 2025')
    expect(tegn('2025-09')).not.toContain('2026')
  })

  it('maaneden staar i SAMME overskrift som loennsrommet', () => {
    // Ikke nok at maaneden finnes et sted i utsnittet - den skal staa i
    // tittelen, saa den ikke kan leses fra hverandre. Funnet i
    // produksjon var nettopp at tallet og perioden sto i hver sin boks.
    const ut = tegn('2026-09')
    const tittel = /<h3[^>]*>([^<]*)<\/h3>/.exec(ut)?.[1] ?? ''
    expect(tittel).toContain('Lønnsrommet')
    expect(tittel).toContain('september 2026')
  })

  it('sikkerhetsgraden staar fortsatt der', () => {
    // Regresjonsvakt: maaneden ble lagt INN i en tittel som alt bar
    // sikkerheten. Den skal ikke ha dyttet noe ut.
    expect(tegn('2026-09')).toContain('sikkerhet lav')
  })
})

describe('tallene er uendret av korreksjonen', () => {
  it('rommet og bruttoen staar som foer', () => {
    // Denne endringen var en OVERSKRIFT. Skulle et tall flytte seg, er
    // det en beregningsendring som ikke var bestilt.
    //
    // SAMME FORMATTER SOM KODEN. `kr.format` gir hardt mellomrom som
    // tusenskille paa nb-NO; en literal med vanlig mellomrom bommer.
    // Skrives fasiten med formatteren, kan de to ikke skille lag.
    const ut = tegn('2026-09')
    expect(ut).toContain(kr.format(189406))
    expect(ut).toContain(kr.format(137489))
  })

  it('manglende loenn staar som tankestrek, ikke som et beloep', () => {
    // CELLEN, IKKE HELE UTSNITTET. En `not.toContain('0 kr')` over hele
    // markupen ville felt et hvilket som helst tall som slutter paa
    // null - og bestaatt hvis den manglende raden sto med «0 kr» et
    // annet sted. Her leses selve cellen.
    const ut = tegn('2026-09')
    const celler = [...ut.matchAll(/<td class="tall">([^<]*)<\/td>/g)].map((m) => m[1])
    expect(celler).toHaveLength(4)
    expect(celler[2], 'Loenn skal vaere tankestrek').toBe('—')
    expect(celler[3], 'Styringsavvik skal vaere tankestrek').toBe('—')
  })
})
