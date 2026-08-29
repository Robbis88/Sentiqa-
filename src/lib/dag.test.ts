import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { erDag, lesDag } from './periode'

// =====================================================================
// EN UGYLDIG DATO GA HVIT SIDE, IKKE EN DAARLIG DAG
//
// `/salg` validerte `?dato=` med en regex som bare talte sifre. Den
// godtok den trettende maaneden og den 45. dagen, som ble til
// `Invalid Date`, som ble til `RangeError: Invalid time value` naar sida
// trakk 56 dager for aa finne sammenligningsgrunnlaget.
//
// Det er samme form som `\d{2}` hadde paa maanedsleddet i `erMaaned` -
// og den ble ogsaa funnet av en test, ikke av lesing.
// =====================================================================

/**
 * Den gamle valideringen, som tekst.
 *
 * Den staar her som `String.raw` og ikke som en regex med vilje: en
 * regex som leter etter en regex maa dobbeltrommes, og hvert lag er en
 * sjanse til aa miste en backslash. Da maaler vakten ingenting, og ser
 * ut som den maaler alt.
 */
const GAMMEL_FORM = String.raw`\d{4}-\d{2}-\d{2}`

describe('erDag', () => {
  it('godtar en vanlig dag', () => {
    expect(erDag('2026-08-29')).toBe(true)
    expect(erDag('2026-01-01')).toBe(true)
    expect(erDag('2026-12-31')).toBe(true)
  })

  it('KANARIFUGL: avviser maaned 13 og dag 45', () => {
    // Presis den verdien som ga RangeError. Slutter denne aa feile,
    // maaler ikke resten av fila noe heller.
    expect(erDag('2026-13-45')).toBe(false)
    expect(erDag('2026-00-10')).toBe(false)
    expect(erDag('2026-08-32')).toBe(false)
    expect(erDag('2026-08-00')).toBe(false)
  })

  it('KANARIFUGL: avviser en dag som ruller stille over', () => {
    // `2026-02-31` bestaar enhver kontroll som teller sifre, men
    // `new Date` gjor den om til 3. mars UTEN aa si fra. Da viser sida en
    // annen dag enn URL-en lover - verre enn en feilmelding, fordi
    // tallene ser riktige ut.
    expect(erDag('2026-02-31')).toBe(false)
    expect(erDag('2026-04-31')).toBe(false)
    // ...men skuddaaret finnes, og en for streng kontroll er ogsaa feil.
    expect(erDag('2028-02-29')).toBe(true)
    expect(erDag('2026-02-29')).toBe(false)
  })

  it('avviser former som ikke er en dag', () => {
    expect(erDag('2026-08')).toBe(false)
    expect(erDag('29.08.2026')).toBe(false)
    expect(erDag('')).toBe(false)
    expect(erDag(undefined)).toBe(false)
    expect(erDag(20260829)).toBe(false)
  })
})

describe('lesDag', () => {
  it('tar dagen fra URL-en naar den er gyldig', () => {
    expect(lesDag({ dato: '2026-08-14' }, '2026-08-29')).toBe('2026-08-14')
  })

  it('faller tilbake til standarden, den KRASJER ikke', () => {
    // Hele poenget. Sida skal vise siste dag med data, ikke ingenting.
    expect(lesDag({ dato: '2026-13-45' }, '2026-08-29')).toBe('2026-08-29')
    expect(lesDag({ dato: 'i gaar' }, '2026-08-29')).toBe('2026-08-29')
    expect(lesDag({}, '2026-08-29')).toBe('2026-08-29')
  })

  it('taaler mellomrom rundt', () => {
    expect(lesDag({ dato: ' 2026-08-14 ' }, '2026-08-29')).toBe('2026-08-14')
  })
})

// =====================================================================
// INGEN SIDE SKAL VALIDERE DATOEN SELV IGJEN
//
// Den slurvete kontrollen var ikke feil fordi noen var uoppmerksom - den
// var feil fordi den sto ETT sted og saa riktig ut. Kommer det en til,
// staar vi samme sted om et halvaar.
// =====================================================================

/**
 * Kilden uten kommentarer.
 *
 * FORSTE UTGAVE AV DENNE VAKTEN FEILET PAA SIN EGEN FORKLARING: jeg
 * skrev den gamle formen inn i en kommentar i `/salg` for aa begrunne
 * hvorfor den var borte, og vakten leste den som kode. Samme form som da
 * RLS-vakthunden traff ordene «row level security» i sin egen migrasjon.
 *
 * En vakt som ikke skiller kode fra prat, tvinger fram kommentarer som
 * ikke tor naevne det de handler om.
 */
function utenKommentarer(kilde: string): string {
  return kilde.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')
}

describe('sidene leser dagen gjennom kontrakten', () => {
  const sider = ['salg', 'timesalg']

  it.each(sider)('/%s bruker lesDag og ikke sin egen kontroll', (side) => {
    const kilde = readFileSync(
      join(process.cwd(), 'src/app/(beskyttet)', side, 'page.tsx'), 'utf8')

    expect(kilde, `/${side} skal lese datoen med lesDag`).toContain('lesDag')
    expect(
      utenKommentarer(kilde),
      `/${side} validerer datoen selv - bruk lesDag i stedet`,
    ).not.toContain(GAMMEL_FORM)
  })

  it('KANARIFUGL: monsteret kjenner igjen den gamle formen', () => {
    // Slutter dette aa treffe, blir paastanden over gronn uansett hva
    // sidene gjor - og en vakt som ikke ser, ser ut som en som ikke
    // finner noe.
    expect(utenKommentarer('const d = /^' + GAMMEL_FORM + '$/.test(valgtDato)'))
      .toContain(GAMMEL_FORM)
  })

  it('KANARIFUGL: kommentarstrippen fjerner bare kommentarer', () => {
    // Tar den for mye, blir paastanden over gronn fordi den leser en tom
    // fil - nettopp den blindheten den skal beskytte mot.
    const linje = `const a = 1 // ${GAMMEL_FORM}`
    expect(utenKommentarer(linje)).toContain('const a = 1')
    expect(utenKommentarer(linje)).not.toContain(GAMMEL_FORM)
  })
})
