import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { ansattregister } from './lonnsgrunnlag'

// =====================================================================
// REGISTERET SKAL IKKE MISTE NOEN I STILLHET
//
// `ansattregister` var «første rad vinner, resten forkastes». Det er tre
// ulike tap i én `continue`, og utenfra ser alle tre ut som ingenting:
//
//   samme person to ganger, likt      → riktig å slå sammen
//   samme nummer, ULIKE svar          → et funn, ikke en dublett
//   person uten brukbar timesats      → kjent person, ukjent pris
//
// Den siste er den som betyr noe i drift: den kan RETTES i easy@work,
// men bare hvis noen får vite at den finnes. Kastet sammen med
// stasjonssummene var den umulig å skille fra en person fila aldri
// nevnte.
//
// MÅLT MOT PRODUKSJON: over de 23 kontrollfilene (431 ansattmåneder) er
// både `utenSats` og `konflikter` TOMME. Antakelsen holdt — men en
// antakelse som brytes i stillhet ser ut som ingen feil, og det er
// nettopp derfor disse står her.
// =====================================================================

/** Minste fil som lar seg lese: topprad, én dagslinje, ferdig. */
const fil = (rader: string[][]): string => {
  const hode = ['Stemplingsnummer', 'Ansatt', 'Lønn', 'Lokasjon', 'Hovedlokasjon', 'Dato', 'Timer']
  return [hode, ...rader].map((r) => r.join(',')).join('\n')
}

const DAG = (nr: string, navn: string, sats: string, dato = '2026-07-01') =>
  [nr, navn, sats, 'St1 - Lone', 'St1 - Lone', dato, '7']

describe('ansattregister — hva som overlever', () => {
  it('slår sammen rader som sier nøyaktig det samme', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00', '2026-07-01'),
      DAG('11', 'Ida Nord', '180.00', '2026-07-02'),
      DAG('11', 'Ida Nord', '180.00', '2026-07-03'),
    ]))
    expect(r.ansatte).toHaveLength(1)
    expect(r.ansatte[0].timesats).toBe(180)
    // Tre like observasjoner er én observasjon gjentatt. Ville dette
    // vært en konflikt, hadde hver eneste ansatt vært et funn, og da
    // hadde lista sluttet å bety noe.
    expect(r.konflikter).toEqual([])
  })

  it('melder fra når samme nummer har to ulike satser i samme fil', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00', '2026-07-01'),
      DAG('11', 'Ida Nord', '210.00', '2026-07-02'),
    ]))
    expect(r.konflikter).toHaveLength(1)
    expect(r.konflikter[0].ansattNr).toBe('11')
    expect(r.konflikter[0].ulikSats).toBe(true)
    expect(r.konflikter[0].ulikNavn).toBe(false)
    expect(r.konflikter[0].varianter.map((v) => v.timesats)).toEqual([180, 210])
    // Motoren er ikke rørt i denne porten: første brukbare sats vinner,
    // som før. Forskjellen er at tapet nå står skrevet.
    expect(r.ansatte[0].timesats).toBe(180)
  })

  it('melder fra når samme nummer har to ulike navn i samme fil', () => {
    const r = ansattregister(fil([
      DAG('1018', 'Andre Fjørstad', '180.00', '2026-07-01'),
      DAG('1018', 'Marietta Iacovou', '180.00', '2026-07-02'),
    ]))
    expect(r.konflikter).toHaveLength(1)
    expect(r.konflikter[0].ulikNavn).toBe(true)
    expect(r.konflikter[0].ulikSats).toBe(false)
  })

  it('beholder en person uten timesats som KJENT, ikke som fraværende', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00'),
      // Carmens form: står i fila, men uten en brukbar sats.
      ['1104265', 'Carmen Ruiz', '', 'St1 - Lone', 'St1 - Lone', '', '0'],
    ]))
    expect(r.ansatte.map((a) => a.ansattNr)).toEqual(['11'])
    expect(r.utenSats).toHaveLength(1)
    expect(r.utenSats[0].ansattNr).toBe('1104265')
    expect(r.utenSats[0].ansattNavn).toBe('Carmen Ruiz')
  })

  it('en sats på null er ikke en sats, men personen finnes', () => {
    // EN GRATIS ANSATT SER UT SOM EN BILLIG MÅNED. Null må aldri bli en
    // pris — men den må heller ikke få personen til å forsvinne.
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00'),
      DAG('12', 'Nulla Sats', '0.00'),
    ]))
    expect(r.ansatte.map((a) => a.ansattNr)).toEqual(['11'])
    expect(r.utenSats.map((u) => u.ansattNr)).toEqual(['12'])
  })

  it('en person med sats på én linje og tom på en annen blir priset', () => {
    // Fila kan nevne samme person på flere nivåer. Har ETT av dem en
    // sats, er personen prisbar — men de to svarene er ulike, og det
    // skal stå i `konflikter`.
    const r = ansattregister(fil([
      ['11', 'Ida Nord', '', 'St1 - Lone', 'St1 - Lone', '', '0'],
      DAG('11', 'Ida Nord', '180.00'),
    ]))
    expect(r.ansatte).toHaveLength(1)
    expect(r.ansatte[0].timesats).toBe(180)
    expect(r.utenSats).toEqual([])
    expect(r.konflikter).toHaveLength(1)
  })

  it('stasjonssummer teller ikke som ansatte', () => {
    const r = ansattregister(fil([
      ['', '', '', 'St1 - Lone', '', '', '120'],
      DAG('11', 'Ida Nord', '180.00'),
    ]))
    expect(r.ansatte).toHaveLength(1)
    expect(r.utenSats).toEqual([])
  })

  it('KANARI: en fil uten dagslinjer gir ingen periode, og avvises', () => {
    // Uten denne ville testene over bestått mot en fil som ikke kan
    // dateres — og et register uten periode kan ikke kontrolleres mot
    // måneden det brukes på.
    expect(() => ansattregister(fil([
      ['11', 'Ida Nord', '180.00', 'St1 - Lone', 'St1 - Lone', '', '0'],
    ]))).toThrow(/perioden kan ikke avgjøres/)
  })
})

