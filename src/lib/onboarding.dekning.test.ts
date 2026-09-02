import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { KILDER, TYPE_TIL_KILDE } from './onboarding'
import { TIMESALG_AAR_TILBAKE, TIMESALG_ANBEFALTE_DAGER } from './historikk'

// =====================================================================
// ONBOARDINGLISTA SKAL IKKE VAERE EN ANNEN SANNHET ENN MODULENE
//
// Den var det. `KILDER` beskrev fem kilder, `v_datadekning` (0090) talte
// de samme fem - to haandholdte lister som maatte vaere enige, og de var
// enige, saa det saa riktig ut.
//
// Systemet tar imot AATTE rapporttyper. Tre sto ingen av stedene:
// kassererstatistikk (0018), varetransaksjoner (0452) og delingsfila.
// `onboardingsteg()` gaar over KILDER, saa en maaling uten oppfoering der
// kastes i stillhet. En ny retailer kunne se en komplett liste, laste opp
// alt den ba om, og sitte igjen med to tomme moduler.
//
// Og terskelen: lista lovet 365 dager timesalg mens bemanningen leste fra
// 1. januar TO AAR tilbake. Begge tallene var riktige da de ble skrevet.
// De sto bare hver for seg.
//
// DETTE ER SAMME FEILFORM SOM EN VAKT SOM SLUTTER AA SE: lista saa like
// ferdig ut dagen den ble feil. Derfor maales den mot fasiten - `Rapporttype`
// og lagringsarmene i `import/kjerne.ts` - i stedet for aa gjentas.
//
// AGENTS.md: «Onboarding skal ikke være en hardkodet sjekkliste ved siden
// av modulene. Da finnes det to sannheter ... og de skiller lag i stillhet.»
// =====================================================================

const ROT = process.cwd()
const les = (...deler: string[]) => readFileSync(join(ROT, ...deler), 'utf8')

/** Hver `Rapporttype` unntatt `ukjent` - fasiten for hva som kan lastes opp. */
function rapporttyper(): string[] {
  const kilde = les('src', 'lib', 'parsere', 'typer.ts')
  // \r\n: fila er CRLF paa Windows, og `\n\n` traff aldri. Foerste utgave
  // av denne vakten var derfor blind - den fant null typer og sammenlignet
  // to tomme lister. Kanarifuglen under fanget det paa foerste kjoering.
  const blokk = kilde.match(/export type Rapporttype =([\s\S]*?)\r?\n\r?\n/)
  expect(blokk, 'Fant ikke Rapporttype-unionen — da maaler denne fila ingenting').not.toBeNull()
  return [...blokk![1].matchAll(/'([a-z0-9_]+)'/g)]
    .map((m) => m[1])
    .filter((t) => t !== 'ukjent')
}

/** Kildenoeklene `v_datadekning` faktisk sender ut, fra siste migrasjon som definerer den. */
function datadekningKilder(): string[] {
  const mappe = join(ROT, 'supabase', 'migrations')
  const treff = readdirSync(mappe)
    .filter((f) => f.endsWith('.sql'))
    .sort()
    .filter((f) => /create or replace view\s+public\.v_datadekning/i
      .test(readFileSync(join(mappe, f), 'utf8')))
  expect(treff.length, 'Ingen migrasjon definerer v_datadekning').toBeGreaterThan(0)

  const sql = readFileSync(join(mappe, treff[treff.length - 1]), 'utf8')
  const kropp = sql.slice(sql.search(/create or replace view\s+public\.v_datadekning/i))
  // Foerste kolonne i hver arm: `select '<kilde>'::text as kilde` / `select '<kilde>',`
  return [...kropp.matchAll(/select\s+'([a-z0-9_]+)'(?:::text)?(?:\s+as\s+kilde)?\s*,/gi)]
    .map((m) => m[1])
}

