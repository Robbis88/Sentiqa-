import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// De to RLS-filene skal ha SAMME lister.
//
// `rls_vakthund.sql` er dommeren — den kaster exception og feller CI.
// `rls_funn.sql` er den man leser, fordi Supabase SQL Editor ikke viser
// `raise warning`. De har hver sin kopi av `varme` og `kalde`, fordi de
// er frittstående skript som limes inn, ikke moduler som kan importere.
//
// 2026-08-19 hadde de gått fra hverandre. Vakthunden meldte ÉTT funn;
// den lesbare utgaven viste seks, der tre var oppdiktede: den manglet
// `stempling_hendelse` og `personlig_punkt`, og hadde beholdt tre
// `opplaring_*`-navn som ikke finnes.
//
// DET ER VERRE ENN DET HORES UT. Verktøyet man bruker for å SE funnene
// løy om tabeller som var i orden. Da lærer man seg å avfeie rapporten —
// og neste gang den melder noe ekte, blir det avfeid det også.
//
// Denne testen er billig og deterministisk, og den gjør at listene bare
// finnes ett sted i praksis: endrer du den ene, må du endre den andre.
// =====================================================================

const rot = join(process.cwd(), 'supabase', 'tests')

/** Fjerner `--`-kommentarer. Uten dette teller navn nevnt i en forklaring. */
function utenKommentarer(sql: string): string {
  return sql.split('\n').map((l) => l.replace(/--.*$/, '')).join('\n')
}

/**
 * Navnene i array-et som følger etter `merke`.
 *
 * Leser fram til første `]`. Ingen av de to array-ene inneholder
 * nøstede klammer, så det holder — og skulle noen legge inn en, faller
 * uttrekket til for få navn og kanarifuglen nedenfor feller testen.
 */
function navnEtter(sql: string, merke: RegExp): string[] {
  const start = sql.search(merke)
  if (start === -1) return []
  const fra = sql.indexOf('array[', start)
  if (fra === -1) return []
  const til = sql.indexOf(']', fra)
  if (til === -1) return []
  return [...sql.slice(fra, til).matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort()
}

function lesVakthund() {
  const sql = utenKommentarer(readFileSync(join(rot, 'rls_vakthund.sql'), 'utf8'))
  return {
    varme: navnEtter(sql, /varme\s+text\[\]\s*:=/),
    kalde: navnEtter(sql, /kalde\s+text\[\]\s*:=/),
  }
}

function lesFunn() {
  const sql = utenKommentarer(readFileSync(join(rot, 'rls_funn.sql'), 'utf8'))
  // Her står navnet ETTER array-et (`array[...]::text[] as varme`), så
  // vi klipper fram til merket og leter bakover etter siste `array[`.
  const bit = (merke: RegExp) => {
    const slutt = sql.search(merke)
    if (slutt === -1) return []
    const fra = sql.lastIndexOf('array[', slutt)
    if (fra === -1) return []
    return [...sql.slice(fra, slutt).matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort()
  }
  return {
    varme: bit(/\]::text\[\]\s+as\s+varme/),
    kalde: bit(/\]::text\[\]\s+as\s+kalde/),
  }
}

describe('RLS-listene i de to filene', () => {
  const vakthund = lesVakthund()
  const funn = lesFunn()

  it('har samme varme tabeller', () => {
    expect(funn.varme).toEqual(vakthund.varme)
  })

  it('har samme kalde tabeller', () => {
    expect(funn.kalde).toEqual(vakthund.kalde)
  })

  it('lar ingen tabell stå i begge lister', () => {
    const begge = vakthund.varme.filter((t) => vakthund.kalde.includes(t))
    expect(begge).toEqual([])
  })

  // KANARIFUGL. Slutter uttrekket å finne noe — filene skrives om,
  // array-et skifter form, regexen slutter å treffe — blir de to
  // listene to tomme lister, og de er like. Da ville testen vært grønn
  // mens den ikke målte noe. Tallene er godt under dagens (55/24) og
  // skal ikke justeres for å få testen grønn; blir de for høye, er det
  // uttrekket som er i stykker.
  it('leser faktisk listene, og ikke tomme array', () => {
    expect(vakthund.varme.length).toBeGreaterThan(40)
    expect(vakthund.kalde.length).toBeGreaterThan(15)
    expect(funn.varme.length).toBeGreaterThan(40)
    expect(funn.kalde.length).toBeGreaterThan(15)
  })

  // Uttrekket skal LESE navn, ikke gjenkjenne dem. Tar det med noe fra
  // en kommentar, er filteret vart for bredt.
  it('plukker ikke opp navn nevnt i kommentarer', () => {
    expect(vakthund.varme).not.toContain('exchange_rates')
    expect(vakthund.kalde).not.toContain('opplaring_personer')
  })
})
