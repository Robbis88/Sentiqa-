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

// =====================================================================
// EN SKRIVEFEIL LAGET EN BRUKER INGEN KUNNE LOGGE INN SOM
//
// `opprettBruker` tok ÉTT passordfelt, `type="password"`. Traff du feil
// tast, ble kontoen opprettet med et passord ingen kjenner — verken den
// som skrev det eller den som skulle bruke det.
//
// Det ser ut som en vellykket handling. Kvitteringen sier «Bruker
// opprettet», og den er sann. Feilen dukker først opp når noen prøver å
// logge inn, og da peker ingenting tilbake hit.
//
// Verst på en TABLET-konto: passordet skal tastes inn på nettbrettet
// etterpå, så det må kunne leses tilbake. Uten det gjettes det inn på
// enheten, og man er tilbake til en konto ingen kommer inn på.
//
// ---------------------------------------------------------------------
// SJEKKEN MÅ LIGGE PÅ SERVEREN
//
// Et `required`-attributt og en `useState` er visninger. Grensen er der
// avgjørelsen tas — samme regel som `malekort.anonymiser` og
// `malekort.vis_tablet` lærte oss, bare i et skjema.
// =====================================================================
describe('opprettBruker: passordet kan ikke skrives feil i stillhet', () => {
  const kropp = kroppen('opprettBruker')
  const skjema = readFileSync(
    join(process.cwd(), 'src', 'app', '(beskyttet)', 'brukere', 'ny-bruker.tsx'), 'utf8')

  it('KANARIFUGL: vakten leser faktisk handlingen og skjemaet', () => {
    expect(kropp.length, 'fant ikke opprettBruker').toBeGreaterThan(200)
    expect(skjema.length, 'fant ikke ny-bruker.tsx').toBeGreaterThan(500)
  })

  it('gjentakelsen sammenlignes PÅ SERVEREN', () => {
    const kode = utenKommentarer(KILDE)
    expect(kode, 'skjemaet validerer ikke gjentakelsen')
      .toMatch(/passord_gjenta/)
    expect(
      kode,
      'de to feltene sammenlignes ikke — da er gjentakelsen bare pynt, og '
      + 'en skrivefeil lager fortsatt en bruker ingen kan logge inn som',
    ).toMatch(/d\.passord === d\.passord_gjenta/)
  })

  it('handlingen leser feltet fra skjemaet', () => {
    // Uten dette ville `passord_gjenta` vaert `undefined` paa serveren,
    // og sammenligningen over ville sammenlignet passordet med ingenting.
    expect(kropp).toMatch(/formData\.get\('passord_gjenta'\)/)
  })

  it('skjemaet har begge feltene og en vis-bryter', () => {
    expect(skjema, 'mangler gjentakelsesfeltet').toMatch(/name="passord_gjenta"/)
    // Bryteren er ikke pynt: en tablet-konto skal tastes inn paa et
    // nettbrett etterpaa, og da maa passordet kunne leses tilbake.
    expect(skjema, 'ingen maate aa se passordet paa')
      .toMatch(/type=\{vis \? 'text' : 'password'\}/)
  })

  it('passordet er SKJULT som standard', () => {
    // Skjermen staar ofte i et rom med andre folk. Bryteren skal vaere et
    // valg, ikke en tilstand man arver.
    expect(skjema).toMatch(/useState\(false\)/)
  })
})
