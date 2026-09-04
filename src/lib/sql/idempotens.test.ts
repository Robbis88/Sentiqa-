import { describe, it, expect } from 'vitest'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// HELE SETTET SKAL TAALE AA KJOERES OM IGJEN.
//
// Migrasjonene kjoeres for haand i SQL Editor. Det finnes ingen
// historikk-tabell, saa `0001 →` kjoeres av og til om igjen fra bunn —
// og da mot en base som ALLEREDE har objektene.
//
// `create policy` har ingen `if not exists` i Postgres. Den feiler med
// 42710 «policy already exists», og kjoeringen stopper DER. Alt etter
// den migrasjonen blir ikke kjoert.
//
// 0107 og 0108 hadde 41 slike. De droppet det GAMLE policynavnet og
// laget nye navn — riktig for en fersk base, men en full re-kjoering
// stoppet paa dem. Ingen vakt saa det: `rls_vakthund.sql` leser
// KATALOGEN, altsaa hvordan basen ser ut naa, og kan per definisjon ikke
// se hva som skjer om filene kjoeres om igjen.
//
// Denne leser FILENE. Det er en annen sansing enn vakthunden, og det er
// hele poenget med at den finnes ved siden av.
// =====================================================================

const MAPPE = join(process.cwd(), 'supabase', 'migrations')
const FILER = readdirSync(MAPPE).filter((n) => n.endsWith('.sql')).sort()

/** Kommentarene bort foerst — ellers leser vakten sin egen prosa, og
    den feilen har skjedd fire ganger i dette prosjektet. */
const utenKommentarer = (s: string) =>
  s.split('\n').map((l) => l.replace(/--.*$/, '')).join('\n')

const sqlFor = (n: string) => utenKommentarer(readFileSync(join(MAPPE, n), 'utf8'))

describe('migrasjonene taaler en ny kjoering', () => {
  it('KANARIFUGL: vakten finner migrasjonene og policyene', () => {
    // Uten dette ville «ingen funn» ogsaa vaert svaret hvis mappa flyttet
    // eller regexen sluttet aa treffe.
    expect(FILER.length).toBeGreaterThan(100)
    const policyer = FILER.flatMap((n) => [...sqlFor(n).matchAll(/create\s+policy\s+([a-z_0-9]+)/gi)])
    expect(policyer.length).toBeGreaterThan(200)
  })

  it('hver `create policy` har en `drop policy if exists` foran seg', () => {
    const funn: string[] = []
    for (const n of FILER) {
      const sql = sqlFor(n)
      for (const m of sql.matchAll(/create\s+policy\s+([a-z_0-9]+)/gi)) {
        const navn = m[1]
        if (!new RegExp(`drop\\s+policy\\s+if\\s+exists\\s+${navn}\\b`, 'i').test(sql)) {
          funn.push(`${n}: ${navn}`)
        }
      }
    }
    expect(funn,
      'create policy har ingen `if not exists` i Postgres. Uten en drop foran '
      + 'feiler en ny kjoering med 42710, og alt etter den migrasjonen blir '
      + `staaende ukjort:\n  ${funn.join('\n  ')}`).toEqual([])
  })

  it('hver tabell opprettes med `if not exists`', () => {
    const funn: string[] = []
    for (const n of FILER) {
      for (const m of sqlFor(n).matchAll(/create\s+table\s+(?!if\s+not\s+exists)(?:public\.)?([a-z_0-9]+)/gi)) {
        funn.push(`${n}: ${m[1]}`)
      }
    }
    expect(funn, `create table uten if not exists:\n  ${funn.join('\n  ')}`).toEqual([])
  })

  it('hver view opprettes med `security_invoker`', () => {
    // Uten klausulen leser viewet som EIEREN, forbi RLS — og
    // `create or replace view` nullstiller flagget i stillhet.
    const funn: string[] = []
    for (const n of FILER) {
      for (const m of sqlFor(n).matchAll(/create\s+(?:or\s+replace\s+)?view\s+(?:public\.)?([a-z_0-9]+)([\s\S]{0,120})/gi)) {
        if (!/security_invoker/i.test(m[2])) funn.push(`${n}: ${m[1]}`)
      }
    }
    expect(funn, `view uten security_invoker:\n  ${funn.join('\n  ')}`).toEqual([])
  })
})
