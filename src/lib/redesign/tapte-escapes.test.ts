import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// ET REGEXLITERAL SOM MISTET BAKSTREKENE SINE
//
// `src/app/(beskyttet)/bemanning/handlinger.ts` sto med
//
//     /^d{4}-d{2}-d{2}$/
//
// Uten bakstrek betyr `d` bokstaven d, så mønsteret krevde den
// litterale strengen `dddd-dd-dd`. Ingen dato kunne matche det.
//
// Følgen var to tap. `gjelder_fra` ble alltid 2020-01-01 og
// `gjelder_til` alltid tom, uansett hva som ble tastet inn — og
// lukkingen av forrige periode, som filtrerer på `gjelder_fra`, kunne
// derfor aldri treffe noe. Da står to gyldige faste vakter samtidig, og
// dekningen telles dobbelt.
//
// ---------------------------------------------------------------------
// HVORFOR EN VAKT OG IKKE BARE EN RETTELSE
//
// Feilen er usynlig i lesing: `/^d{4}/` og `/^\d{4}/` ser like ut i en
// diff, og begge er gyldig JavaScript. Den samme tapte escapen står
// allerede i notatene som `bash-heredoc-escapes`, fra en helt annen
// kant av verktøykassa. Det er en form, ikke et uhell.
//
// Denne leter etter regexliteraler der en klasse som `\d`, `\w`, `\s`
// eller `\b` er skrevet uten bakstrek på et sted der den bare kan ha
// vært ment som klassen: rett foran en kvantifikator, `{n}` eller `{n,m}`.
// `d{4}` er ikke noe man skriver med vilje.
// =====================================================================

const ROT = process.cwd()

function tsFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !/\.test\.tsx?$/.test(rad.name)) ut.push(sti)
  }
  return ut
}

/**
 * Regexliteraler med en klasse som mangler bakstreken sin.
 *
 * Leter bare INNE i `/…/`-literaler, ikke i vanlige strenger — en
 * streng som inneholder «d{4}» kan være hva som helst.
 */
export function tapteEscapes(kilde: string): string[] {
  const ut: string[] = []
  // KANARIFUGL FOR MAALINGEN SELV. Denne fila - og rettelsen i
  // `bemanning/handlinger.ts` - forklarer feilen ved aa SITERE det gale
  // moensteret. Leses kommentarer, maaler vakten seg selv, og hver
  // dokumentasjon av en rettet feil blir et nytt funn.
  // Samme grep som `skrivevakt.ts` har for `await ...insert(...)`.
  kilde = utenKommentarer(kilde)
  // Et regexliteral: `/…/` med flagg, som ikke er en kommentar eller
  // en divisjon. Grovt, men godt nok: vi krever `^` eller `$` inni, som
  // er der denne feilklassen bor (validering av hele feltet).
  for (const m of kilde.matchAll(/\/\^?[^/\n\\]*(?:\\.[^/\n\\]*)*\$?\/[gimsuy]*/g)) {
    const lit = m[0]
    if (!/[$^]/.test(lit)) continue
    // `d{4}` uten bakstrek foran. Samme for w, s og b.
    const funn = [...lit.matchAll(/(^|[^\\A-Za-z0-9_])([dwsb])\{\d/g)]
    for (const f of funn) ut.push(`${lit} → «${f[2]}{» uten bakstrek`)
  }
  return ut
}

/** Fjerner `//`-linjer og `/* … *​/`-blokker. */
export function utenKommentarer(kilde: string): string {
  return kilde
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split(/\r?\n/)
    .map((l) => l.replace(/(^|\s)\/\/.*$/, '$1'))
    .join('\n')
}

const filer = tsFiler(join(ROT, 'src'))
  .map((f) => ({ f, kilde: readFileSync(f, 'utf8') }))

describe('målingen forstår det den teller', () => {
  it('ser den ekte feilen', () => {
    expect(tapteEscapes('const r = /^d{4}-d{2}-d{2}$/')).toHaveLength(3)
  })

  it('ser ikke den riktige varianten', () => {
    expect(tapteEscapes('const r = /^\\d{4}-\\d{2}-\\d{2}$/')).toEqual([])
  })

  it('ser ikke en vanlig streng', () => {
    // «d{4}» i en streng kan være en mal, en etikett, hva som helst.
    expect(tapteEscapes('const s = "dato er d{4}-d{2}"')).toEqual([])
  })

  it('ser ikke et eksempel i en kommentar', () => {
    // Rettelsen i `bemanning/handlinger.ts` siterer det gale moensteret
    // for aa forklare hva som var galt. Teller vakten den, kan feilen
    // aldri dokumenteres uten aa bli et nytt funn.
    expect(tapteEscapes('// her sto /^d{4}-d{2}$/ og matchet aldri')).toEqual([])
    expect(tapteEscapes('/* /^d{4}$/ */ const a = 1')).toEqual([])
    expect(utenKommentarer('/* /^d{4}$/ */ const a = 1')).not.toContain('d{4}')
  })

  it('ser ikke en bokstav som faktisk er ment', () => {
    // `[abd]{2}` er en tegnklasse der d er bokstaven d — med vilje.
    expect(tapteEscapes('const r = /^[abd]{2}$/')).toEqual([])
  })
})

describe('tapte escapes', () => {
  it('den ser fortsatt filene', () => {
    expect(filer.length, 'fant ingen .ts-filer under src/').toBeGreaterThan(300)
  })

  it('ingen regex har mistet bakstreken sin', () => {
    const funn = filer
      .flatMap(({ f, kilde }) => tapteEscapes(kilde).map((t) => `${f.replace(ROT, '')}: ${t}`))
    expect(
      funn,
      'Et regexliteral har «d{», «w{», «s{» eller «b{» uten bakstrek. Det er '
      + 'bokstaven, ikke tegnklassen, og mønsteret kan aldri matche det du tror.\n'
      + 'Fant i:\n  ' + funn.join('\n  '),
    ).toEqual([])
  })
})
