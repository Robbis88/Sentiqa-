import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// TILGANGSENDRING HAR ÉN STILLE FEILMÅTE.
//
// `endreStasjoner` gjør to skriv uten transaksjon — PostgREST gir ingen.
// Én av dem kan feile alene, og rekkefølgen avgjør hva som da står igjen:
//
//   fjern først  →  feiler tillegget, har hun for LITE tilgang.
//                   Hun ser det med en gang, og sier fra.
//   legg til først → feiler fjerningen, har hun for MYE tilgang.
//                   Ingenting sier fra. Ingen merker det.
//
// Den stille feilen er den farlige. Rekkefølgen er derfor ikke stil, og
// en ombytting skal koste en rød test.
//
// Vakten leser kilden. Den kan ikke kjøre handlingen — den snakker med
// Supabase — men rekkefølgen og portneren står i teksten, og det er
// nettopp de to som ikke må forsvinne i stillhet.
// =====================================================================

const KILDE = readFileSync(join(process.cwd(), 'src', 'app', '(beskyttet)', 'brukere', 'handlinger.ts'), 'utf8')

/** Kommentarene strippes først. Uten det ville vakten kunne lese sin egen
    forklaring og stå grønn — det har skjedd fire ganger i dette prosjektet. */
const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n').map((l) => l.replace(/\/\/.*$/, '')).join('\n')

function kroppen(navn: string): string {
  const kode = utenKommentarer(KILDE)
  const start = kode.indexOf(`export async function ${navn}(`)
  if (start < 0) return ''
  const neste = kode.indexOf('export async function ', start + 1)
  return kode.slice(start, neste < 0 ? undefined : neste)
}

describe('endreStasjoner', () => {
  const kropp = kroppen('endreStasjoner')

  it('KANARIFUGL: vakten finner handlingen i det hele tatt', () => {
    // Uten dette ville «ingen avvik» også vært svaret hvis funksjonen ble
    // omdøpt — og alle påstandene under ville blitt sanne om tom streng.
    expect(kropp.length).toBeGreaterThan(400)
    expect(kropp).toContain('butikksjef_stasjoner')
  })

  it('fjerner FØR den legger til', () => {
    const fjern = kropp.indexOf('.delete()')
    const leggTil = kropp.indexOf('.upsert(')
    expect(fjern, 'fant ingen fjerning').toBeGreaterThan(-1)
    expect(leggTil, 'fant ingen tillegg').toBeGreaterThan(-1)
    expect(fjern, 'tillegg før fjerning gir for MYE tilgang når fjerningen feiler — og det er stille')
      .toBeLessThan(leggTil)
  })

  it('avbryter hvis fjerningen feiler, i stedet for å legge til likevel', () => {
    // Uten `return` mellom dem ville rekkefølgen vært riktig og likevel
    // meningsløs: begge kjørte uansett.
    const mellom = kropp.slice(kropp.indexOf('.delete()'), kropp.indexOf('.upsert('))
    expect(mellom).toMatch(/if\s*\(fjernFeil\)\s*return/)
  })

  it('slipper bare eier inn', () => {
    expect(kropp).toMatch(/rolle !== 'retailer_admin'/)
  })

  it('tar kjeden fra sesjonen, aldri fra skjemaet', () => {
    expect(kropp).toContain('bruker.retailerId')
    expect(kropp, 'retailer_id fra klienten ville latt eieren skrive i en annen kjede')
      .not.toMatch(/formData\.get\(\s*['"]retailer/)
  })

  it('sjekker BEGGE sider mot egen kjede', () => {
    // Admin-klienten omgår RLS. Da må både profilen og stasjonene bevises
    // å tilhøre kjeden — å sjekke bare den ene er å ikke sjekke.
    const treff = kropp.match(/\.eq\('retailer_id', bruker\.retailerId\)/g) ?? []
    expect(treff.length, 'både profilen og stasjonene må bindes til kjeden').toBeGreaterThanOrEqual(2)
  })

  it('nekter å sette en butikksjef til null stasjoner', () => {
    expect(kropp).toMatch(/valgte\.length === 0/)
  })
})
