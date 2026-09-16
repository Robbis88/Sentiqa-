import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// LAYOUTEN SKAL IKKE FALLE TILBAKE TIL EN FOSS
// =====================================================================
//
// Målt på nettbrettets landingsside før rettelsen: fire nettverks-
// rundturer på rad i denne layouten, 452–552 ms, der det tregeste
// enkeltleddet var 140–179 ms. Rundt 312–372 ms var ren venting — hver
// eneste render, og nettbrettet rendrer på nytt hvert 30. sekund.
//
// Rettelsen er å kjøre de uavhengige leddene samtidig. Denne vakten
// hindrer at de skiller lag igjen, for det ville ikke gitt noen feil —
// bare en side som ble langsommere uten at noe ble rødt.
//
// ---------------------------------------------------------------------
// HVA SOM MED VILJE IKKE ER PARALLELLISERT
// ---------------------------------------------------------------------
//
// `hentInnloggetBruker` står foran alt: rollen avgjør både MFA-porten
// og hvilke ledd som skal kjøre. `mfaHandling` står også foran, fordi
// den ender i en `redirect` — en bruker som skal tvinges til steg-opp
// skal ikke utløse spørringer på veien ut.
//
// Vakten krever derfor BÅDE at de fire kjøres samtidig OG at de to
// over fortsatt står foran.
// =====================================================================

const kilde = () =>
  readFileSync(join(process.cwd(), 'src', 'app', '(beskyttet)', 'layout.tsx'), 'utf8')

/** Kommentarene bort — en vakt som leser sin egen prosa står grønn. */
const kode = () => kilde().split('\n').map((l) => l.replace(/\/\/.*$/, '')).join('\n')

describe('layouten kjører de uavhengige leddene samtidig', () => {
  it('varseltellingen og stasjonskonteksten står i SAMME Promise.all', () => {
    const k = kode()
    const i = k.indexOf('Promise.all([')
    expect(i, 'ingen Promise.all i layouten').toBeGreaterThan(0)
    const blokk = k.slice(i, k.indexOf('])', i))
    expect(blokk).toContain("from('varsler')")
    expect(blokk).toContain('stasjonskontekst(')
  })

  it('nettbrettets to ekstra ledd er med i samme blokk', () => {
    const k = kode()
    const i = k.indexOf('Promise.all([')
    const blokk = k.slice(i, k.indexOf('])', i))
    expect(blokk).toContain('lesAktivAnsatt(')
    expect(blokk).toContain('oversettTabletOrd')
  })

  it('ingen av de fire hentes med sitt eget `await` utenfor blokka', () => {
    const k = kode()
    // Et gjenoppstaatt `const x = await supabase.from('varsler')` ville
    // vaert fossen tilbake, uten at noe annet ble roedt.
    expect(k).not.toMatch(/await\s+supabase\s*\n?\s*\.from\('varsler'\)/)
    expect(k).not.toMatch(/=\s*await\s+stasjonskontekst\(/)
    expect(k).not.toMatch(/=\s*await\s+lesAktivAnsatt\(/)
    expect(k).not.toMatch(/=\s*await\s+oversettTabletOrd\(/)
  })

  it('brukeren og MFA-porten står fortsatt FORAN blokka', () => {
    const k = kode()
    const bruker = k.indexOf('await hentInnloggetBruker()')
    const mfa = k.indexOf('await mfaHandling(')
    const blokk = k.indexOf('Promise.all([')
    expect(bruker, 'hentInnloggetBruker mangler').toBeGreaterThan(0)
    expect(mfa, 'mfaHandling mangler').toBeGreaterThan(0)
    expect(bruker, 'brukeren maa hentes foer den parallelle blokka').toBeLessThan(blokk)
    expect(mfa, 'MFA-porten maa staa foer den parallelle blokka').toBeLessThan(blokk)
  })

  it('MFA-redirectene er uendret', () => {
    const k = kode()
    expect(k).toContain("redirect('/logg-inn/totp')")
    expect(k).toContain("redirect('/sikkerhet?paakrevd=1')")
    // Nettbrettet er fortsatt unntatt porten.
    expect(k).toContain("bruker.rolle !== 'butikkbruker_tablet'")
  })

  it('nettbrettet får fortsatt sitt eget skall, aldri admin-skallet', () => {
    const k = kode()
    // ANKRET PAA HELE TAGGEN, ikke paa prefikset. `<TabletSkall` alene
    // matchet ogsaa `<TabletSkallX`, saa en injeksjon som byttet ut
    // komponenten kom groenn tilbake.
    const start = k.indexOf('if (erTablet) {')
    expect(start, 'nettbrettgrenen mangler').toBeGreaterThan(0)
    const gren = k.slice(start, k.indexOf('\n  }', start))
    expect(gren).toMatch(/<TabletSkall[\s>]/)
    expect(gren, 'nettbrettet skal ALDRI faa admin-skallet').not.toContain('<Appskall')
    // Og admin-skallet skal fortsatt finnes, etter grenen.
    expect(k.indexOf('<Appskall')).toBeGreaterThan(start)
  })
})
