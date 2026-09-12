import { describe, expect, it } from 'vitest'
import {
  KONTROLL_TOLERANSE_KR, analyseomraade, erDrivstoffblokk, gruppekodeFor,
  iButikkanalysen, kontrollerUsynlig, nivaaFraType,
} from './nivaa'
import { avstemGrupper, type UsynligProdukt, type UsynligResultat } from '@/lib/parsere/usynligsvinn'

// =====================================================================
// REGLENE SOM AVGJØR OM MATANALYSEN ER SANN
// =====================================================================
//
// Alle tall her er målt på Kelsars sju regnskapsfiler, 42 ark:
//
//   546  grupperader (ProdGr3)      2346  butikkprodukter (5-sifret)
//   420  drivstoff/CR (4-sifret)       0  rader uten kode
//
// Identiteten `teoretisk − faktisk − kast = usynlig` holder med
// `diff = 0` i alle 35 stasjonsmåneder, og mat (120) avstemmer mot
// produktradene i alle 35.
// =====================================================================

const GRUPPER = new Set(['120', '130', '140', '160', '170', '180', '190', '200', '210', '211', '220', '240', '250'])

describe('nivåene', () => {
  it('normaliserer arkets egne typenavn', () => {
    expect(nivaaFraType('ProdGr3')).toBe('gruppe')
    expect(nivaaFraType('Prod')).toBe('produkt')
  })

  it('KANARI: blokkoverskriften er ikke et nivå', () => {
    // `ProdGr1` er «10 Drivstoff» og «40 CR» — seksjonsoverskrifter.
    // Ble de et nivå, kom drivstoffblokkene inn som data.
    expect(nivaaFraType('ProdGr1')).toBeNull()
    expect(nivaaFraType('Oms')).toBeNull()
    expect(nivaaFraType('Res')).toBeNull()
  })
})

describe('analyseomraadet', () => {
  // Blokkene slik de FAKTISK ser ut i arket. To ting maalt 2026-09-12:
  //
  //   1  blokknavnet bygges «kode navn», altsaa `40 40 CR`
  //   2  `10 Drivstoff` er overskriften over ALLE de 13 butikkgruppene
  //
  // Derfor kan ikke overskriften baere regelen alene. Det strukturelle
  // skillet er om blokken inneholder grupper: en REN produktblokk er
  // en drivstoff-/CR-oppstilling.
  const REN = { gruppekoder: GRUPPER, blokkHarGrupper: false }
  const MED = { gruppekoder: GRUPPER, blokkHarGrupper: true }

  it('grupperaden er butikk per definisjon', () => {
    // De 13 gruppene ER universet - ogsaa under en drivstoffoverskrift.
    expect(analyseomraade('gruppe', '120', { ...MED, blokk: '10 10 Drivstoff' })).toBe('butikk')
  })

  it('et produkt hoerer til butikken naar gruppa finnes paa arket', () => {
    expect(analyseomraade('produkt', '12010', { ...MED, blokk: '10 10 Drivstoff' })).toBe('butikk')
    expect(analyseomraade('produkt', '25010', { ...MED, blokk: '10 10 Drivstoff' })).toBe('butikk')
  })

  it('KANARI: drivstoff faller ut fordi gruppa ikke finnes - ikke fordi koden er kort', () => {
    // `1490 Diesel` gir `149`, som ikke er en varegruppe paa arket.
    // Regelen er arkets egen struktur, ikke antall siffer. Robert
    // 2026-09-12: «Firesifrede rader skal ikke fjernes bare fordi de
    // har fire sifre. De skal fjernes fordi de tilhoerer drivstoff/CR.»
    expect(analyseomraade('produkt', '1490', { ...REN, blokk: '40 40 CR' })).toBe('drivstoff')
    expect(analyseomraade('produkt', '1046', { ...REN, blokk: '10 10 Drivstoff' })).toBe('drivstoff')
  })

  it('KANARI: blokknavnet er «kode navn», ikke bare navnet', () => {
    // Den forankrede varianten `^\s*40\s+cr` traff ingenting, fordi
    // arket gir `40 40 CR`. Den var groenn i denne testen og blind i
    // arket: 19 dieselrader per maaned ble `ukjent` i stillhet.
    expect(erDrivstoffblokk('40 40 CR')).toBe(true)
    expect(erDrivstoffblokk('10 10 Drivstoff')).toBe(true)
    expect(analyseomraade('produkt', '1490', { ...REN, blokk: '40 40 CR' })).toBe('drivstoff')
  })

  it('KANARI: en drivstoffoverskrift over butikkgruppene gjoer ingen rad til drivstoff', () => {
    // `99910 UKJENT` paa 4177 - 72 kroner i salg - ligger i en blokk MED
    // grupper. Det er St1s egen uklassifiserte varegruppe, ikke
    // drivstoff. Baaret overskriften regelen alene, ble den drivstoff og
    // dermed usynlig i stedet for blokkert med navn.
    expect(analyseomraade('produkt', '99910', { ...MED, blokk: '10 10 Drivstoff' })).toBe('ukjent')
  })

  it('KANARI: en femsifret kode utenfor gruppene er IKKE butikk', () => {
    // Beviset paa at regelen ikke er kodelengde. Innfoerer St1 en
    // femsifret drivstoffkode, skal den ikke gli inn i butikktallene.
    expect(analyseomraade('produkt', '99010', { ...REN, blokk: '10 10 Drivstoff' })).toBe('drivstoff')
    expect(analyseomraade('produkt', '99010', { ...MED, blokk: '' })).toBe('ukjent')
  })

  it('KANARI: en firesifret kode som ER en gruppe, blir butikk', () => {
    // Motsatt vei. En kodelengderegel ville tatt feil her.
    expect(analyseomraade('produkt', '1201', {
      gruppekoder: new Set(['120']), blokk: '', blokkHarGrupper: true,
    })).toBe('butikk')
  })

  it('ukjent er en egen tilstand, ikke drivstoff', () => {
    // Uten blokkoverskrift vet vi ikke. «Vi vet ikke hva dette er» er
    // et annet svar enn «dette er drivstoff» - begge blokkeres, men de
    // er ikke samme funn, og de skal telles hver for seg.
    expect(analyseomraade('produkt', '1490', { ...REN, blokk: '' })).toBe('ukjent')
  })

  it('bare butikk gaar inn i analysen', () => {
    expect(iButikkanalysen('butikk')).toBe(true)
    expect(iButikkanalysen('drivstoff')).toBe(false)
    expect(iButikkanalysen('ukjent')).toBe(false)
  })

  it('blokkgjenkjenningen treffer arkets egne overskrifter', () => {
    expect(erDrivstoffblokk('10 Drivstoff')).toBe(true)
    expect(erDrivstoffblokk('40 CR')).toBe(true)
    expect(erDrivstoffblokk('10 Drivstoff volum Totalt')).toBe(true)
    expect(erDrivstoffblokk('')).toBe(false)
    expect(erDrivstoffblokk('120 Mat')).toBe(false)
  })

  it('gruppekoden er de tre første sifrene', () => {
    expect(gruppekodeFor('12010')).toBe('120')
    expect(gruppekodeFor('1490')).toBe('149')
    expect(gruppekodeFor('12')).toBeNull()
    expect(gruppekodeFor('mat')).toBeNull()
  })
})

