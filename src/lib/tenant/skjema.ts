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

/**
 * Operasjoner `authenticated` IKKE har rettighet til, per tabell.
 *
 * EN POLICY UTEN GRANT ER VIRKNINGSLOES — og kontrakten beskrev
 * policyen. `profiler_admin_alt` står fortsatt i basen og ser ut som om
 * eieren kan skrive; `0078` tok grantet i stedet:
 *
 *   revoke insert, update, delete on public.profiler from authenticated;
 *
 * Privilegie-eskaleringen (`PATCH /rest/v1/profiler {"rolle":…}`) ble
 * stengt med en RETTIGHET, ikke med et predikat. Klassifiserte jeg
 * eieren som skrivende, ga matrisen 42501 fra grantet i stedet for det
 * tillatte skrivet den ventet — og etterpå kolliderte gjeninnsettingen
 * med raden som aldri ble slettet.
 *
 * KOLONNEGRANT TELLER SOM GJENOPPRETTING. `0112` tar `select` fra
 * `ansatte` og gir den tilbake kolonne for kolonne; da er operasjonen
 * fortsatt mulig, og dette skal ikke slå ut.
 */
export type Rettighetsop = 'select' | 'insert' | 'update' | 'delete'

const ALLE_OPS: Rettighetsop[] = ['select', 'insert', 'update', 'delete']

const REVOKE = /revoke\s+([a-z, ]+?)\s*(?:\([^)]*\))?\s+on\s+(?:table\s+)?(?:public\.)?([a-z0-9_]+)\s+from\s+([^;')]+)/gi
const GRANT = /grant\s+([a-z, ]+?)\s*(?:\([^)]*\))?\s+on\s+(?:table\s+)?(?:public\.)?([a-z0-9_]+)\s+to\s+([^;')]+)/gi

function ops(tekst: string): Rettighetsop[] {
  const t = tekst.trim().toLowerCase()
  if (t === 'all' || t.startsWith('all ')) return [...ALLE_OPS]
  return t.split(',').map((x) => x.trim()).filter((x): x is Rettighetsop =>
    (ALLE_OPS as string[]).includes(x))
}

/**
 * SQL uten kommentarer.
 *
 * `0138` SITERER `0112` I EN KOMMENTAR:
 *
 *   -- `0112` skrev, for aa lukke pin_hash:
 *   --   revoke update on public.ansatte from authenticated;
 *
 * Uten dette leste vakten sitatet som en setning, og konkluderte med at
 * `ansatte` fortsatt manglet update-retten — lenge etter at `0112` ga
 * den tilbake kolonne for kolonne. En kommentar som forklarer historien
 * ble altså lest som historien selv.
 */
function utenKommentarer(sql: string): string {
  return sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*/g, '')
}

export function fratattAuthenticated(mappe: string): Record<string, Set<Rettighetsop>> {
  const ut: Record<string, Set<Rettighetsop>> = {}
  for (const fil of readdirSync(mappe).filter((f) => f.endsWith('.sql')).sort()) {
    const sql = utenKommentarer(readFileSync(`${mappe}/${fil}`, 'utf8'))
    // Rekkefolgen INNE i en fil teller ogsaa: 0112 tar select og gir den
    // tilbake kolonnevis i samme fil.
    const hendelser: Array<[number, 'revoke' | 'grant', string, string, string]> = []
    for (const m of sql.matchAll(REVOKE)) hendelser.push([m.index!, 'revoke', m[1], m[2], m[3]])
    for (const m of sql.matchAll(GRANT)) hendelser.push([m.index!, 'grant', m[1], m[2], m[3]])
    hendelser.sort((a, b) => a[0] - b[0])
    for (const [, typ, opTekst, tabell, mottakere] of hendelser) {
      // `revoke all on FUNCTION ...` fanges ikke: regexen krever et
      // tabellnavn rett etter `on`, og «function» er ikke et tabellnavn
      // vi noen gang klassifiserer.
      if (tabell === 'function' || tabell === 'schema' || tabell === 'sequence') continue
      if (!/(^|[\s,])authenticated([\s,]|$)/.test(mottakere)) continue
      const sett = (ut[tabell] ??= new Set())
      for (const op of ops(opTekst)) {
        if (typ === 'revoke') sett.add(op)
        else sett.delete(op)
      }
    }
  }
  for (const t of Object.keys(ut)) if (ut[t].size === 0) delete ut[t]
  return ut
}
