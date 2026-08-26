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
// KOLONNELISTA KAN INNEHOLDE PARENTESER. `[^)]+` stoppet ved den
// FOERSTE `)`, altsaa midt inne i `coalesce(...)` - og siste kolonne i
// `signal_lukket_unik` forsvant i stillhet. En noekkelkolonne som blir
// borte, gjor at vakten slutter aa kreve at kontrakten kjenner den.
const INDEKS = /create\s+unique\s+index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?([a-z0-9_]+)\s+on\s+(?:public\.)?([a-z0-9_]+)\s*\(([\s\S]*?)\)\s*(?:where|;)/gi
const DROPPET_INDEKS = /drop\s+index\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi
const DROPPET_TABELL = /drop\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi

/**
 * `alter table t drop column c`.
 *
 * EN DROPPET KOLONNE TAR MED SEG NØKLENE SINE. Postgres dropper hver
 * indeks kolonnen inngår i — uten et `drop index` å lese noe sted.
 *
 * `puls_svar_ansatt_dag (ansatt_id, dato)` ble laget i `0026` og
 * forsvant i `0044`, da `dato` ble droppet. En parser som bare leser
 * `drop index` krever da at kontrakten oppgir en forretningsnøkkel over
 * en kolonne som ikke finnes — og den eneste måten å bli grønn på ville
 * vært å lyve i kontrakten.
 */
const DROPPET_KOLONNE =
  /alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)\s+drop\s+column\s+(?:if\s+exists\s+)?([a-z0-9_]+)/gi

export type Noekkel = { kolonner: string[]; navn?: string }

/**
 * Kolonnenavnene i en indeksdefinisjon — og bare dem.
 *
 * ET UTTRYKK ER IKKE EN KOLONNE. `signal_lukket_unik` er
 *
 *   (retailer_id, coalesce(stasjon_id, '000…'::uuid), signal_id)
 *
 * fordi null-stasjonen ellers ville gjort nøkkelen flertydig. Et naivt
 * `split(',')` deler midt inne i `coalesce(...)` og forlanger så at
 * kontrakten oppgir «coalesce(stasjon_id» som forretningsnøkkel — en
 * kolonne som ikke finnes, og som ingen fixture kan variere.
 *
 * Vi deler derfor på komma PÅ DYBDE 0 og beholder de delene som er rene
 * identifikatorer. Uttrykket faller ut: det er utledet av kolonner som
 * allerede står der, og fixturen kan ikke sette det direkte uansett.
 */
function kolonnenavn(liste: string[] | string): string[] {
  const tekst = Array.isArray(liste) ? liste.join(',') : liste
  const deler: string[] = []
  let dybde = 0
  let denne = ''
  for (const ch of tekst) {
    if (ch === '(') dybde++
    if (ch === ')') dybde--
    if (ch === ',' && dybde === 0) { deler.push(denne); denne = ''; continue }
    denne += ch
  }
  deler.push(denne)
  return deler.map((d) => d.trim()).filter((d) => /^[a-z_][a-z0-9_]*$/.test(d))
}

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

    for (const m of sql.matchAll(DROPPET_KOLONNE)) {
      const [, tabell, kolonne] = m
      ut[tabell] = (ut[tabell] ?? []).filter((n) => !n.kolonner.includes(kolonne))
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
        liste.push({ navn, kolonner: kolonnenavn(kolonner) })
      }
    }
  }
  return ut
}
