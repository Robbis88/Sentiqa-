import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// Token-fasiten: farger og luft endrer seg ikke i stillhet.
//
// Dette er den delen av «visuell regresjon» som betyr noe i dette
// repoet, og den koster ingenting.
//
// Chromatic tar skjermbilder og sammenligner dem. Verdien ligger i aa
// fange at CSS har endret seg saa hele appen forskyver seg. Men her
// finnes all den CSS-en i to filer, og de tretti tokenene under er
// stedet der en endring treffer ALT samtidig: flytter noen --luft-5,
// endrer hvert eneste mellomrom i systemet seg paa en gang.
//
// En fasit over tokenverdiene fanger nettopp det, deterministisk, uten
// nettleser og uten en betalt tjeneste. Det den IKKE fanger er at en
// enkelt komponent ser feil ut - der er skjermbilder fortsatt bedre.
// Avveiningen er bevisst: tretti tokens dekker det som treffer bredt,
// og designskrallen dekker at nye stiler ikke sniker seg inn i JSX.
//
// Endres en token med vilje:
//     OPPDATER_FASIT=1 npx vitest run src/lib/redesign
// Da viser git hvilken verdi som ble byttet, og til hva.
// =====================================================================

const ROT = process.cwd()
const CSS = join(ROT, 'src', 'app', 'globals.css')
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'tokenfasit.json')

/**
 * Leser `--navn: verdi;` fra rot-blokken.
 *
 * Bare den FORSTE definisjonen av hvert navn telles. Tokens redefineres
 * i media-blokker (moerk modus, sma skjermer), og de variantene er ment
 * aa vaere ulike - laaser vi dem alle, feiler testen hver gang noen
 * legger til et brekkpunkt.
 */
function tokens(css: string): Record<string, string> {
  const ut: Record<string, string> = {}
  for (const m of css.matchAll(/(?<![\w-])(--[a-z0-9-]+)\s*:\s*([^;]+);/g)) {
    const navn = m[1]
    if (!(navn in ut)) ut[navn] = m[2].replace(/\s+/g, ' ').trim()
  }
  return ut
}

const naa = tokens(readFileSync(CSS, 'utf8'))

describe('token-fasit', () => {
  test('lesingen finner tokenene', () => {
    // KANARIFUGL. Endrer noen formatet paa fila - eller flytter tokenene
    // til en annen fil - vil et tomt resultat se ut som «ingen endring».
    expect(Object.keys(naa).length, 'Fant nesten ingen tokens i globals.css.')
      .toBeGreaterThan(20)
    expect(naa['--luft-5'], '--luft-5 mangler; leser vi riktig fil?').toBeTruthy()
  })

  test('bare forste definisjon teller', () => {
    // Moerk modus redefinerer de samme navnene. Tas begge, feiler testen
    // hver gang noen legger til et brekkpunkt.
    const css = ':root { --a: 1px; }\n@media (x) { :root { --a: 2px; } }'
    expect(tokens(css)).toEqual({ '--a': '1px' })
  })

  test('var(--x) i en verdi forveksles ikke med en definisjon', () => {
    const css = ':root { --a: 1px; }\n.b { margin: var(--a); }'
    expect(Object.keys(tokens(css))).toEqual(['--a'])
  })

  test('ingen token har endret verdi', () => {
    if (process.env.OPPDATER_FASIT === '1' || !existsSync(FASIT)) {
      writeFileSync(FASIT, `${JSON.stringify(naa, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as Record<string, string>

    const endret = Object.entries(fasit)
      .filter(([k, v]) => k in naa && naa[k] !== v)
      .map(([k, v]) => `  ${k}: ${v}  ->  ${naa[k]}`)
    const borte = Object.keys(fasit).filter((k) => !(k in naa)).map((k) => `  ${k} er fjernet`)

    expect(
      [...endret, ...borte],
      'Designtokens er endret:\n' + [...endret, ...borte].join('\n')
      + '\n\nEn token treffer hele systemet samtidig. Er det meningen:'
      + '\n  OPPDATER_FASIT=1 npx vitest run src/lib/redesign',
    ).toEqual([])
  })
})
