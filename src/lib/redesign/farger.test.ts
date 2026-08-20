import { describe, expect, test } from 'vitest'
import { readFileSync, readdirSync, statSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { tellFarger, UNNTAK } from './farger'
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
