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
  // SAMME KOLONNEREKKEFOELGE SOM EKTE FILER. `Betalingsfrekvens` staar
  // mellom `Lønn` og `Lokasjon` i alle 28 kontrollfilene, og parseren
  // krever den: den bærer ENHETEN på tallet i `Lønn`.
  const hode = ['Stemplingsnummer', 'Ansatt', 'Lønn', 'Betalingsfrekvens',
    'Lokasjon', 'Hovedlokasjon', 'Dato', 'Timer']
  return [hode, ...rader].map((r) => r.join(',')).join('\n')
}

const DAG = (nr: string, navn: string, sats: string, dato = '2026-07-01', bf = 'Time') =>
  [nr, navn, sats, bf, 'St1 - Lone', 'St1 - Lone', dato, '7']

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
      ['1104265', 'Carmen Ruiz', '', 'Time', 'St1 - Lone', 'St1 - Lone', '', '0'],
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
      ['11', 'Ida Nord', '', 'Time', 'St1 - Lone', 'St1 - Lone', '', '0'],
      DAG('11', 'Ida Nord', '180.00'),
    ]))
    expect(r.ansatte).toHaveLength(1)
    expect(r.ansatte[0].timesats).toBe(180)
    expect(r.utenSats).toEqual([])
    expect(r.konflikter).toHaveLength(1)
  })

  it('stasjonssummer teller ikke som ansatte', () => {
    const r = ansattregister(fil([
      ['', '', '', 'Time', 'St1 - Lone', '', '', '120'],
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
      ['11', 'Ida Nord', '180.00', 'Time', 'St1 - Lone', 'St1 - Lone', '', '0'],
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

// =====================================================================
// ENHETEN PÅ TALLET
//
// `lonnsregister.timesats` inneholdt 48 736 for Sandra i juli — ikke en
// timesats, men månedslønna hennes, i en kolonne som lover timer.
// Easy@Work sa det rett ut hele tiden; parseren brukte kolonnen til å
// kjenne igjen filtypen og kastet den.
//
// MÅLT: `Betalingsfrekvens` står bare på ANSATTSUM-raden, ikke på
// dagslinjene. En blank enhet er derfor et fravær, ikke en motstrid.
// =====================================================================

describe('betalingsfrekvens', () => {
  it('leser Time og Måned, og normaliserer til ASCII én gang', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00', '2026-07-01', 'Time'),
      DAG('118', 'Sandra S', '48736.00', '2026-07-02', 'Måned'),
    ]))
    expect(r.ansatte.find((a) => a.ansattNr === '11')?.betalingsfrekvens).toBe('time')
    expect(r.ansatte.find((a) => a.ansattNr === '118')?.betalingsfrekvens).toBe('maaned')
  })

  it('en ukjent enhet blir null, ALDRI time', () => {
    // EN UKJENT ENHET ER IKKE TIMER. Gjettet vi på «time», ville et tall
    // som kan være månedslønn blitt ganget med timene.
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00', '2026-07-01', 'Uke'),
    ]))
    expect(r.ansatte[0].betalingsfrekvens).toBeNull()
  })

  it('blank enhet på en dagslinje er fravær, ikke motstrid', () => {
    // Enheten står bare på ansattsum-raden. Talte vi blank som en
    // variant, ville hver eneste person i hver eneste fil blitt et funn
    // — og da slutter konfliktlista å bety noe.
    const r = ansattregister(fil([
      ['11', 'Ida Nord', '180.00', 'Time', 'St1 - Lone', 'St1 - Lone', '', '0'],
      DAG('11', 'Ida Nord', '180.00', '2026-07-01', ''),
      DAG('11', 'Ida Nord', '180.00', '2026-07-02', ''),
    ]))
    expect(r.konflikter).toEqual([])
    expect(r.ansatte[0].betalingsfrekvens).toBe('time')
  })

  it('TO ULIKE UTFYLTE enheter er en konflikt', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00', '2026-07-01', 'Time'),
      DAG('11', 'Ida Nord', '180.00', '2026-07-02', 'Måned'),
    ]))
    expect(r.konflikter).toHaveLength(1)
    expect(r.konflikter[0].ulikFrekvens).toBe(true)
    expect(r.konflikter[0].ulikSats).toBe(false)
  })

  it('enheten hentes på tvers av radene, ikke fra satsraden', () => {
    // Satsen kan stå på en dagslinje mens enheten står på ansattsummen.
    // Hentet vi enheten fra raden som tilfeldigvis bar satsen, ville
    // Sandra fått null enhet og 48 736 kunne blitt timepriset.
    // ANSATTSUM-RADEN STAAR SIST HER, MED VILJE. Foerste utgave hadde
    // den foerst, og da bestod testen ogsaa naar koden bare leste
    // `obs[0].frekvens` - injeksjonen kom tilbake groenn.
    const r = ansattregister(fil([
      DAG('118', 'Sandra S', '48736.00', '2026-07-02', ''),
      ['118', 'Sandra S', '', 'Måned', 'St1 - Lone', 'St1 - Lone', '', '0'],
    ]))
    expect(r.ansatte[0].timesats).toBe(48736)
    expect(r.ansatte[0].betalingsfrekvens).toBe('maaned')
  })

  it('også en person uten sats bærer enheten', () => {
    const r = ansattregister(fil([
      DAG('11', 'Ida Nord', '180.00'),
      ['12', 'Uten Sats', '', 'Måned', 'St1 - Lone', 'St1 - Lone', '', '0'],
    ]))
    expect(r.utenSats[0].betalingsfrekvens).toBe('maaned')
  })
})

