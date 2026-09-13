// Stasjonsfasiten skal ikke kunne byttes igjen — og ikke kopieres.
//
// =====================================================================
// HVORFOR DENNE FINNES
// =====================================================================
//
// Fire fiksturfiler bar hver sin håndskrevne kobling mellom butikknummer
// og navn. Alle fire sa 9145 = Dale og 9467 = Varden. Ingen test var
// rød: fiksturene er syntetiske, og parserne nøkler på nummeret.
//
// Kartet var likevel ikke uten kostnad. P2-rapporten slo opp der, byttet
// Varden og Bønes, og satsene fulgte med — Varden ble fortalt at den lå
// 7,19 prosentpoeng over kastbudsjettet da den lå 1,05 under.
//
// Vakten har to halvdeler: fasiten stemmer med kilden, og ingen lager en
// kopi av den.

import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { STASJONSFASIT, medPrefiks, navnFor, noekler, normaliser, normaliserTapt, sammeStasjon } from './stasjoner'

const MAPPE = join(process.cwd(), 'src/lib/parsere/fixtures')

describe('stasjonsfasiten', () => {
  // -------------------------------------------------------------------
  // 1) FASITEN SELV
  // -------------------------------------------------------------------
  it('er de fem parene fra arknavnene i kildefila', () => {
    expect(STASJONSFASIT.map(([nr, navn]) => `${nr} ${navn}`)).toEqual([
      '4177 Lone',
      '4185 Dale',
      '9038 Laguneparken',
      '9145 Varden',
      '9467 Bønes',
    ])
  })

  it('9145 er Varden og 9467 er Bønes — ikke omvendt', () => {
    expect(navnFor('9145')).toBe('Varden')
    expect(navnFor('9467')).toBe('Bønes')
    expect(navnFor('4185')).toBe('Dale')
    expect(navnFor('9038')).toBe('Laguneparken')
    expect(navnFor('4177')).toBe('Lone')
  })

  it('bærer prefikset slik arkene faktisk skriver det', () => {
    expect(medPrefiks(true)).toContainEqual(['9145', 'ST1 Varden'])
    expect(medPrefiks(false)).toContainEqual(['9467', 'St1 Bønes'])
  })

  it('et ukjent nummer kaster, det blir ikke undefined', () => {
    expect(() => navnFor('1234')).toThrow(/Ukjent butikknummer/)
  })

  // -------------------------------------------------------------------
  // 2) NORSK TEGNSETT
  //
  // `/Bones/i` matcher IKKE «Bønes». En kanarifugl skrevet slik ville
  // vært grønn fordi den aldri traff, ikke fordi den stemte — nøyaktig
  // formen på en vakt som slutter å se.
  // -------------------------------------------------------------------
  it('KANARI: en rå RegExp på «Bones» treffer ikke «Bønes»', () => {
    expect(new RegExp('Bones', 'i').test('Bønes')).toBe(false)
    expect(navnFor('9467')).toBe('Bønes')
  })

  it.each([
    ['Bønes'],
    ['Bones'],
    ['ST1 BØNES'],
    ['Shell Bønes'],
    ['St1 - Bønes'],
    ['BONES'],
    ['9467 ST1 Bønes'.replace('9467 ', '')],
  ])('%s kjennes igjen som Bønes', (skrivemaate) => {
    expect(sammeStasjon(skrivemaate, navnFor('9467'))).toBe(true)
  })

  it('folder æ, ø og å eksplisitt — ikke via NFD', () => {
    expect(normaliser('Bønes')).toBe('boenes')
    expect(normaliserTapt('Bønes')).toBe('bones')
    expect(normaliser('ST1 BØNES')).toBe('boenes')
    expect(normaliser('Shell Bønes')).toBe('boenes')
    // NFD ville gitt «bnes». Den er grunnen til at foldingen er skrevet
    // ut for hånd i stedet for å kalle normalize('NFD').
    expect('Bønes'.normalize('NFD').replace(/[^a-zA-Z]/g, '').toLowerCase()).toBe('bnes')
  })

  it('to foldinger, fordi én ikke rekker', () => {
    // `boenes` og `bones` er ulike, og ingen av dem er en delstreng av
    // den andre. Én folding alene ville sluppet gjennom den ene
    // skrivemåten. Derfor settet.
    expect(normaliser('Bønes')).not.toBe(normaliserTapt('Bønes'))
    expect(normaliser('Bønes').includes(normaliserTapt('Bønes'))).toBe(false)
    expect([...noekler('Bønes')].sort()).toEqual(['boenes', 'bones'])
  })

  it('normaliseringen slår ikke sammen to ulike stasjoner', () => {
    const navn = STASJONSFASIT.map(([, n]) => n)
    for (const a of navn) {
      for (const b of navn) {
        if (a === b) continue
        expect(sammeStasjon(a, b)).toBe(false)
      }
    }
  })

  it('visningsnavnet beholder ø — normalisering er kun for gjenkjenning', () => {
    expect(navnFor('9467')).toContain('ø')
    expect(navnFor('9467')).not.toBe(normaliser('Bønes'))
  })

  // -------------------------------------------------------------------
  // 3) INGEN NY KOPI
  //
  // Den halvdelen som hindrer at feilen kommer tilbake et femte sted.
  // -------------------------------------------------------------------
  it('ingen fiksturfil skriver sin egen nummer–navn-liste', () => {
    const numre = STASJONSFASIT.map(([nr]) => nr)
    const navn = ['Lone', 'Dale', 'Laguneparken', 'Varden', 'Bønes']
    const funn: string[] = []

    for (const fil of readdirSync(MAPPE)) {
      if (!fil.endsWith('.ts') || fil === 'stasjoner.ts' || fil.endsWith('.test.ts')) continue
      const linjer = readFileSync(join(MAPPE, fil), 'utf8')
        .split('\r\n').join('\n')
        .split('\n')
      linjer.forEach((l, i) => {
        if (l.trimStart().startsWith('//')) return
        // Et nummer og et stasjonsnavn på samme linje, uten at navnet
        // kommer fra `navnFor()` — da er det en håndskrevet kobling.
        // BARE STRENGLITERALER. Uten dette felte vakten
        // `const erLone = nr === '4177'` - en identifikator, ikke en
        // kobling, og en vakt som roper paa den blir slaatt av.
        const strenger = l.match(/(['"`])(?:(?!\1).)*\1/g) ?? []
        const harNummer = strenger.some((s) => numre.some((n) => s.includes(n)))
        const harNavn = strenger.some((s) => navn.some((n) => s.includes(n)))
        if (harNummer && harNavn && !l.includes('navnFor(')) {
          funn.push(`${fil}:${i + 1}  ${l.trim()}`)
        }
      })
    }
    expect(funn, `Håndskrevet nummer–navn-kobling. Bruk navnFor():\n${funn.join('\n')}`)
      .toEqual([])
  })

  it('KANARI: vakten over ser faktisk etter noe', () => {
    // Injiser en kobling og bevis at mønsteret felles. Uten denne kunne
    // regexen vært i stykker og lista tom av feil grunn.
    const numre = STASJONSFASIT.map(([nr]) => nr)
    const navn = ['Lone', 'Dale', 'Laguneparken', 'Varden', 'Bønes']
    const felles = (l: string) => {
      const strenger = l.match(/(['"`])(?:(?!\1).)*\1/g) ?? []
      return strenger.some((s) => numre.some((n) => s.includes(n)))
        && strenger.some((s) => navn.some((n) => s.includes(n)))
        && !l.includes('navnFor(')
    }
    // Injisert kobling: skal felles.
    expect(felles("  ['9145', 'St1 Dale'],")).toBe(true)
    // Identifikator med et stasjonsnavn i seg: skal IKKE felles.
    expect(felles("  const erLone = nr === '4177'")).toBe(false)
    // Riktig form: skal ikke felles.
    expect(felles("  [`Butikk: St1 ${navnFor('9145')}`, VARDEN],")).toBe(false)
  })
})