describe('identiteten for usynlig svinn', () => {
  it('Dale juli 2026 stemmer på øret', () => {
    // Målt i arket: teoretisk 493 718,84 − faktisk 429 797,63
    // − kast 32 018,74 = 31 902,47, og kolonne 23 sier nøyaktig det.
    const { kontrollKr, status } = kontrollerUsynlig(493_718.84, 429_797.63, 32_018.74, 31_902.47)
    expect(kontrollKr).toBe(31_902.47)
    expect(status).toBe('ok')
  })

  it('KANARI: et avvik over toleransen felles', () => {
    // Uten dette ville en rad der St1s tall og identiteten spriker
    // blitt brukt til en konklusjon.
    const { status } = kontrollerUsynlig(493_718.84, 429_797.63, 32_018.74, 25_000)
    expect(status).toBe('avvik')
  })

  it('BEGGE tall bevares — ingen erstatter den andre', () => {
    // Sporet tilbake til St1-rapporten forsvinner hvis vi skriver vår
    // egen beregning over deres.
    const { kontrollKr } = kontrollerUsynlig(100, 60, 10, 25)
    expect(kontrollKr).toBe(30)
    expect(KONTROLL_TOLERANSE_KR).toBe(0.5)
  })

  it('negativt usynlig svinn er en verdi, ikke en nullstilling', () => {
    // Dale hadde −9 991,53 i april. Det skal ikke bli 0, og det skal
    // ikke kalles gevinst.
    const { kontrollKr, status } = kontrollerUsynlig(363_759.44, 332_852.73, 40_898.24, -9_991.53)
    expect(kontrollKr).toBe(-9_991.53)
    expect(status).toBe('ok')
  })
})

// =====================================================================
// MAT 120 SOM FAST REGRESJONSTEST
// =====================================================================
//
// Robert 2026-09-12: testen skal feile dersom grupperaden mangler,
// produktdetaljene dobbelttelles, små produktrader filtreres bort,
// synlig kast ikke avstemmer, usynlig svinn ikke avstemmer, eller samme
// fil gir duplikater.
//
// Tallene er Dales juli: gruppe 32 018,74 i kast og 31 902,47 usynlig,
// og produktradene summerer eksakt til dem.
// =====================================================================

