import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// SONDEN MAA SE ALT KONTRAKTEN KJENNER.
//
// `postgrest_sonde.mjs` gaar den faktiske veien - HTTPS mot rest-
// endepunktet med anon-noekkelen, slik nettleseren gjoer. Den er det
// eneste som ser en lekkasje gjennom KLIENTFLATEN og ikke bare i
// katalogen.
//
// Men maallista er haandholdt, og 2026-09-04 hadde den drevet fra
// kontrakten med AATTE tabeller - blant dem `bp_aar`, `bp_linje` og
// `retailer_koderegel`. Sonden svarte «ingen funn» hele tiden, fordi den
// aldri spurte om dem.
//
// Det er samme form som hver eneste vakt som har vaert groenn mens den
// var blind: lista ser komplett ut, og et hull i den ser ut som ingen
// hull i det hele tatt.
// =====================================================================

const les = (...p: string[]) => JSON.parse(readFileSync(join(process.cwd(), ...p), 'utf8'))

const kontrakt = les('supabase', 'tenant-kontrakt.json')
const sonde = les('supabase', 'tests', 'sonde_maal.json')

describe('sonden dekker kontrakten', () => {
  it('KANARIFUGL: begge listene ble lest', () => {
    // Uten dette ville «ingen mangler» ogsaa vaert svaret hvis en av
    // filene var tom eller flyttet.
    expect(kontrakt.ressurser.length).toBeGreaterThan(50)
    expect(sonde.tabeller.length).toBeGreaterThan(50)
  })

  it('hver tabell i kontrakten staar i sondens maalliste', () => {
    const iSonden = new Set<string>(sonde.tabeller)
    const mangler = kontrakt.ressurser
      .map((r: { tabell: string }) => r.tabell)
      .filter((t: string) => !iSonden.has(t))
    expect(mangler,
      'tabeller sonden aldri spoer om - en lekkasje der ville aldri blitt sett: '
      + mangler.join(', ')).toEqual([])
  })
})
