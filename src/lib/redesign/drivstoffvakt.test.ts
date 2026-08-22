import { describe, expect, test } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// Ingen visning skal summere kroner med drivstoff i.
//
// AGENTS.md, siden april 2026: «alt som summerer kroner eller antall
// skal lese `v_butikksalg`.» Drivstoff er ~68 % av omsetningen, det
// betjener seg selv på pumpa, og det drukner alt annet på datoer der
// det er med.
//
// DA DET SIST VAR UFILTRERT ET STED, viste ukerapportens forside
// +216 % vekst som ikke fantes: årets uke MED drivstoff mot fjorårets
// UTEN. `0084`/`0085` ryddet opp — men `v_salg_per_stasjon_dag` fra
// `0004` kom aldri med, og den mater /salg, nettbrettets vekstkort,
// butikksjef-dashbordet og AI-verktøyet.
//
// Regelen fantes. Grep-en i AGENTS.md dekker `src/` — den ser ikke SQL.
// Dette er den samme regelen, håndhevet der hullet var.
//
// TO LOVLIGE MÅTER, og vakten godtar begge: lese `v_butikksalg`, eller
// filtrere drivstoff inline. `0084` gjorde det siste for tre visninger,
// og de er like riktige — å tvinge dem om ville vært å endre kode som
// virker for å tilfredsstille en vakt.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/** Den NYESTE definisjonen av hver visning. En eldre er overskrevet. */
function nyesteVisninger(): Map<string, { fil: string; kropp: string }> {
  const ut = new Map<string, { fil: string; kropp: string }>()
  for (const fil of readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()) {
    const sql = readFileSync(join(KATALOG, fil), 'utf8')
    for (const m of sql.matchAll(/create\s+(?:or\s+replace\s+)?view\s+public\.(\w+)([\s\S]*?);\s*$/gm)) {
      ut.set(m[1], { fil, kropp: m[2] })
    }
  }
  return ut
}

const summererPenger = (s: string) =>
  /sum\s*\(\s*(omsetning_eks_mva|antall|bto_fortjeneste_kr)/i.test(s)

const leserRaatabellen = (s: string) => /from\s+public\.daglig_salg/i.test(s)

/**
 * Drivstoff ute: enten via v_butikksalg, eller filtrert for hånd.
 *
 * `coalesce(avdeling_kode, '') <> '10'` MÅ TELLE. Første utgave krevde
 * `avdeling_kode <> '10'` uten innpakning, og meldte da tre visninger
 * fra 0084 som feil — de var riktige, vakten var for streng. En vakt
 * som melder falske funn på kode som virker, er den sikreste måten å
 * lære folk å ignorere den.
 *
 * BEGGE DELER KREVES: koden OG navnet. En ENERGI-rad med tom
 * avdelingskode slipper gjennom et filter som bare ser på koden.
 */
const utenDrivstoff = (s: string) => {
  if (/from\s+public\.v_butikksalg/i.test(s)) return true
  const koden = /avdeling_kode[^<>\n]*<>\s*'10'/i.test(s)
    || /avdeling_kode\s+not\s+in\s*\([^)]*'10'/i.test(s)
  return koden && /ENERGI/i.test(s)
}

describe('målingen forstår det den ser', () => {
  test('kjenner igjen en visning som summerer penger', () => {
    expect(summererPenger('sum(omsetning_eks_mva) as oms')).toBe(true)
    expect(summererPenger('sum( antall )')).toBe(true)
    // En visning som bare velger rader summerer ingenting.
    expect(summererPenger('select dato, avdeling_kode from x')).toBe(false)
  })

  test('kjenner igjen begge de lovlige måtene', () => {
    expect(utenDrivstoff('from public.v_butikksalg')).toBe(true)
    expect(utenDrivstoff("where avdeling_kode <> '10' and upper(avdeling_navn) <> 'ENERGI'"))
      .toBe(true)
    expect(utenDrivstoff(
      "where coalesce(avdeling_kode, '') <> '10' and upper(avdeling_navn) <> 'ENERGI'",
    ), 'coalesce-innpakningen skal telle').toBe(true)
    // KANARIFUGL: halv filtrering er ikke filtrering. Bare koden, uten
    // navnesjekken, slipper ENERGI-rader med tom kode gjennom.
    expect(utenDrivstoff("where avdeling_kode <> '10'")).toBe(false)
    expect(utenDrivstoff('from public.daglig_salg')).toBe(false)
  })

  test('den ser faktisk migrasjonene', () => {
    // Peker stien feil, blir kartet tomt og vakten grønn uten å ha lest
    // en eneste visning.
    const v = nyesteVisninger()
    expect(v.size, `fant nesten ingen visninger i ${KATALOG}`).toBeGreaterThan(15)
    expect(v.has('v_butikksalg'), 'v_butikksalg skal finnes').toBe(true)
    expect(v.has('v_salg_per_stasjon_dag')).toBe(true)
  })
})

describe('drivstoffvakten', () => {
  test('ingen visning summerer kroner med drivstoff i', () => {
    const funn: string[] = []
    for (const [navn, { fil, kropp }] of nyesteVisninger()) {
      // `v_butikksalg` ER filteret. Den må lese råtabellen.
      if (navn === 'v_butikksalg') continue
      if (summererPenger(kropp) && leserRaatabellen(kropp) && !utenDrivstoff(kropp)) {
        funn.push(`  ${navn}  (${fil})`)
      }
    }

    expect(funn, `\nDisse visningene summerer kroner rett fra daglig_salg, `
      + `altsaa MED drivstoff:\n${funn.join('\n')}\n\n`
      + 'Drivstoff er ~68 % av omsetningen og drukner alt annet. Les '
      + '`public.v_butikksalg` i stedet, eller filtrer bort avdeling 10 '
      + 'og ENERGI eksplisitt.\n')
      .toEqual([])
  })
})