const p = (o: Partial<UsynligProdukt>): UsynligProdukt => ({
  kode: '12010', navn: 'Baguette', nivaa: 'produkt', analyseomraade: 'butikk',
  kodeGruppe: '120', kodelengde: 5, salg: 0, bfKr: 0, brfPst: 0,
  teoretiskKr: 0, teoretiskPst: 0, kast: 0, kastPst: 0,
  usynligKr: 0, usynligPst: 0, kontrollUsynligKr: 0, avviksstatus: 'ok',
  kildeRad: 10, ...o,
})

const ark = (produkter: UsynligProdukt[]): UsynligResultat => ({
  rapporttype: 'usynlig_svinn',
  stasjoner: [{ butikknummer: '4185', produkter, totalManko: 0, totalOverskudd: 0 }],
})

/** Dales juli, forenklet til to produktrader som summerer til gruppa. */
const DALE_JULI = () => [
  p({ kode: '120', navn: '120 Mat', nivaa: 'gruppe', kodeGruppe: null, kodelengde: 3,
      salg: 838_292.15, kast: 32_018.74, usynligKr: 31_902.47 }),
  p({ kode: '12010', salg: 800_000, kast: 31_942.84, usynligKr: 31_106.88 }),
  p({ kode: '12011', salg: 38_292.15, kast: 75.90, usynligKr: 795.59 }),
]

describe('mat 120 avstemmer mot produktradene', () => {
  it('avstemt når produktradene summerer til gruppa', () => {
    const a = avstemGrupper(ark(DALE_JULI())).find((x) => x.gruppe === '120')!
    expect(a.gruppeKast).toBe(32_018.74)
    expect(a.produktKast).toBe(32_018.74)
    expect(a.diffKast).toBe(0)
    expect(a.diffUsynlig).toBe(0)
    expect(a.avstemt).toBe(true)
  })

  it('KANARI 1: grupperaden mangler → ingen avstemming i det hele tatt', () => {
    // Grupperaden EIER totalen. Er den borte, finnes ikke sannheten —
    // og det var nøyaktig tilstanden før 0208: parseren tok bare `Prod`.
    const uten = DALE_JULI().filter((x) => x.nivaa !== 'gruppe')
    expect(avstemGrupper(ark(uten))).toEqual([])
  })

  it('KANARI 2: produktdetaljene dobbelttelt → avvik', () => {
    // Summerer en analyse begge nivåer, dobles alt. Skjer det på
    // produktsiden, skal avstemmingen rope.
    const dobbelt = [...DALE_JULI(), p({ kode: '12012', kast: 32_018.74, usynligKr: 31_902.47 })]
    const a = avstemGrupper(ark(dobbelt)).find((x) => x.gruppe === '120')!
    expect(a.avstemt).toBe(false)
    expect(a.diffKast).toBe(-32_018.74)
  })

  it('KANARI 3: en liten produktrad filtrert bort → avvik', () => {
    // 1000-kronersfilteret kostet Dale nøyaktig denne raden: 75,90 i
    // kast. Det var forskjellen mellom viewets 31 943 og arkets
    // 32 018,74.
    const utenSmaa = DALE_JULI().filter((x) => x.kode !== '12011')
    const a = avstemGrupper(ark(utenSmaa)).find((x) => x.gruppe === '120')!
    expect(a.avstemt).toBe(false)
    expect(a.diffKast).toBe(75.9)
    expect(a.diffSalg).toBe(38_292.15)
  })

  it('KANARI 4: synlig kast som ikke avstemmer', () => {
    const rader = DALE_JULI()
    rader[1] = p({ ...rader[1], kast: 20_000 })
    expect(avstemGrupper(ark(rader)).find((x) => x.gruppe === '120')!.avstemt).toBe(false)
  })

  it('KANARI 5: usynlig svinn som ikke avstemmer', () => {
    const rader = DALE_JULI()
    rader[1] = p({ ...rader[1], usynligKr: 0 })
    const a = avstemGrupper(ark(rader)).find((x) => x.gruppe === '120')!
    expect(a.diffUsynlig).toBe(31_106.88)
    expect(a.avstemt).toBe(false)
  })

  it('drivstoff og ukjent regnes ikke med i avstemmingen', () => {
    // Ellers ville 420 drivstoffrader dratt hver gruppe i minus.
    const med = [...DALE_JULI(),
      p({ kode: '1490', navn: '1490 Diesel', analyseomraade: 'drivstoff', kodeGruppe: null, kodelengde: 4, salg: 111_116, kast: 5_000 }),
    ]
    expect(avstemGrupper(ark(med)).find((x) => x.gruppe === '120')!.avstemt).toBe(true)
  })

  it('KANARI: avstemmingen måler faktisk noe', () => {
    // En tom liste ville gjort hver påstand over sann.
    expect(avstemGrupper(ark(DALE_JULI())).length).toBe(1)
  })
})
