import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// EN SPØRRING SOM FEILER SKAL ROPE, IKKE BLI TOM
//
// `hentLonnskost` henter seks ting i parallell. Fem av dem ble lest som
// `(svar.data ?? [])`, og da 0182 ikke var kjørt mot produksjon svarte
// PostgREST «relation v_lonnsrom_grunnlag does not exist» — som koden
// leste som «ingen omsetning».
//
// Resultatet: /lonnskost uten lønnsrom på hver eneste måned, uten et
// eneste tegn på hvorfor. «Ingen data» og «spørringen feilet» ser helt
// like ut når feilen svelges.
//
// Samme form som `sql/rpc-feil.test.ts`, bare med `.from()` i stedet for
// `.rpc()`. Den vakten er en port; dette er den samme porten for den ene
// funksjonen der hele siden henger på at seks spørringer lykkes.
//
// Legger noen til en sjuende spørring uten å sjekke `error`, blir denne
// rød — og det er hele poenget.
// =====================================================================

const KILDE = readFileSync(join(process.cwd(), 'src', 'lib', 'lonnskost', 'hent.ts'), 'utf8')

/**
 * Navn som sjekker `error` PÅ STEDET, inne i sin egen innpakning.
 *
 * `bpMnd` er en async-funksjon inne i `Promise.all` som kaster selv —
 * formen `rpc-feil.test.ts` krever, siden den vakten leser fem linjer
 * bakover fra kallet. Den hører derfor ikke hjemme i fellessjekken.
 *
 * Å stå her krever at noen har tatt stilling. Det er meningen.
 */
const SJEKKER_SELV = new Set(['bpMnd'])

describe('hentLonnskost svelger ikke en feilet spørring', () => {
  it('henter seks ting i parallell', () => {
    const m = KILDE.match(/const \[([^\]]+)\] = await Promise\.all\(/)
    expect(m, 'fant ikke Promise.all-destruktureringen').not.toBeNull()
    const navn = m![1].split(',').map((n) => n.trim()).filter(Boolean)
    expect(navn.length).toBeGreaterThanOrEqual(6)
  })

  it('hver spørring har en feilsjekk', () => {
    const m = KILDE.match(/const \[([^\]]+)\] = await Promise\.all\(/)
    const navn = m![1].split(',').map((n) => n.trim()).filter(Boolean)

    const mangler = navn.filter((n) => {
      if (SJEKKER_SELV.has(n)) return false
      // Enten i fellesløkka, eller med en egen `n.error`-sjekk.
      return !new RegExp(`\\[\\s*'[^']*'\\s*,\\s*${n}\\s*\\]`).test(KILDE)
        && !new RegExp(`\\b${n}\\.error\\b`).test(KILDE)
    })

    expect(
      mangler,
      'Disse spørringene leses uten at `error` sjekkes:\n'
      + mangler.join(', ')
      + '\n\nEn feilet spørring blir da til en tom liste, og siden viser '
      + 'ingenting uten å si hvorfor. Legg den i feilsjekken over '
      + '`byggLonnskost`, eller pakk den inn så den kaster selv.',
    ).toEqual([])
  })

  // KANARIFUGL. Slutter regexen aa finne navnene, blir lista tom - og en
  // tom liste ser ut som «alt er sjekket».
  it('KANARIFUGL: den finner faktisk navnene', () => {
    const m = KILDE.match(/const \[([^\]]+)\] = await Promise\.all\(/)
    const navn = m![1].split(',').map((n) => n.trim())
    expect(navn).toContain('grunnlag')
    expect(navn).toContain('brutto')
  })
})
