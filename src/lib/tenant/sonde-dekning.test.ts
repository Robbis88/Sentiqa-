import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
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

// =====================================================================
// DEN ANDRE LISTA I SAMME FIL VAR IKKE VOKTET
// =====================================================================
// Testen over binder `sonde.tabeller` til kontrakten, og den virker.
// `sonde.views` sto ved siden av, uvoktet.
//
// Migrasjonene definerer 35 `public.v_*`; sonden listet 26. Ni views var
// utenfor — blant dem `v_lonnsrom_grunnlag` og `v_retailer_kodestatus`.
// AGENTS.md sier hvorfor det betyr noe: Supabase-standarden gir `anon`
// grant på hvert NYTT view, og `anon` er rollen bak den offentlige
// nøkkelen i hver sidelast.
//
// Det er nøyaktig driftformen testens egen toppkommentar advarer mot,
// på den andre lista i den samme fila.
describe('sonden dekker viewene også', () => {
  const migrasjoner = () => {
    const mappe = join(process.cwd(), 'supabase', 'migrations')
    const funnet = new Set<string>()
    // `create or replace view public.v_x` — også de som redefineres
    // senere. Settet er «hvilke views finnes i dag», ikke «hvor mange
    // ganger ble de laget».
    for (const f of readdirSync(mappe).filter((n) => n.endsWith('.sql'))) {
      const sql = readFileSync(join(mappe, f), 'utf8')
      for (const m of sql.matchAll(/create\s+(?:or\s+replace\s+)?view\s+public\.(v_\w+)/gi)) {
        funnet.add(m[1])
      }
      // Et view som er droppet finnes ikke lenger.
      for (const m of sql.matchAll(/drop\s+view\s+(?:if\s+exists\s+)?public\.(v_\w+)/gi)) {
        funnet.delete(m[1])
      }
    }
    return funnet
  }

  it('KANARIFUGL: den finner faktisk views i migrasjonene', () => {
    // Slutter regexen å treffe, blir settet tomt — og «ingen mangler»
    // ville vært svaret uten at én eneste fil ble lest.
    expect(migrasjoner().size, 'fant ingen public.v_* i migrasjonene')
      .toBeGreaterThan(20)
    expect(Array.isArray(sonde.views) && sonde.views.length > 20).toBe(true)
  })

  it('hvert view i migrasjonene står i sondens målliste', () => {
    const iSonden = new Set<string>(sonde.views)
    const mangler = [...migrasjoner()].filter((v) => !iSonden.has(v)).sort()
    expect(mangler,
      'views sonden aldri spør om. Supabase gir `anon` grant på hvert nytt '
      + 'view, og anon er rollen bak den offentlige nøkkelen i hver sidelast — '
      + 'en lekkasje her ville aldri blitt sett:\n  ' + mangler.join('\n  '),
    ).toEqual([])
  })
})
