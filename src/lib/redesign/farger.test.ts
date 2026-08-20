import { describe, expect, test } from 'vitest'
import { readFileSync, readdirSync, statSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { tellFarger, UNNTAK, kontrast, tokenverdier } from './farger'
import { utenKommentarer } from './design'

const SRC = join(process.cwd(), 'src')
const FASIT = join(SRC, 'lib', 'redesign', 'fargefasit.json')

function kildefiler(katalog: string): string[] {
  const ut: string[] = []
  for (const navn of readdirSync(katalog)) {
    const sti = join(katalog, navn)
    if (statSync(sti).isDirectory()) ut.push(...kildefiler(sti))
    else if (/\.(css|tsx?)$/.test(navn) && !/\.test\.tsx?$/.test(navn)) ut.push(sti)
  }
  return ut
}

const relativ = (sti: string) => sti.slice(SRC.length + 1).replace(/\\/g, '/')

const filer = kildefiler(SRC).filter((f) => !(relativ(f) in UNNTAK))
const naa = filer.reduce((sum, f) => sum + tellFarger(readFileSync(f, 'utf8')), 0)

const fasit: number = existsSync(FASIT)
  ? JSON.parse(readFileSync(FASIT, 'utf8')).hardkodetFarge
  : naa

/**
 * Den GAMLE merkevarefargen, som en hard port.
 *
 * Skrallen teller farger, men den skiller ikke paa hvilke - `rgba(37,
 * 99, 235, …)` stod i timesalgskartet som en av 261, og ingen saa hvilken
 * av dem det var. Den overlevde palettbyttet i trinn 01, og ble forst
 * synlig da bolge 2 seedet timesalg og axe kjorte paa et kart med data:
 * hvit tekst paa den halvgjennomsiktige blaafargen gir 2.6:1.
 *
 * Dette er ikke et tall som skal ned over tid. Det skal vaere null.
 */
const GAMMEL_PALETT: [RegExp, string][] = [
  [/#2563eb/i, 'gammel merkevarebla (hex)'],
  [/rgba?\(\s*37\s*,\s*99\s*,\s*235/i, 'gammel merkevarebla (rgb)'],
  [/#3b82f6/i, 'gammel lys bla'],
]

describe('den gamle paletten er borte', () => {
  test('ingen fil bruker fargene fra for merkevarebyttet', () => {
    const funn: string[] = []
    for (const f of filer) {
      // UTEN KOMMENTARER. Da denne porten ble skrevet, fant den to
      // treff - begge i kommentarer som FORKLARTE hvorfor den gamle
      // fargen var et problem. En vakt som gjor det dyrere aa forklare
      // enn aa slette i stillhet, laerer folk aa slette i stillhet.
      const kilde = utenKommentarer(readFileSync(f, 'utf8'))
      for (const [m, hva] of GAMMEL_PALETT) {
        if (m.test(kilde)) funn.push(`${relativ(f)}: ${hva}`)
      }
    }
    expect(
      funn,
      'Farger fra paletten som ble byttet ut i trinn 01. De ser nesten '
      + 'riktige ut, staar sjelden ved siden av en ny farge, og oppdages '
      + 'derfor forst naar noen maaler kontrast paa en side med data.',
    ).toEqual([])
  })
})

describe('fargevakten', () => {
  test('ingen nye hardkodede farger', () => {
    if (process.env.OPPDATER_FASIT) {
      writeFileSync(FASIT, `${JSON.stringify({ hardkodetFarge: naa }, null, 2)}\n`)
      return
    }
    expect(naa, [
      `Hardkodede farger har vokst: ${fasit} -> ${naa}.`,
      'Bruk var(--token). Mangler tokenet, legg det i :root og forklar hvorfor.',
      'Er det en ekte teknisk grunn, legg fila i UNNTAK i farger.ts med begrunnelse.',
    ].join('\n')).toBeLessThanOrEqual(fasit)
  })

  // Samme mekanikk som design-skrallen: naar tallet faller skal baseline
  // strammes, ellers kan det skli tilbake i stillhet.
  test('baseline er strammet naar tallet har falt', () => {
    if (process.env.OPPDATER_FASIT) return
    expect(naa, [
      `Farger har SUNKET: ${fasit} -> ${naa}. Bra.`,
      'Stram baseline: OPPDATER_FASIT=1 npx vitest run src/lib/redesign',
    ].join('\n')).toBeGreaterThanOrEqual(fasit)
  })
})

describe('maalingen virker', () => {
  test('teller alle fire skrivemaatene', () => {
    expect(tellFarger('a { color: #fff; }')).toBe(1)
    expect(tellFarger('a { color: #2e7d6b; }')).toBe(1)
    expect(tellFarger('a { color: rgb(1,2,3); }')).toBe(1)
    expect(tellFarger('a { box-shadow: 0 0 2px rgba(1,2,3,.4); }')).toBe(1)
    expect(tellFarger('a { color: hsl(1 2% 3%); }')).toBe(1)
    expect(tellFarger('a { color: hsla(1,2%,3%,.4); }')).toBe(1)
  })

  // Tokenlinja er stedet fargen SKAL staa. Talte vi den, ville vakten
  // straffe det eneste riktige stedet aa skrive en farge.
  test('teller ikke tokendefinisjoner', () => {
    expect(tellFarger('  --primaer: #2e7d6b;')).toBe(0)
    expect(tellFarger('  --skygge: 0 1px 2px rgba(15, 23, 32, 0.04);')).toBe(0)
  })

  test('teller ikke arvede verdier', () => {
    expect(tellFarger('a { stroke: currentColor; background: transparent; }')).toBe(0)
  })

  test('teller ikke farger nevnt i en kommentar', () => {
    expect(tellFarger('/* systemet var #2563eb for trinn 01 */')).toBe(0)
  })

  // KANARIFUGL. Slutter filsoeket aa finne noe - katalogen flyttes,
  // endelsene endres - blir summen 0, og 0 <= fasit passerer. Da ville
  // vakten vaert groenn mens den ikke maalte noe.
  test('leser faktisk kodebasen', () => {
    expect(filer.length).toBeGreaterThan(100)
    expect(naa).toBeGreaterThan(0)
  })

  test('unntakene finnes', () => {
    const alle = new Set(kildefiler(SRC).map(relativ))
    for (const f of Object.keys(UNNTAK)) expect(alle.has(f)).toBe(true)
  })
})

// =====================================================================
// Kontrastvakten.
//
// Paret er (tekstfarge, flate) slik primitivene faktisk setter dem.
// Lista er handholdt med vilje: en parser som skulle utlede kaskaden
// ville vaert et lite nettleser-prosjekt, og en vakt man ikke stoler
// paa er verre enn ingen. Hver linje navngir regelen den speiler, saa
// den kan etterprovees mot `globals.css`.
//
// Endrer noen en av reglene uten aa endre linja her, maaler vakten feil
// par - og det er det `parene finnes i css-en` under fanger.
// =====================================================================

const CSS = readFileSync(join(SRC, 'app', 'globals.css'), 'utf8')
const T = tokenverdier(CSS)

/** [tekst, flate, hvor det staar] */
const PAR: [string, string, string][] = [
  ['--tekst', '--kort', '.sq-signal / all brodtekst paa kort'],
  ['--tekst', '--bg', 'sida under kortene'],
  ['--tekst-svak', '--kort', '.undertittel, .sq-rad sekundaer'],
  ['--tekst-svak', '--bg', 'samme, utenfor et kort'],
  // De tre tonene. Det var her signalet stod med dempet tekst.
  ['--tekst', '--rod-svak', '.sq-signal-kritisk .sq-signal-tekst p'],
  ['--tekst', '--gul-svak', '.sq-signal-oppmerksomhet .sq-signal-tekst p'],
  ['--tekst', '--gronn-svak', '.sq-signal-mulighet .sq-signal-tekst p'],
  // Status paa flata den staar paa. Forsiden bruker alle tre nivaaene:
  // «Haster» paa en saksrad, «Litt bak» i budsjettabellen, ferskheten i
  // sidehodet. De sto ikke under vakt for bolge 4B.2.
  ['--rod', '--kort', '.sq-status-kritisk paa kort'],
  ['--rod', '--bg', '.sq-status-kritisk paa sida'],
  ['--gul', '--kort', '.sq-status-handling paa kort'],
  ['--gul', '--bg', '.sq-status-handling paa sida'],
  // Aksentfarge paa sin egen tone: statuspiller og merkelapper.
  ['--rod', '--rod-svak', '.status-pip.rod, .sq-nokkeltall-mot.darlig'],
  ['--gul', '--gul-svak', '.status-pip.gul'],
  ['--gronn', '--gronn-svak', '.status-pip.gronn, sidemenyens aktive lenke'],
]

describe('kontrastvakten', () => {
  test('tokenene er lesbare fra globals.css', () => {
    for (const [tekst, flate] of PAR) {
      expect(T[tekst], `${tekst} finnes ikke i :root`).toMatch(/^#[0-9a-f]{6}$/i)
      expect(T[flate], `${flate} finnes ikke i :root`).toMatch(/^#[0-9a-f]{6}$/i)
    }
  })

  test('all brodtekst naar 4.5:1', () => {
    const feil = PAR
      .map(([tekst, flate, hvor]) => [kontrast(T[tekst], T[flate]), tekst, flate, hvor] as const)
      .filter(([k]) => k < 4.5)
      .map(([k, tekst, flate, hvor]) => `${tekst} paa ${flate} = ${k.toFixed(2)}:1  (${hvor})`)
    expect(feil, [
      'Under WCAG AA for tekst. Enten er fargen feil, eller flata er feil.',
      'Dempet tekst paa en tone er den vanlige feilen: `--tekst-svak` bestaar',
      'bare paa hvitt, og bare saa vidt.',
    ].join('\n')).toEqual([])
  })

  // KANARIFUGL 1: maalingen selv. Returnerer `kontrast` plutselig 21 for
  // alt - feil parsing, feil formel - blir testen over gronn mens den
  // ikke maaler noe. Tallene er frosne literaler, ikke tokener, saa de
  // endrer seg ikke naar paletten gjor det.
  test('formelen regner riktig', () => {
    expect(kontrast('#ffffff', '#000000')).toBeCloseTo(21, 2)
    expect(kontrast('#ffffff', '#ffffff')).toBeCloseTo(1, 2)
    expect(kontrast('#64748b', '#ffffff')).toBeCloseTo(4.76, 1)
    // Paret som faktisk stod i signalet fram til bolge 4B.1.
    expect(kontrast('#64748b', '#fbe7e7')).toBeLessThan(4.5)
  })

  // KANARIFUGL 2: parene. Skrives en regel om - `.sq-signal-tekst p` fra
  // `--tekst` tilbake til noe dempet - skal vakten merke at lista ikke
  // lenger beskriver CSS-en, ikke fortsette aa maale et par som ingen
  // bruker.
  test('parene finnes i css-en', () => {
    expect(CSS).toMatch(/\.sq-signal-tekst p \{[^}]*color: var\(--tekst\)/)
    expect(CSS).toMatch(/\.sq-signal-kritisk \{[^}]*background: var\(--rod-svak\)/)
    expect(CSS).toMatch(/\.sq-signal-oppmerksomhet \{[^}]*background: var\(--gul-svak\)/)
    expect(CSS).toMatch(/\.sq-signal-mulighet \{[^}]*background: var\(--gronn-svak\)/)
    expect(CSS).toMatch(/\.sq-status-kritisk \{[^}]*color: var\(--rod\)/)
    expect(CSS).toMatch(/\.sq-status-handling \{[^}]*color: var\(--gul\)/)
  })
})