// ---------------------------------------------------------------------
// MOT EKTE FILER: historikken skal ikke omskrives
//
// Sandra står «Måned»/48 736 i sju sammenhengende måneder og «Time»/285
// i august. Vi vet IKKE om arbeidsforholdet endret seg eller om
// Easy-data ble rettet — og registeret skal ikke velge side. Hver måned
// bevarer sin egen observasjon.
//
// Det er derfor `kilde_maaned` er en nøkkeldel og ikke pynt.
// ---------------------------------------------------------------------

const LONE_AUG = join(process.cwd(), 'supabase', 'tests', 'lonnsdata',
  'lonnsgrunnlag-2026-08', 'lone.csv')
const harBegge = harData && existsSync(LONE_AUG)

describe('Sandra og Carmen, måned for måned', () => {
  it('KANARI: begge filene finnes', () => {
    if (!harBegge) {
      console.warn(
        'HOPPER OVER: Lones juli- eller augustfil mangler. '
        + 'Frekvensmaalingen mot ekte data ble IKKE kjoert.',
      )
    }
    expect(true).toBe(true)
  })

  it.runIf(harBegge)('Lone JULI: Sandra er Måned/48 736, Carmen er Time/138', () => {
    const r = ansattregister(readFileSync(LONE_JULI, 'utf8'))
    const sandra = r.ansatte.find((a) => a.ansattNr === '118')
    expect(sandra?.betalingsfrekvens, 'Sandra juli').toBe('maaned')
    expect(sandra?.timesats).toBe(48736)

    const carmen = r.ansatte.find((a) => a.ansattNr === '1104265')
    expect(carmen?.betalingsfrekvens, 'Carmen juli').toBe('time')
    expect(carmen?.timesats).toBe(138)
  })

  it.runIf(harBegge)('Lone AUGUST: Sandra er Time/285 — kilden skiftet mening', () => {
    // LIKE VIKTIG SOM JULI. Systemet skal bevare hva Easy faktisk sa
    // hver måned, ikke «rette» historikken mot den nyeste observasjonen.
    const r = ansattregister(readFileSync(LONE_AUG, 'utf8'))
    const sandra = r.ansatte.find((a) => a.ansattNr === '118')
    expect(sandra?.betalingsfrekvens, 'Sandra august').toBe('time')
    expect(sandra?.timesats).toBe(285)
  })

  it.runIf(harBegge)('de to månedene påvirker ikke hverandre', () => {
    // Leses de i motsatt rekkefølge, skal svaret være det samme. En
    // delt tilstand mellom to filer ville gitt siste fil vinner — og
    // det ville sett ut som at Sandra alltid har vært timelønnet.
    const aug = ansattregister(readFileSync(LONE_AUG, 'utf8'))
    const juli = ansattregister(readFileSync(LONE_JULI, 'utf8'))
    expect(juli.ansatte.find((a) => a.ansattNr === '118')?.betalingsfrekvens).toBe('maaned')
    expect(aug.ansatte.find((a) => a.ansattNr === '118')?.betalingsfrekvens).toBe('time')
  })

  it.runIf(harBegge)('ingen fil har en ukjent enhet', () => {
    // Målt over alle 28 filene: 511 «Time», 7 «Måned», 0 andre. Dukker
    // det opp en tredje verdi, er det et funn — ikke et tilfelle.
    for (const f of [LONE_JULI, LONE_AUG]) {
      const r = ansattregister(readFileSync(f, 'utf8'))
      const ukjent = [...r.ansatte, ...r.utenSats].filter((x) => x.betalingsfrekvens === null)
      expect(ukjent.map((x) => x.ansattNr), `ukjent enhet i ${f}`).toEqual([])
    }
  })
})
