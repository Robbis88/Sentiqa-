import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SKJUL_OMS_KODER, UTELAT_KODER } from '../avdelinger'

// =====================================================================
// Én sannhet, to språk.
//
// `SKJUL_OMS_KODER` i src/lib/avdelinger.ts er fasiten for hvilke koder
// som holdes utenfor omsetnings- og bruttoanalyser: drivstoff (10), pant
// (250) og regnskapets grand total (40).
//
// `v_bp_status_avdeling` må filtrere på nøyaktig det samme — men SQL kan
// ikke importere fra TypeScript, så lista står to steder.
//
// DET HAR GÅTT GALT FØR, PÅ NØYAKTIG DENNE MÅTEN. `rls_vakthund.sql` og
// `rls_funn.sql` bar hver sin kopi av de samme to listene, og 2026-08-19
// hadde de gått fra hverandre: vakthunden meldte ett funn, den lesbare
// utgaven seks — der tre var oppdiktede. Verktøyet man brukte for å SE
// funnene løy om tabeller som var i orden.
//
// `lister.test.ts` ble skrevet for å binde de to sammen. Denne gjør det
// samme for kodelista: endrer du den ene, må du endre den andre.
// =====================================================================

const MIGRASJON = join(
  process.cwd(), 'supabase', 'migrations', '0113_bp_status_avdeling.sql',
)

/** Kodene migrasjonen faktisk filtrerer på, lest ut av `not in (...)`. */
function koderIMigrasjonen(): string[][] {
  const sql = readFileSync(MIGRASJON, 'utf8')
    // Kommentarer ut: markørlinja `-- utelatte_koder := array[...]` er
    // dokumentasjon, ikke et filter. Teller vi den med, kan filteret
    // være tomt uten at testen merker det.
    .split('\n').map((l) => l.replace(/--.*$/, '')).join('\n')

  return [...sql.matchAll(/not\s+in\s*\(([^)]*)\)/g)]
    .map((m) => [...m[1].matchAll(/'([^']+)'/g)].map((k) => k[1]).sort())
}

describe('utelatte koder', () => {
  test('migrasjonen filtrerer paa de samme kodene som avdelinger.ts', () => {
    const fasit = [...SKJUL_OMS_KODER].sort()
    const funnet = koderIMigrasjonen()

    // KANARIFUGL. Finner uttrekket ingen filtre, er alle sammenligninger
    // under trivielt grønne — og da måler testen at ingenting er likt
    // ingenting. Det er slik en vakt slutter å se.
    expect(funnet.length, 'Fant ingen `not in (...)` i 0113 — leser testen riktig fil?')
      .toBeGreaterThan(0)

    for (const liste of funnet) {
      expect(liste, `Migrasjonen filtrerer paa ${liste.join(', ')}, `
        + `fasiten sier ${fasit.join(', ')}`).toEqual(fasit)
    }
  })

  test('pant og drivstoff er med i fasiten, og av samme grunn', () => {
    // Uten denne kunne noen fjerne 250 fra `UTELAT_KODER` og få alt
    // grønt: da ville begge sider vært enige om noe galt. En speiltest
    // beviser at to lister er like, aldri at de er riktige.
    expect(UTELAT_KODER.has('10'), 'drivstoff skal utelates').toBe(true)
    expect(UTELAT_KODER.has('250'), 'pant skal utelates').toBe(true)
    expect(SKJUL_OMS_KODER.has('40'), 'grand total skal utelates').toBe(true)
  })
})
