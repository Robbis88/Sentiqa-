import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// HALVE BYTTET ER VERRE ENN INGEN
//
// Nettbrettet er ikke egne komponenter — det er egne TOKENS. `.tablet`
// bytter `--bg`, `--kort`, `--tekst` og aksentene, og hele biblioteket
// følger med. Det er et godt system, og det er nettopp derfor det
// svikter stille når byttet er ufullstendig.
//
// `--rod` ble byttet til `--natt-rod` (#ffb3b3) med en skrevet
// begrunnelse: #9b2c2c gir 2,5:1 på nattbakgrunnen. Men `--rod-svak`
// sto igjen som #fbe7e7 — og de to brukes **sammen**: tinten er
// bakgrunnen, aksenten er teksten.
//
//     .sjekk-nei { background: var(--rod-svak); color: var(--rod); }
//
// På nettbrettet ble det #ffb3b3 på #fbe7e7. 1,5:1. Aksentbyttet gjorde
// knappen VERRE enn før: #9b2c2c på #fbe7e7 var i det minste lesbart.
//
// Det samme gjaldt `.puls-popp-kort`, som skrev `background: #fff` med
// `color: var(--tekst)` — 1,1:1 på nettbrettet. Spørsmålet fra pulsen
// sto der, usynlig, hver gang den slo til i butikken.
//
// ---------------------------------------------------------------------
// HVORFOR EN VAKT OG IKKE BARE EN RETTELSE
//
// `tilgjengelighet.test.ts` kjører axe i jsdom og **måler ikke
// kontrast** — det krever layout, altså en ekte nettleser. Det er også
// derfor dette sto i to versjoner uten at noe ble rødt.
//
// Denne måler ikke kontrast heller. Den måler PARET: har `.tablet` en
// egen verdi for aksenten, må den ha en for tinten som står under.
// Det er en strukturell regel, den er billig, og den fanger nøyaktig
// den formen feilen hadde.
// =====================================================================

const CSS = readFileSync(join(process.cwd(), 'src', 'app', 'globals.css'), 'utf8')

/** Tokennavnene som settes inne i én selektorblokk. */
function tokenerI(css: string, selektor: string): Set<string> {
  const start = css.indexOf(`${selektor} {`)
  if (start < 0) return new Set()
  const slutt = css.indexOf('\n}', start)
  const kropp = css.slice(start, slutt)
  return new Set([...kropp.matchAll(/(--[a-z0-9-]+)\s*:/g)].map((m) => m[1]))
}

const rot = tokenerI(CSS, ':root')
const tablet = tokenerI(CSS, '.tablet')

describe('målingen ser det den skal', () => {
  test('KANARIFUGL: begge blokkene ble faktisk lest', () => {
    // Bytter noen selektor eller filformat, blir begge settene tomme —
    // og «ingen token mangler sin tint» blir sant fordi ingen token
    // finnes. Det ser nøyaktig ut som en ren palett.
    expect(rot.size, 'fant nesten ingen tokens i :root').toBeGreaterThan(30)
    expect(tablet.size, 'fant nesten ingen tokens i .tablet').toBeGreaterThan(8)
    expect(tablet.has('--tekst'), '.tablet bytter ikke --tekst?').toBe(true)
    expect(rot.has('--rod-svak'), ':root har ingen --rod-svak?').toBe(true)
  })

  test('KANARIFUGL: regelen ville tatt den ekte feilen', () => {
    // Slik `.tablet` så ut da feilen sto der: aksenten byttet, tinten
    // ikke. Slutter regelen å felle dette, måler den ingenting.
    const fasit = ':root {\n  --rod: #9b2c2c;\n  --rod-svak: #fbe7e7;\n}\n'
      + '.tablet {\n  --rod: var(--natt-rod);\n}\n'
    const r = tokenerI(fasit, ':root')
    const t = tokenerI(fasit, '.tablet')
    const glemt = [...t].filter((n) => r.has(`${n}-svak`) && !t.has(`${n}-svak`))
    expect(glemt).toEqual(['--rod'])
  })
})

describe('nattpaletten er hel', () => {
  test('bytter .tablet en aksent, bytter den tinten under også', () => {
    const glemt = [...tablet]
      .filter((navn) => rot.has(`${navn}-svak`) && !tablet.has(`${navn}-svak`))
      .sort()

    expect(
      glemt,
      `\n.tablet gir disse egne nattverdier, men lar tinten deres stå i `
      + `dagpaletten:\n${glemt.map((n) => `  ${n}  (mangler ${n}-svak)`).join('\n')}\n\n`
      + 'Tinten er bakgrunnen og aksenten er teksten — de brukes sammen. '
      + 'Bytter du bare den ene, blir det lys tekst paa lys flate, og '
      + 'resultatet er DAARLIGERE enn foer byttet.\n',
    ).toEqual([])
  })

  test('ingen flate skriver sin egen hvite bakgrunn under var(--tekst)', () => {
    // Den eksakte formen `.puls-popp-kort` hadde: en litteral hvit
    // flate med en tekstfarge som følger temaet. Den kan bare være
    // riktig i ett av de to temaene.
    const syndere: string[] = []
    for (const m of CSS.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      const kropp = m[2]
      if (!/background(-color)?:\s*(#fff\b|#ffffff\b|white\b)/i.test(kropp)) continue
      if (!/color:\s*var\(--tekst\)/.test(kropp)) continue
      syndere.push(m[1].trim().split('\n').pop()!.trim())
    }
    expect(
      syndere,
      '\nDisse reglene laaser bakgrunnen til hvit og lar teksten foelge '
      + `temaet:\n${syndere.map((s) => `  ${s}`).join('\n')}\n\n`
      + 'Paa nettbrettet er var(--tekst) lys — det gir 1,1:1. Bruk '
      + 'var(--kort), som ER hvit paa dagpaletten.\n',
    ).toEqual([])
  })
})
