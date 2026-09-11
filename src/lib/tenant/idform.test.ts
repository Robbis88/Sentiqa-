import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// GENERATOREN ANTAR AT `id` ER EN UUID DEN KAN SETTE SELV
//
// `seedId()` lager en uuid, og proberaden setter `id = '<uuid>'`. Det
// står ingen steder som et krav — det står som en implementasjon, og en
// implementasjon er ikke noe man leser før man har brutt den.
//
// 2026-09-11 fikk `stotte_oppslag` en `bigint generated always as
// identity`, fordi det er en logg og det virket ryddig. Symptomet kom
// fire minutter senere, i nettleserjobben, og handlet ikke om sikkerhet
// i det hele tatt:
//
//   ERROR: invalid input syntax for type bigint: "43f6149a-0000-..."
//
// Det er formen AGENTS.md navngir under «Generatorantakelser skal testes
// direkte»: en FORMFEIL, ikke en autorisasjonsfeil. En autorisasjonsfeil
// gir 42501 og roper. En formfeil later som den er en avvisning, og
// koster en CI-runde per symptom.
//
// Denne testen beviser REGELEN i stedet for symptomet, og den kjører på
// millisekunder.
//
// ---------------------------------------------------------------------
// HVA DEN IKKE GJØR
//
// Den leser migrasjonstekst, ikke et skjema. En tabell som får en
// identity-kolonne på en måte denne ikke gjenkjenner, slipper forbi —
// og da er nettleserjobben fortsatt nettet under. Den flytter den
// vanlige feilen fra fire minutter til null, ikke alle tenkelige.
// =====================================================================

const MIGRASJONER = join(process.cwd(), 'supabase', 'migrations')
const KONTRAKT = JSON.parse(
  readFileSync(join(process.cwd(), 'supabase', 'tenant-kontrakt.json'), 'utf8'),
) as { ressurser: { tabell: string; id_kolonne?: string }[] }

const sql = readdirSync(MIGRASJONER)
  .filter((f) => f.endsWith('.sql'))
  .map((f) => readFileSync(join(MIGRASJONER, f), 'utf8'))
  .join('\n')

/**
 * Tabeller der en kolonne er erklært `generated ... as identity`.
 *
 * Leser fra `create table`-blokken og framover til den lukkende
 * parentesen på egen linje — det er formen alle migrasjonene her bruker.
 */
function medIdentity(): string[] {
  const ut: string[] = []
  const re = /create table if not exists public\.(\w+) \(([\s\S]*?)\n\);/g
  for (const m of sql.matchAll(re)) {
    if (/generated\s+(always|by default)\s+as\s+identity/i.test(m[2])) ut.push(m[1])
  }
  return [...new Set(ut)]
}

describe('KANARIFUGL', () => {
  it('måler faktisk migrasjonene', () => {
    // Uten denne ville en feil sti gitt tom streng, null funn og grønt.
    expect(sql.length, 'leste nesten ingen SQL').toBeGreaterThan(50_000)
    expect(sql).toContain('create table if not exists public.stotte_tilgang')
  })

  it('gjenkjenner en identity-kolonne når den ser en', () => {
    // Regelen skal bevises på et eksempel den SKAL felle, ellers måler
    // den ingenting den dagen ingen skriver en slik kolonne.
    const prove = 'create table if not exists public.x (\n  id bigint generated always as identity\n);'
    expect(/generated\s+(always|by default)\s+as\s+identity/i.test(prove)).toBe(true)
  })
})

/**
 * Er identity-kolonnen konvertert bort av en SENERE migrasjon?
 *
 * Den endelige formen er det som teller, ikke `create table`. 0196 er
 * kjoert mot produksjon og kan derfor ikke rettes - 0197 konverterer i
 * stedet, og da er tabellen i orden selv om opprettelsen ikke er det.
 *
 * Leses ut av SQL-en, ikke fra en unntaksliste: en liste ville staatt
 * igjen den dagen konverteringen ble fjernet, og sagt at alt er bra.
 */
function konvertertTilUuid(tabell: string): boolean {
  return new RegExp(
    `alter table public\\.${tabell}[\\s\\S]{0,200}?add column id uuid`, 'i',
  ).test(sql)
}

describe('tenant-kontraktens tabeller har en id generatoren kan sette', () => {
  it('KANARIFUGL: konverteringen i 0197 blir faktisk sett', () => {
    // Uten denne ville regelen under vaert groenn fordi den ikke finner
    // noe - ikke fordi formen er riktig.
    expect(medIdentity(), 'fant ingen identity-kolonne i det hele tatt')
      .toContain('stotte_oppslag')
    expect(konvertertTilUuid('stotte_oppslag'),
      '0197 konverterer ikke stotte_oppslag.id til uuid lenger').toBe(true)
    expect(konvertertTilUuid('daglig_salg'),
      'regelen paastaar en konvertering som ikke finnes').toBe(false)
  })

  it('ingen av dem ender opp med en identity-kolonne', () => {
    const iKontrakten = new Set(KONTRAKT.ressurser.map((r) => r.tabell))
    const funn = medIdentity()
      .filter((t) => iKontrakten.has(t))
      .filter((t) => !konvertertTilUuid(t))
    expect(funn,
      '\nDisse tabellene staar i tenant-kontrakten OG har en identity-kolonne:\n  '
      + funn.join('\n  ')
      + '\n\nGeneratoren seeder en uuid for `id` og setter den i proberaden '
      + '(`seedId()` i generer.ts). En identity-kolonne kan ikke settes, og '
      + 'atferdsmatrisen feiler med «invalid input syntax for type bigint».\n'
      + 'Bruk `uuid primary key default gen_random_uuid()`, eller pek '
      + 'generatoren et annet sted med `id_kolonne` i kontrakten.\n')
      .toEqual([])
  })
})
