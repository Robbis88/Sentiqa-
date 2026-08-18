import { describe, expect, test } from 'vitest'
import { nesteSteg, type Tilstand } from './bemanningssteg'

// nb-NO grupperer tusener med hardt mellomrom. Mykner det i påstandene.
const lesbar = (s: string) => s.replace(/\s/g, ' ')

// Utgangspunktet er en stasjon der alt er i orden. Hver test slår ut
// nøyaktig én ting, så det som måles er rekkefølgen og ikke oppsettet.
const klar: Tilstand = {
  harRamme: true,
  gjennomforbar: true,
  underskudd: 0,
  harVindu: true,
  disponible: 1240,
  kontraktTiltak: 'dekket',
  kontraktUdekket: 0,
  stillingsdekning: 1.0,
}

describe('nesteSteg', () => {
  test('alt i orden gir planen som svar, ikke en tom streng', () => {
    const s = nesteSteg(klar)
    expect(s.blokkering).toBe('klar')
    expect(s.stopper).toBe(false)
    expect(lesbar(s.tittel)).toBe('Planen er klar — 1 240 timer til disposisjon')
  })

  test('manglende ramme stopper alt og peker på eier', () => {
    const s = nesteSteg({ ...klar, harRamme: false })
    expect(s.blokkering).toBe('mangler_ramme')
    expect(s.stopper).toBe(true)
    expect(s.handling).toBe('import')
  })

  test('manglende vindu stopper, og lar seg løse her', () => {
    const s = nesteSteg({ ...klar, harVindu: false })
    expect(s.blokkering).toBe('mangler_vindu')
    expect(s.stopper).toBe(true)
    expect(s.handling).toBe('vindu')
  })
})

describe('rekkefølgen mellom blokkeringene', () => {
  test('for stram ramme slår manglende vindu', () => {
    // Legger man inn vinduet foerst, faar man en plan - men den er feil,
    // og feilen ser ut som butikksjefens problem mens den er eierens.
    const s = nesteSteg({
      ...klar, gjennomforbar: false, underskudd: 320, harVindu: false,
    })
    expect(s.blokkering).toBe('ramme_for_stram')
    expect(lesbar(s.tittel)).toContain('320 timer for lite')
    // Ingen handling: dette loeses ikke av et skjema paa denne sida.
    expect(s.handling).toBeUndefined()
  })

  test('manglende ramme slår alt annet', () => {
    const s = nesteSteg({
      ...klar, harRamme: false, gjennomforbar: false, harVindu: false,
      kontraktTiltak: 'ny_stilling', stillingsdekning: 0.5,
    })
    expect(s.blokkering).toBe('mangler_ramme')
  })

  test('harde blokkeringer slår funn i planen', () => {
    // «Stillingene er for smaa» sier ingenting naar det ikke finnes en
    // plan a maale dem mot.
    const s = nesteSteg({
      ...klar, harVindu: false, kontraktTiltak: 'ny_stilling', kontraktUdekket: 900,
    })
    expect(s.blokkering).toBe('mangler_vindu')
  })

  test('kontraktdekning slår kapasitet', () => {
    // Kapasitet loeses med en ekstravakt. Kontraktdekning er et krav om
    // fast stilling etter § 14-4 a, og det vokser stille i tolv maaneder.
    const s = nesteSteg({
      ...klar, kontraktTiltak: 'ny_stilling', kontraktUdekket: 900, stillingsdekning: 0.5,
    })
    expect(s.blokkering).toBe('kontrakt_underdekning')
    expect(s.stopper).toBe(false)
    expect(lesbar(s.tittel)).toContain('900 timer i året')
  })
})

describe('funnene i en ferdig plan', () => {
  test('kapasitet under 95 prosent er verdt en advarsel', () => {
    expect(nesteSteg({ ...klar, stillingsdekning: 0.94 }).blokkering).toBe('stillinger_for_smaa')
  })

  test('95 prosent er godt nok', () => {
    expect(nesteSteg({ ...klar, stillingsdekning: 0.95 }).blokkering).toBe('klar')
  })

  test('mer stilling enn plan er ikke en blokkering', () => {
    // For mye kapasitet betyr at noen ikke faar timene sine. Det er verdt
    // a vite, men det stopper ingen plan.
    expect(nesteSteg({ ...klar, stillingsdekning: 1.4 }).blokkering).toBe('klar')
  })

  test('ukjent kontraktgrunnlag er ikke en paastand om underdekning', () => {
    // For faa bekreftede kontrakter til a svare. Da skal vi ikke paastaa
    // at stillingene er for smaa - vi vet det ikke.
    const s = nesteSteg({ ...klar, kontraktTiltak: 'ukjent_grunnlag' })
    expect(s.blokkering).toBe('klar')
  })

  test('rammeavtale og midlertidig er loeste tiltak, ikke aapne funn', () => {
    expect(nesteSteg({ ...klar, kontraktTiltak: 'ramme' }).blokkering).toBe('klar')
    expect(nesteSteg({ ...klar, kontraktTiltak: 'midlertidig' }).blokkering).toBe('klar')
  })

  test('manglende kontraktmaaling krasjer ikke', () => {
    expect(nesteSteg({ ...klar, kontraktTiltak: null, stillingsdekning: null }).blokkering)
      .toBe('klar')
  })
})
