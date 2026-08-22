import { describe, expect, test } from 'vitest'
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { erServerfil, kastedeSkriv, utenKommentarer } from './skrivevakt'

// =====================================================================
// Skralle på serverhandlinger som kaster resultatet av et skriv.
//
// Feiler hvis tallet VOKSER. Det er 100+ slike i dag, og en storrengjøring
// nå ville vært en diff ingen kunne lese — men ingen nye skal komme til,
// og hver gang en fil røres skal den ryddes.
//
// Skal et tall gå opp med vilje:
//
//     OPPDATER_FASIT=1 npx vitest run src/lib/redesign
//
// Da viser git at det gikk opp, og hvem som lot det skje.
// =====================================================================

const ROT = process.cwd()
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'skrivefasit.json')

function tsFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !/\.test\.tsx?$/.test(rad.name)) ut.push(sti)
  }
  return ut
}

const serverfiler = tsFiler(join(ROT, 'src'))
  .map((f) => ({ f, kilde: readFileSync(f, 'utf8') }))
  .filter(({ kilde }) => erServerfil(kilde))

const naa = serverfiler.reduce((s, { kilde }) => s + kastedeSkriv(kilde).length, 0)

describe('maalingen forstaar det den teller', () => {
  test('et kastet skriv telles', () => {
    expect(kastedeSkriv("await supabase.from('x').insert({ a: 1 })")).toHaveLength(1)
    expect(kastedeSkriv("await supabase.from('x').delete().eq('id', i)")).toHaveLength(1)
  })

  test('et skriv som tas imot telles ikke', () => {
    // Dette er formen kontrakten krever, og den skal aldri felle.
    expect(kastedeSkriv("const { error } = await supabase.from('x').insert({})"))
      .toHaveLength(0)
    expect(kastedeSkriv("return await supabase.from('x').insert({})"))
      .toHaveLength(0)
  })

  test('lesing teller ikke', () => {
    // En lesefeil gir tom liste, ikke en tapt endring. Den er ikke
    // gratis, men den er en annen sak enn denne vakten.
    expect(kastedeSkriv("await supabase.from('x').select('id')")).toHaveLength(0)
  })

  test('kall over flere linjer telles', () => {
    // Den vanligste formen i denne kodebasen er nettopp denne.
    const kilde = [
      'await supabase.from(\'x\').insert({',
      '  a: 1,',
      '})',
    ].join('\n')
    expect(kastedeSkriv(kilde)).toHaveLength(1)
  })

  test('et eksempel i en kommentar teller ikke', () => {
    // KANARIFUGL FOR MAALINGEN SELV. Denne fila er full av
    // `await supabase…insert(…)` i forklaringer. Teller vakten dem,
    // maaler den seg selv.
    expect(kastedeSkriv("// await supabase.from('x').insert({})")).toHaveLength(0)
    expect(utenKommentarer('/* await x.insert() */ const a = 1')).not.toContain('insert')
  })

  test('bare serverfiler leses', () => {
    expect(erServerfil("'use server'\nexport async function a() {}")).toBe(true)
    expect(erServerfil('export function a() {}')).toBe(false)
  })
})

describe('skrivevakten', () => {
  test('den ser fortsatt filene', () => {
    // Peker stien feil, blir lista tom og skrallen groenn uten aa ha
    // sett en eneste serverhandling.
    expect(serverfiler.length, 'fant ingen filer med «use server»')
      .toBeGreaterThan(20)
  })

  test('antallet har ikke vokst', () => {
    if (process.env.OPPDATER_FASIT === '1' || !existsSync(FASIT)) {
      writeFileSync(FASIT, `${JSON.stringify({ kastedeSkriv: naa }, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { kastedeSkriv: number }

    expect(naa, `Serverhandlinger som kaster resultatet av et skriv har gaatt `
      + `fra ${fasit.kastedeSkriv} til ${naa}.\n\n`
      + 'Et kastet skriv kan ikke sjekke `{ error }`, og da ser en avvist '
      + 'lagring noeyaktig ut som en vellykket.\n\n'
      + 'Skriv i stedet:\n'
      + '  const { error } = await supabase.from(...)...\n'
      + '  if (error) return { feil: `Kunne ikke lagre: ${error.message}` }\n\n'
      + 'Er oekningen med vilje: OPPDATER_FASIT=1 npx vitest run src/lib/redesign')
      .toBeLessThanOrEqual(fasit.kastedeSkriv)
  })

  test('fasiten foelger med naar tallet synker', () => {
    // En skralle som ikke strammes er en skralle som staar stille. Ryddes
    // en fil, skal fasiten ned - ellers kan neste person legge til like
    // mange igjen uten at noe sier fra.
    if (process.env.OPPDATER_FASIT === '1' || !existsSync(FASIT)) return
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { kastedeSkriv: number }
    expect(naa, `Tallet har gaatt ned fra ${fasit.kastedeSkriv} til ${naa}. `
      + 'Kjor OPPDATER_FASIT=1 npx vitest run src/lib/redesign')
      .toBeGreaterThanOrEqual(fasit.kastedeSkriv)
  })

  test('timeregnskapets egne handlinger er rene', () => {
    // FLATEN KONTRAKTEN BLE SATT FOR. Uansett hva totalen er, skal disse
    // vaere null - det var her feilen ble oppdaget.
    const mine = serverfiler.filter(({ f }) => f.includes('timeregnskap'))
    for (const { f, kilde } of mine) {
      expect(kastedeSkriv(kilde), `${f} kaster et skriv`).toEqual([])
    }
  })
})
