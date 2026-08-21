import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// Hvor mye margin har dempet tekst egentlig?
//
// HVA DENNE IKKE ER. `tilgjengelighet.test.ts` kan ikke måle kontrast —
// jsdom har ingen layout, ingen sammensatte flater, ingen
// gjennomsiktighet. Bare nettleseren kan det, og den gjør det: axe
// kjører på hver rute i `nettleser`-jobben.
//
// MEN AXE SER BARE DET SOM RENDRES. Kontrastfeilen på `/businessplan`
// ble funnet fordi CI tilfeldigvis hadde salg uten BP, så nettopp den
// grenen tegnet seg. Etter at den feilen ble rettet, tegner grenen seg
// ikke lenger i CI — og målingen som fant feilen ville ikke funnet den
// på nytt.
//
// Så det som står igjen å sikre er ikke selve rendringen, men TALLET:
// `--tekst-svak` har nesten ingen margin. 4,71:1 på kortet, der 4,5
// kreves. Den tåler ingenting oppå seg:
//
//   * `opacity: 0.75` på en forelder dro den til 2,98:1. Det var den
//     faktiske feilen, og den sto ingen steder i koden — bare i det
//     nettleseren regnet ut.
//   * på arbeidsflaten `--bg` er den 4,55:1. Den passerer, men med
//     0,05 å gå på. Alt som legger seg oppå — en flate til, en
//     gjennomsiktighet, en litt lysere grå — bryter den.
//
// Marginen er en egenskap ved fargene, ikke ved en side. Derfor står den
// her, som regnestykke, i stedet for i en kommentar noen kan endre uten
// å merke det.
// =====================================================================

const CSS = join(process.cwd(), 'src', 'app', 'globals.css')

/** Relativ luminans etter WCAG 2.1. */
function luminans(hex: string): number {
  const kanal = [1, 3, 5]
    .map((i) => parseInt(hex.substr(i, 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
  return 0.2126 * kanal[0] + 0.7152 * kanal[1] + 0.0722 * kanal[2]
}

export function kontrast(forgrunn: string, bakgrunn: string): number {
  const a = luminans(forgrunn)
  const b = luminans(bakgrunn)
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

/**
 * Samme farge lagt på med gjennomsiktighet over en flate.
 *
 * Finnes her bare for å kunne vise hva `opacity` faktisk koster. Ingen
 * regel i systemet skal trenge den.
 */
export function blandet(farge: string, flate: string, alfa: number): string {
  const to = (h: string, i: number) => parseInt(h.substr(i, 2), 16)
  const b = [1, 3, 5].map((i) => Math.round(alfa * to(farge, i) + (1 - alfa) * to(flate, i)))
  return `#${b.map((v) => v.toString(16).padStart(2, '0')).join('')}`
}

function tokenverdier(): Record<string, string> {
  const css = readFileSync(CSS, 'utf8')
  const ut: Record<string, string> = {}
  for (const m of css.matchAll(/(?<![\w-])(--[a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{6})\s*;/g)) {
    if (!(m[1] in ut)) ut[m[1]] = m[2].toLowerCase()
  }
  return ut
}

const T = tokenverdier()
const KRAV = 4.5

describe('regnestykket stemmer', () => {
  test('kjente par gir kjente tall', () => {
    // KANARIFUGL. Er formelen feil, blir alt under grønt uten grunn.
    // Svart på hvitt er 21:1, og hvitt på hvitt er 1:1 — begge er
    // definisjoner, ikke målinger, så de kan ikke drive.
    expect(kontrast('#000000', '#ffffff')).toBeCloseTo(21, 1)
    expect(kontrast('#ffffff', '#ffffff')).toBeCloseTo(1, 5)
  })

  test('tokenene ble faktisk lest', () => {
    // Peker stien feil, blir T tom, alle oppslag undefined og hele
    // vakten grønn uten å ha sett en farge.
    expect(Object.keys(T).length, `fant nesten ingen hexverdier i ${CSS}`)
      .toBeGreaterThan(15)
    expect(T['--tekst-svak'], '--tekst-svak mangler').toMatch(/^#[0-9a-f]{6}$/)
  })
})

describe('dempet tekst har nesten ingen margin', () => {
  test('--tekst-svak holder på begge flatene — så vidt', () => {
    const paaKort = kontrast(T['--tekst-svak'], T['--kort'])
    const paaFlate = kontrast(T['--tekst-svak'], T['--bg'])

    expect(paaKort, `--tekst-svak på --kort er ${paaKort.toFixed(2)}:1`)
      .toBeGreaterThanOrEqual(KRAV)
    expect(paaFlate, `--tekst-svak på --bg er ${paaFlate.toFixed(2)}:1`)
      .toBeGreaterThanOrEqual(KRAV)

    // HVOR TYNN MARGINEN ER, SKREVET NED. Den er 0,21 på kortet og 0,05
    // på arbeidsflaten. Blir --tekst-svak ett hakk lysere, faller den
    // ene eller begge — og det ville ellers bare vist seg som en axe-feil
    // på en tilfeldig side, langt fra fargen som forårsaket den.
    expect(Math.min(paaKort, paaFlate) - KRAV,
      `minste margin er ${(Math.min(paaKort, paaFlate) - KRAV).toFixed(2)}`)
      .toBeLessThan(0.3)
  })

  test('gjennomsiktighet over dempet tekst bryter kravet', () => {
    // DEN FAKTISKE FEILEN, SOM REGNESTYKKE. `opacity: 0.75` på raden
    // rundt ga 2,98:1 der 4,5 kreves — og ingenting i CSS-en sa det.
    const dempet = blandet(T['--tekst-svak'], T['--kort'], 0.75)
    const maalt = kontrast(dempet, T['--kort'])

    expect(maalt, `0.75 opacity gir ${maalt.toFixed(2)}:1`).toBeLessThan(KRAV)

    // Og hvor lite som skal til: selv 0.9 spiser nesten hele marginen.
    const nesten = kontrast(blandet(T['--tekst-svak'], T['--kort'], 0.9), T['--kort'])
    expect(nesten, `0.9 opacity gir ${nesten.toFixed(2)}:1`).toBeLessThan(KRAV)
  })

  test('sterk tekst tåler flatene den brukes på', () => {
    for (const flate of ['--kort', '--bg'] as const) {
      const v = kontrast(T['--tekst'], T[flate])
      expect(v, `--tekst på ${flate} er ${v.toFixed(2)}:1`).toBeGreaterThanOrEqual(KRAV)
    }
  })
})

describe('businessplan-raden står på kortet', () => {
  const UI = join(process.cwd(), 'src', 'components', 'ui', 'ui.css')

  test('.bp-rad-plan dempes ikke med opacity', () => {
    const css = readFileSync(UI, 'utf8')
    const regel = css.match(/\.bp-rad-plan\s*\{([^}]*)\}/)

    expect(regel, '.bp-rad-plan finnes ikke lenger i ui.css').not.toBeNull()

    const kropp = regel![1]
    expect(kropp, `.bp-rad-plan {${kropp}}`).not.toMatch(/opacity/)
    // Og den skal ikke flytte seg av kortet heller — se testen over for
    // hvorfor --bg ikke holder for dempet tekst.
    expect(kropp, `.bp-rad-plan {${kropp}}`).not.toMatch(/background/)
  })
})
