import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// INGENTING PÅ /lonnskost SAMMENLIGNER NI KONTI MED ET FEM-KONTO-ROM
//
// Siden er en serverkomponent og lar seg ikke kjøre i vitest. Den leses
// derfor som tekst — samme form som `bildevakt.test.ts` og
// `redesign/tilgang.test.ts`, der påstanden gjelder KODEN og ikke en
// kjøring.
//
// ---------------------------------------------------------------------
// HVORFOR DETTE TRENGER EN VAKT
//
// Trinn 2 rettet `styringsavvik` i `bilde.ts`. Men siden hadde FIRE
// steder til som sammenlignet lønn mot rommet, og ett av dem ble oversett
// i første runde: månedstabellens `avvikRom` og `radAndel`.
//
// Feilen slo begge veier:
//   avlagt måned   `lonnskostKr` er ni konti  → ser ut som overforbruk
//                  (Dale juli 2026: 35 330 kr som aldri var budsjettert)
//   åpen måned     `ea.lonnskostKr` mangler 501 helt → ser ut som MER
//                  rom enn det er. Den farlige retningen.
// =====================================================================

const SIDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'lonnskost', 'page.tsx'),
  'utf8',
)

/** Uten kommentarer — ellers felles vakten av sin egen begrunnelse. */
const KODE = SIDE
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .split('\n')
  .filter((l) => !l.trim().startsWith('//'))
  .join('\n')

describe('lønn mot rom måles på BP-nivå', () => {
  it('ingen linje trekker en ni-konto-sum fra romKr', () => {
    // `brukt` og `lonnskostKr` er hele lønnskosten og hører til
    // kolonnene som VISER den. Møter de `romKr`, er nivåene blandet.
    const linjer = KODE.split('\n')
      .filter((l) => /romKr/.test(l))
      .filter((l) => /\blonnskostKr\b|\bbrukt\b/.test(l))
    expect(linjer, `blandet nivå:\n${linjer.join('\n')}`).toEqual([])
  })

  it('andelen per rad regnes av styringskosten', () => {
    // `r.lonnsandel` er BP-lønn / BP-brutto, altså fem konti. Telleren
    // må være de samme fem, ellers er avviket epler mot pærer.
    expect(KODE).toContain('bruktStyring / r.bruttoKr')
    expect(KODE).not.toMatch(/radAndel\s*=[\s\S]{0,120}\bbrukt\s*\/\s*r\.bruttoKr/)
  })

  it('årsavviket regnes av styringskosten', () => {
    expect(KODE).toContain('aarstall.styringskostKr - aarstall.romKr')
    expect(KODE).not.toContain('aarstall.lonnskostKr - aarstall.romKr')
  })

  it('«igjen» regnes av styringskosten', () => {
    // Tallet butikksjefen leser som «dette har du igjen».
    expect(KODE).toContain('naa.romKr - naaStyring')
    expect(KODE).not.toContain('naa.romKr - naaBrukt')
  })

  it('KANARIFUGL: vakten leser faktisk en fil med innhold', () => {
    // En vakt som leser tom tekst finner aldri noe galt.
    expect(KODE.length).toBeGreaterThan(5000)
    expect(KODE).toContain('romKr')
    expect(KODE).toContain('lonnskostKr')
  })
})
