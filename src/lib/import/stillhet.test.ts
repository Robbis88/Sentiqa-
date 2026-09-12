import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// «BEST EFFORT» BETYR IKKE «I STILLHET»
// =====================================================================
//
// Importkjernen har flere steg som med vilje ikke velter importen: en
// månedsplan, et varsel, en pivotbuffer som ikke finnes. Det er riktig
// — én manglende plan skal ikke koste et helt regnskap.
//
// Men fem av dem sto med `catch {}` og sa ingenting.
//
// 2026-09-12 var månedsplanene tomme etter en vellykket import, og det
// fantes ingen måte å se hvorfor på: ikke i UI, ikke i jobbraden, ikke i
// noen logg. Diagnosen ble gjetning i flere runder, mens alt så grønt ut.
//
// **Et steg som feiler uten å si fra ser nøyaktig ut som et steg som
// ikke hadde noe å gjøre.** Det er samme form som en vakt som slutter å
// måle, og samme form som `0065` — og huset har skrevet den regelen ned
// før: en handling som svelger feilen sin er verre enn en som kaster.
//
// Merknaden på jobbraden er det ENESTE stedet importen kan forklare seg.
// Derfor skal hver `catch` her skrive noe dit.
// =====================================================================

const FIL = join(process.cwd(), 'src', 'lib', 'import', 'kjerne.ts')

// ---------------------------------------------------------------------
// HVOR REGELEN GJELDER, OG HVORFOR IKKE OVERALT
//
// Merknaden paa jobbraden er mekanismen. Den finnes i
// `behandleJobbKjerne` mens jobben behandles - altsaa i
// `case 'regnskap_resultat'`, der alle fem stille catchene sto.
//
// Utenfor den er det sju til, og de er IKKE glemt:
//
//   `kjorRegnskapsanalyse` / `genererFokusForRetailer` (x2 steder)
//       kjoerer i `after()`, ETTER at jobbraden er skrevet og svaret er
//       sendt. Det finnes ingen merknad aa skrive til paa det
//       tidspunktet, og begge har en ekte reserve: nattjobben og en
//       manuell knapp.
//
//   `ryddUkecache`
//       «Blir cachen staaende, er den feil - men dataene er riktige, og
//       neste import av samme uke rydder den.»
//
//   `varsleOmUrimeligDag`
//       Kjoerer per stasjon per dag. En merknad per dag ville druknet
//       den ene som betyr noe - samme skade som duplikatvarslene.
//
//   `lagreForhandsparset`-grenen
//       Speilbildet av regnskapsgrenen, for filer parset i nettleseren.
//       Boer over paa samme form; staar igjen med vilje her fordi den
//       ikke ble maalt i denne runden.
//
// Vokser lista, er det en beslutning noen tar - ikke noe som sklir inn.
// ---------------------------------------------------------------------

/** Bare `case 'regnskap_resultat'`-grenen. Der finnes merknaden. */
function regnskapsgrenen(kilde: string): string {
  const start = kilde.indexOf("case 'regnskap_resultat': {")
  if (start < 0) throw new Error('fant ikke regnskapsgrenen i kjerne.ts')
  const slutt = kilde.indexOf("case 'easyatwork_stempling'", start)
  if (slutt < 0) throw new Error('fant ikke slutten paa regnskapsgrenen')
  return kilde.slice(start, slutt)
}

/** Fila med LF og uten kommentarer — en kommentar er ikke en handling. */
function utenKommentarer(kilde: string): string {
  return kilde
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/[^\n]*/g, '')
}

/**
 * Tomme `catch`-blokker.
 *
 * Ser etter `catch` + valgfri `(e)` + `{` og krever at det står noe
 * annet enn mellomrom før `}`. Kommentarer er strippet først, så en
 * `catch { /* forklaring *\/ }` teller som tom — den forklarer for den
 * som leser koden, ikke for den som lastet opp fila.
 */
function tommeCatch(kilde: string): number {
  return [...utenKommentarer(kilde).matchAll(/catch\s*(\([^)]*\))?\s*\{\s*\}/g)].length
}

describe('importkjernen sier fra naar et steg feiler', () => {
  const kilde = readFileSync(FIL, 'utf8')

  it('ingen tomme catch-blokker i regnskapsgrenen', () => {
    expect(
      tommeCatch(regnskapsgrenen(kilde)),
      '\nImportkjernen har en `catch` som svelger feilen sin.\n\n'
      + 'Steget skal fortsatt ikke velte importen - men det skal skrive '
      + 'grunnen i merknaden paa jobbraden, som er det eneste stedet '
      + 'importen kan forklare seg.\n\n'
      + 'Maanedsplanene var tomme etter en vellykket import 2026-09-12, og '
      + 'ingen av de fem stille catchene sa hvorfor. Diagnosen ble '
      + 'gjetning.\n',
    ).toBe(0)
  })

  it('KANARI: grenen er funnet, og den inneholder faktisk catcher', () => {
    // Flyttes `case 'regnskap_resultat'` eller byttes nabocasen ut, blir
    // utsnittet tomt - og «ingen tomme catcher» ville vaert sant fordi
    // det ikke er noen catcher i det hele tatt.
    const gren = regnskapsgrenen(kilde)
    expect(gren.length, 'utsnittet er mistenkelig kort').toBeGreaterThan(1500)
    expect((gren.match(/catch/g) ?? []).length, 'ingen catcher i grenen')
      .toBeGreaterThanOrEqual(5)
  })

  it('KANARI: detektoren ser en tom catch', () => {
    // Uten denne kunne regexen vaere doed, og «ingen tomme» sant fordi
    // den ikke finner noen som helst.
    expect(tommeCatch('try { a() } catch {}')).toBe(1)
    expect(tommeCatch('try { a() } catch (e) {   }')).toBe(1)
  })

  it('KANARI: en kommentar teller ikke som en handling', () => {
    // Dette var nettopp formen de fem hadde: en forklaring til den som
    // leser koden, og ingenting til den som lastet opp fila.
    expect(tommeCatch('try { a() } catch { /* skal ikke velte */ }')).toBe(1)
    expect(tommeCatch('try { a() } catch { // best effort\n }')).toBe(1)
  })

  it('KANARI: en catch som faktisk gjoer noe teller ikke', () => {
    // Ellers ville regelen vaert umulig aa oppfylle, og da blir den
    // skrudd av - som er verre enn at den ikke fantes.
    expect(tommeCatch('try { a() } catch (e) { notater.push(grunn(e)) }')).toBe(0)
  })

  it('de fem stegene skriver hver sin grunn', () => {
    // Navngitt, ikke bare talt: forsvinner ett av dem, er det ikke
    // lenger «best effort» - da er det en stille utelatelse igjen.
    for (const tekst of [
      'Maanedsplanene ble ikke bygget',
      'Bemanningsvarsler ble ikke laget',
      'Kaffevarsler ble ikke laget',
      'Bilagsbufferen ble ikke lest',
      'Usynlig svinn ble ikke lest',
    ]) {
      expect(kilde, `merknaden «${tekst}» er borte`).toContain(tekst)
    }
  })

  it('grunnene havner faktisk i merknaden paa jobbraden', () => {
    // En liste ingen leser er ikke en beskjed. `feilnotater` maa med i
    // strengen som skrives til `import_jobber.feilmelding`.
    const ren = utenKommentarer(kilde)
    expect(ren, 'feilnotater samles, men skrives ikke ut').toMatch(/\.\.\.feilnotater/)
    expect(ren, 'plannotat skrives ikke ut').toMatch(/plannotat,/)
  })
})
