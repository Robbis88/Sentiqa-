import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// Vakthund mot en feil ingen av verktøyene ser
//
// «use client» er en GRENSE, ikke et hint. Leser en serverkomponent en
// verdi fra en klientfil, får den ikke verdien — den får en
// klientreferanse. Et `.some()` på en klientreferanse kaster under
// render, og siden blir hvit.
//
// Det spesielle er at ingenting fanger det underveis: `tsc` ser en
// array og er fornøyd, `eslint` sier ingenting, og `next build` bygger
// fint. Feilen viser seg først når noen åpner siden i drift. Det er
// nøyaktig det som skjedde med /kontrakt — FORMER og ROLLER lå i
// skjemafila, og siden var død fra første klikk.
//
// Regelen her er en tommelfingerregel, ikke en typesjekk: en klientfil
// skal eksportere KOMPONENTER (PascalCase). Eksporterer den data, hører
// dataene hjemme i en vanlig modul begge sider kan importere.
//
// Typer er unntatt — de finnes ikke etter kompilering og krysser derfor
// ingen grense.
// =====================================================================

const ROT = join(process.cwd(), 'src', 'app')

function alleFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...alleFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !rad.name.includes('.test.')) ut.push(sti)
  }
  return ut
}

const forsteLinje = (kilde: string) => kilde.split('\n').find((l) => l.trim() !== '') ?? ''
const erKlientfil = (kilde: string) => /^\s*(['"])use client\1/.test(forsteLinje(kilde))
const erServerfil = (kilde: string) => /^\s*(['"])use server\1/.test(forsteLinje(kilde))

/**
 * Eksporterte DATAVERDIER — det er bare de som er farlige.
 *
 * Skillet går ikke på navnet. `FORMER` og `MalSkjema` ser like ut for en
 * PascalCase-test, og en slik regel ville sluppet nettopp den feilen som
 * drepte siden. Det som skiller dem er høyresiden: en komponent er en
 * funksjon, data er en literal.
 *
 * Derfor flagges bare `export const X =` der verdien begynner som en
 * array, et objekt, en streng, et tall eller et `new`. Funksjoner og
 * pilfunksjoner — komponenter, hooks, hjelpere — går fri.
 *
 * `export type` og `export interface` treffes ikke: de finnes ikke etter
 * kompilering og krysser derfor ingen grense.
 */
function dataeksporter(kilde: string): string[] {
  const ut: string[] = []
  const re = /^export\s+const\s+(\w+)\s*(?::[^=]+?)?=\s*(.)/gm
  for (const m of kilde.matchAll(re)) {
    if (/[[{'"`0-9]/.test(m[2])) ut.push(m[1])
  }
  for (const m of kilde.matchAll(/^export\s+const\s+(\w+)\s*(?::[^=]+?)?=\s*new\s/gm)) {
    ut.push(m[1])
  }
  return ut
}

describe('klientgrensen', () => {
  test('klientfiler eksporterer komponenter og hooks, ikke data', () => {
    const syndere: string[] = []
    for (const fil of alleFiler(ROT)) {
      const kilde = readFileSync(fil, 'utf8')
      if (!erKlientfil(kilde)) continue
      for (const navn of dataeksporter(kilde)) {
        syndere.push(`${fil.replace(process.cwd(), '.')} eksporterer «${navn}»`)
      }
    }
    expect(
      syndere,
      'Data som eksporteres fra en «use client»-fil blir en klientreferanse når '
      + 'en serverkomponent leser den, og kaster under render. Flytt verdien til '
      + 'en vanlig modul (f.eks. under src/lib) som begge sider kan importere.',
    ).toEqual([])
  })

  test('serverfiler eksporterer bare async funksjoner', () => {
    // Speilbildet av regelen over, og like usynlig i editoren. En
    // «use server»-fil gjor HVER eksport til et handlingsendepunkt —
    // eksporterer du en konstant, brekker bygget med «Ecmascript file had
    // an error» og en importsporing som peker et helt annet sted.
    //
    // Det skjedde: STASJONSKAPSEL laa i stasjon-handlinger.ts.
    const syndere: string[] = []
    for (const fil of alleFiler(ROT)) {
      const kilde = readFileSync(fil, 'utf8')
      if (!erServerfil(kilde)) continue
      for (const m of kilde.matchAll(/^export\s+(?!async\s+function)(\w+)/gm)) {
        // `export type` og `export interface` forsvinner ved kompilering
        // og krysser ingen grense.
        if (m[1] === 'type' || m[1] === 'interface') continue
        syndere.push(`${fil.replace(process.cwd(), '.')} eksporterer «${m[1]} …»`)
      }
    }
    expect(
      syndere,
      'En «use server»-fil kan bare eksportere async funksjoner. Flytt '
      + 'konstanter og typer til en vanlig modul.',
    ).toEqual([])
  })

  test('vakthunden finner faktisk klientfiler — ellers er den grønn av feil grunn', () => {
    const klientfiler = alleFiler(ROT).filter((f) => erKlientfil(readFileSync(f, 'utf8')))
    expect(klientfiler.length).toBeGreaterThan(5)
  })

  test('den bjeffer på nettopp det mønsteret som drepte /kontrakt', () => {
    const kilde = [
      "'use client'",
      "export const FORMER = [{ verdi: 'fast' }]",
      'export const LONNSFORM_NAVN: Record<string, string> = { a: 1 }',
      'export function MalSkjema() { return null }',
      'export const Knapp = ({ x }: P) => null',
      'export const brukTid = () => 1',
      'export type Ansattkort = { navn: string }',
    ].join('\n')

    expect(erKlientfil(kilde)).toBe(true)
    // Bare de to literalene. Komponenten, pilfunksjonene og typen går fri —
    // og at FORMER tas er hele poenget: en PascalCase-regel hadde sluppet
    // den, fordi «FORMER» ser like mye ut som en komponent som «MalSkjema».
    expect(dataeksporter(kilde)).toEqual(['FORMER', 'LONNSFORM_NAVN'])
  })
})