describe('onboardinglista mot det systemet faktisk tar imot', () => {
  test('KANARIFUGL: fasiten lar seg lese', () => {
    // Slutter en av de tre parserne aa treffe, blir hver paastand under
    // en sammenligning mellom to tomme lister - og den er alltid sann.
    // Tallene er nedre grenser, ikke fasit: de skal kunne vokse.
    expect(rapporttyper().length, 'Fant ingen rapporttyper').toBeGreaterThanOrEqual(8)
    expect(datadekningKilder().length, 'Fant ingen kilder i v_datadekning').toBeGreaterThanOrEqual(7)
    expect(Object.keys(TYPE_TIL_KILDE).length).toBeGreaterThanOrEqual(8)
  })

  test('hver rapporttype som kan lastes opp har en lagringsarm', () => {
    // Uten dette kan en type staa i unionen uten aa bli lagret noe sted,
    // og feilen viser seg foerst naar noen faktisk laster opp fila.
    const kjerne = les('src', 'lib', 'import', 'kjerne.ts')
    const utenArm = rapporttyper().filter((t) => !kjerne.includes(`case '${t}':`))
    expect(utenArm, 'Rapporttyper uten lagringsarm i import/kjerne.ts').toEqual([])
  })

  test('hver rapporttype peker paa en kilde i KILDER', () => {
    // DETTE ER SELVE DRIFTEN. `onboardingsteg()` gaar over KILDER; en
    // type uten kobling hit blir usynlig i onboardingen uansett hvor godt
    // den er implementert ellers.
    const noekler = new Set(KILDER.map((k) => k.noekkel))
    const utenKilde = rapporttyper().filter((t) => !TYPE_TIL_KILDE[t])
    expect(utenKilde, 'Rapporttyper som ikke er ført inn i TYPE_TIL_KILDE').toEqual([])

    const ukjentMaal = Object.entries(TYPE_TIL_KILDE)
      .filter(([, k]) => !noekler.has(k))
      .map(([t, k]) => `${t} -> ${k}`)
    expect(ukjentMaal, 'TYPE_TIL_KILDE peker paa kilder som ikke finnes i KILDER').toEqual([])
  })

  test('hver kilde i KILDER kan faktisk maales', () => {
    // En kilde uten arm i `v_datadekning` staar «mangler» for alltid -
    // den ser ut som noe retaileren har glemt, uansett hva de laster opp.
    const talt = new Set(datadekningKilder())
    const umaalbare = KILDER.map((k) => k.noekkel).filter((n) => !talt.has(n))
    expect(umaalbare, 'Kilder i KILDER som v_datadekning ikke teller').toEqual([])
  })

  test('ingen kilde telles uten aa staa i lista', () => {
    // Motsatt vei: teller visningen noe KILDER ikke kjenner, kastes det i
    // stillhet av `onboardingsteg()`. Maalingen finnes, svaret naar ikke fram.
    const noekler = new Set(KILDER.map((k) => k.noekkel))
    const kastet = [...new Set(datadekningKilder())].filter((k) => !noekler.has(k))
    expect(kastet, 'v_datadekning teller kilder som onboardingsteg() kaster').toEqual([])
  })
})

describe('historikkvinduet er ett tall, ikke to', () => {
  test('timesalgterskelen foelger vinduet bemanningen leser', () => {
    const timesalg = KILDER.find((k) => k.noekkel === 'timesalg')
    expect(timesalg, 'Fant ikke timesalg i KILDER').toBeDefined()
    expect(timesalg!.anbefaltDager).toBe(TIMESALG_ANBEFALTE_DAGER)
    expect(
      timesalg!.anbefaltDager,
      `Lista lover mindre enn de ${TIMESALG_AAR_TILBAKE} aarene bemanningen leser`,
    ).toBeGreaterThanOrEqual(365 * TIMESALG_AAR_TILBAKE)
  })

  test('KANARIFUGL: bemanningen leser vinduet fra historikk.ts, ikke fra en literal', () => {
    // Hele feilen var to tall som sto hver for seg. Skrives `${ar - 2}`
    // inn igjen, er de to igjen - og testen over ville fortsatt vaert
    // groenn, fordi den bare sammenligner onboarding med seg selv.
    const side = les('src', 'app', '(beskyttet)', 'bemanning', 'page.tsx')
    expect(side, 'Bemanningen bruker ikke timesalgFra()').toContain('timesalgFra(ar)')
    expect(
      side.match(/\$\{ar - 2\}-01-01/g),
      'Vinduet er skrevet inn som literal igjen ved siden av historikk.ts',
    ).toBeNull()
  })
})