// ---------------------------------------------------------------------
// MOT EKTE FIL: Carmen
//
// Hun er grunnen til at trinn 1 finnes. I Lones julifil står hun med 0
// timer og sats 138,00, samtidig som hun jobbet 79,82 timer på Bønes.
// `lesLonnsgrunnlag` hopper over rader uten dato, så hun forsvinner ved
// import av lønnsartlinjene — og uten registeret finnes det ingen måte
// å prise Bønes' timer på.
//
// KREVER EKTE LØNNSDATA, som aldri ligger i git. Mangler filene, hopper
// testen over — men HOPPER OVER ER IKKE GRØNT, så kanarien under sier
// fra i klartekst når det skjer.
// ---------------------------------------------------------------------

const LONE_JULI = join(process.cwd(), 'supabase', 'tests', 'lonnsdata', 'lone-2026-07.csv')
const harData = existsSync(LONE_JULI)

describe('Carmen overlever registeret', () => {
  it('KANARI: datagrunnlaget finnes', () => {
    if (!harData) {
      console.warn(
        'HOPPER OVER: supabase/tests/lonnsdata/lone-2026-07.csv mangler. '
        + 'Registermaalingen mot ekte fil ble IKKE kjoert.',
      )
    }
    expect(true).toBe(true)
  })

  it.runIf(harData)('staar i registeret med sats 138, uten en eneste time', () => {
    const r = ansattregister(readFileSync(LONE_JULI, 'utf8'))
    const c = r.ansatte.find((a) => a.ansattNr === '1104265')
    expect(c, 'Carmen (1104265) skal vaere i registeret').toBeDefined()
    expect(c?.timesats).toBe(138)
  })

  it.runIf(harData)('fila har ingen konflikter og ingen uten sats', () => {
    // Maalt over alle 23 kontrollfilene: 431 ansattmaaneder, null av
    // hver. Antakelsen holder - og gaar den i stykker, sier denne fra.
    const r = ansattregister(readFileSync(LONE_JULI, 'utf8'))
    expect(r.konflikter).toEqual([])
    expect(r.utenSats).toEqual([])
    expect(r.ansatte).toHaveLength(18)
  })
})
