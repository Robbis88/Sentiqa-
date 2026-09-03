import { describe, it, expect } from 'vitest'
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// EN CRON SOM PEKER FEIL SIER INGENTING.
//
// Vercel kaller stien i `vercel.json`. Finnes ruta ikke, svarer Next med
// 404 — og en 404 fra en cron ser ut akkurat som en cron som kjørte og
// ikke hadde noe å gjøre. Ingen logg roper, ingen bruker merker det, og
// det oppdages først når noen spør hvorfor et brev aldri kom.
//
// Den motsatte veien er like stille: en cron-rute som ingen plan
// utløser. Den bygger, den svarer på kall, den ser komplett ut — og
// kjører aldri. `/api/cron/ukebrief` var nettopp det, med vilje, fram til
// 2026-09-03.
//
// Begge retninger måles her.
// =====================================================================

const ROT = process.cwd()
const CRONMAPPE = join(ROT, 'src', 'app', 'api', 'cron')

type Cron = { path: string; schedule: string }
const planer: Cron[] = JSON.parse(readFileSync(join(ROT, 'vercel.json'), 'utf8')).crons ?? []

/**
 * Cron-ruter som med vilje IKKE står i `vercel.json`.
 *
 * Skal stå tom. En rute her må ha en skrevet grunn — «vi rakk det ikke»
 * er ikke en; da hører den hjemme i planen eller i papirkurven.
 */
const UTEN_PLAN: Record<string, string> = {}

function rutefil(sti: string): string {
  return join(ROT, 'src', 'app', ...sti.split('/').filter(Boolean), 'route.ts')
}

function cronruter(): string[] {
  const ut: string[] = []
  for (const n of readdirSync(CRONMAPPE)) {
    if (!statSync(join(CRONMAPPE, n)).isDirectory()) continue
    if (existsSync(join(CRONMAPPE, n, 'route.ts'))) ut.push(`/api/cron/${n}`)
  }
  return ut
}

describe('cron-stiene i vercel.json', () => {
  it('KANARIFUGL: vakten finner planene og rutene i det hele tatt', () => {
    // Uten dette ville «ingen avvik» også vært svaret hvis fila ikke ble
    // lest, eller mappa var tom — og en vakt som slutter å se ser ut som
    // en vakt som ikke finner noe.
    expect(planer.length).toBeGreaterThanOrEqual(4)
    expect(cronruter().length).toBeGreaterThanOrEqual(4)
    expect(planer.map((p) => p.path)).toContain('/api/cron/natt')
  })

  it('hver plan peker på en rute som finnes', () => {
    const doede = planer.filter((p) => !existsSync(rutefil(p.path))).map((p) => p.path)
    expect(doede, `plan uten rute (gir 404 i stillhet): ${doede.join(', ')}`).toEqual([])
  })

  it('hver cron-rute har en plan som utløser den', () => {
    const planlagte = new Set(planer.map((p) => p.path))
    const uten = cronruter().filter((r) => !planlagte.has(r) && !(r in UTEN_PLAN))
    expect(uten, `cron-rute som aldri kjører: ${uten.join(', ')}`).toEqual([])
  })

  it('hver plan har et gyldig uttrykk med fem felt', () => {
    for (const p of planer) {
      expect(p.schedule.trim().split(/\s+/), `${p.path} har ugyldig schedule «${p.schedule}»`)
        .toHaveLength(5)
    }
  })

  // Tidspunktet er ikke tilfeldig, og en endring av det skal være et valg.
  // Nattjobben (03:00 UTC) henter gårsdagens salgsfil og regner ukerapport;
  // kjørte briefen før den, ville søndagen manglet i hver eneste uke.
  it('ukebriefen går mandag, og etter nattjobben', () => {
    const brief = planer.find((p) => p.path === '/api/cron/ukebrief')
    expect(brief, 'ukebriefen har ingen plan').toBeDefined()
    const [, time, , , ukedag] = brief!.schedule.split(/\s+/)
    expect(ukedag, 'ukebriefen skal gå mandag (1)').toBe('1')
    const natt = planer.find((p) => p.path === '/api/cron/natt')!
    expect(Number(time), 'ukebriefen må gå etter nattjobben, ellers mangler søndagen')
      .toBeGreaterThan(Number(natt.schedule.split(/\s+/)[1]))
  })
})
