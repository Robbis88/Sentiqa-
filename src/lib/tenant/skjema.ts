// =====================================================================
// Forretningsnøklene, lest ut av migrasjonene.
//
// `business_unik` i kontrakten er håndholdt, og jeg overså én: `ansatte`
// har TO unike indekser, ikke én. Den andre — `(retailer_id, pin_hash)`
// — felte matrisen i CI etter fire minutter, med 23505.
//
// Det er ikke en generatorantakelse; det er en kontraktdatafeil. Men
// den fortjener samme behandling: les skjemaet, og la en test si fra
// når en nøkkel mangler i kontrakten.
//
// LESER MIGRASJONENE, IKKE BASEN. Testen kjører i vitest uten database.
// Det er godt nok her: en unique-skranke oppstår i en migrasjon, og
// `rls_vakthund.sql` dekker katalogen i CI hvis de skulle skille lag.
// =====================================================================
import { readdirSync, readFileSync } from 'node:fs'

/** `unique (a, b)` inne i en `create table`. */
const I_TABELL = /create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z0-9_]+)\s*\(([\s\S]*?)\n\);/gi
const UNIQUE_LINJE = /^\s*unique\s*\(([^)]+)\)/gim

/** `create unique index ... on public.t (a, b)`. */
const INDEKS = /create\s+unique\s+index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?([a-z0-9_]+)\s+on\s+(?:public\.)?([a-z0-9_]+)\s*\(([^)]+)\)/gi
const DROPPET_INDEKS = /drop\s+index\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi
const DROPPET_TABELL = /drop\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi

export type Noekkel = { kolonner: string[]; navn?: string }

/**
 * Forretningsnøkler per tabell, i migrasjonsrekkefølge.
 *
 * Siste treff vinner, og en `drop` teller — samme regel som resten av
 * prosjektet leser migrasjoner etter.
 */
export function forretningsnokler(mappe: string): Record<string, Noekkel[]> {
  const ut: Record<string, Noekkel[]> = {}
  const indeksEier: Record<string, string> = {}

  for (const fil of readdirSync(mappe).filter((f) => f.endsWith('.sql')).sort()) {
    const sql = readFileSync(`${mappe}/${fil}`, 'utf8')

    for (const m of sql.matchAll(DROPPET_TABELL)) delete ut[m[1]]

    for (const m of sql.matchAll(DROPPET_INDEKS)) {
      const tabell = indeksEier[m[1]]
      if (tabell) ut[tabell] = (ut[tabell] ?? []).filter((n) => n.navn !== m[1])
    }

    for (const m of sql.matchAll(I_TABELL)) {
      const [, tabell, kropp] = m
      for (const u of kropp.matchAll(UNIQUE_LINJE)) {
        const kolonner = u[1].split(',').map((k) => k.trim())
        ;(ut[tabell] ??= []).push({ kolonner })
      }
    }

    for (const m of sql.matchAll(INDEKS)) {
      const [, navn, tabell, kolonner] = m
      indeksEier[navn] = tabell
      const liste = (ut[tabell] ??= [])
      if (!liste.some((n) => n.navn === navn)) {
        liste.push({ navn, kolonner: kolonner.split(',').map((k) => k.trim()) })
      }
    }
  }
  return ut
}
