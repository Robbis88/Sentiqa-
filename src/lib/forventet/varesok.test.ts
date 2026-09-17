import { describe, expect, it } from 'vitest'
import { kandidater, slaaOpp, spoersmaal, type Varerad } from './varesok'
import { maalTreff, tillit, type Treffmaal } from './treffsikkerhet'
import { MODELLER, type Salgsrad } from './motor'

// =====================================================================
// RESOLVEREN VELGER ALDRI STILLE
// =====================================================================
//
// Målt i produksjon 2026-09-17: fire ulike EAN kan naturlig forstås som
// «Coca-Cola uten sukker», i fire forskjellige størrelser. Å ta den mest
// solgte ville gitt riktig svar fire av fem ganger — og feil svar uten
// at noen merket det.
// =====================================================================

const r = (
  ean: string, varenavn: string, dato = '2026-09-01',
  antall = 10, vg = '1402', vgn = 'BRUS MEDIUM =0,4 - 0,6l',
  stasjon = 's1',
): Varerad => ({
  ean, varenavn, dato, antall, varegruppe_kode: vg, varegruppe_navn: vgn,
  avdeling_navn: 'KALD DRIKKE', stasjon_id: stasjon,
})

/** De faktiske produksjonsradene, forenklet. */
const PROD: Varerad[] = [
  r('5000112636833', 'COCA-COLA 0.5L', '2026-09-01', 15_980),
  r('5000112636840', 'COCA-COLA UTEN SUKKE', '2026-09-01', 8_189),
  r('5000112636871', 'COCA-COLA UTEN SUKKE', '2026-09-01', 797, '1403', 'BRUS STOR >0,6l'),
  r('5000112637397', 'COCA-COLA UTEN SUKKE', '2026-09-01', 688, '1401', 'BRUS LITEN<0,4L'),
  r('5000112691719', '0,5 L COCA-COLA ZERO', '2026-09-01', 399),
  // Samme EAN, to navn over tid. Én vare, ikke to.
  r('5000112651881', 'COCA-COLA UTEN SUKKE', '2026-03-01', 200),
  r('5000112651881', '0,5 L COCA-COLA ZERO', '2026-08-01', 278),
  // Falsk venn: traff /cola/ i produksjonsmaalingen.
  r('7071864018589', 'MUFFINS MILK CHOCOLA', '2026-09-01', 98, '1205', 'KAKER'),
]

describe('navn finner, EAN identifiserer', () => {
  it('flere EAN med samme navn gir FLERE, ikke den stoerste', () => {
    const o = slaaOpp(PROD, 'coca cola uten sukker')
    expect(o.slag).toBe('flere')
  })

  it('«cola zero» treffer begge zero-variantene og spoer', () => {
    const o = slaaOpp(PROD, 'cola zero')
    expect(o.slag).toBe('flere')
    if (o.slag !== 'flere') return
    expect(o.kandidater.map((k) => k.ean).sort())
      .toEqual(['5000112651881', '5000112691719'])
  })

  it('SAMME EAN MED TO NAVN ER ÉN KANDIDAT', () => {
    const o = slaaOpp(PROD.filter((x) => x.ean === '5000112651881'), 'cola')
    expect(o.slag).toBe('entydig')
    if (o.slag !== 'entydig') return
    expect(o.vare.navnHistorikk).toHaveLength(2)
    // Nyeste navn vises; begge finnes.
    expect(o.vare.navn).toBe('0,5 L COCA-COLA ZERO')
  })

  it('et gammelt navn finner fortsatt varen', () => {
    const o = slaaOpp(PROD.filter((x) => x.ean === '5000112651881'), 'coca cola uten sukker')
    expect(o.slag).toBe('entydig')
  })

  it('alle ordene maa treffe — OG, ikke ELLER', () => {
    // «cola zero» skal ikke treffe hver vare med «cola» i navnet.
    expect(kandidater(PROD, 'cola').length).toBeGreaterThan(5)
    expect(kandidater(PROD, 'cola zero')).toHaveLength(2)
  })

  it('bindestrek og mellomrom er samme soek', () => {
    const a = kandidater(PROD, 'coca-cola 0.5l').map((k) => k.ean)
    const b = kandidater(PROD, 'coca cola 05 l').map((k) => k.ean)
    expect(a).toEqual(b)
    expect(a).toContain('5000112636833')
  })

  it('en falsk venn er en kandidat, ikke et valg', () => {
    // «MUFFINS MILK CHOCOLA» traff /cola/ i produksjonsmaalingen. Den
    // skal komme med som kandidat - og nettopp derfor spoer vi.
    const o = slaaOpp(PROD, 'chocola')
    expect(o.slag).toBe('entydig')
    if (o.slag === 'entydig') expect(o.vare.ean).toBe('7071864018589')
  })

  it('ingen treff gir ingen, ikke et gjett', () => {
    expect(slaaOpp(PROD, 'pepsi max').slag).toBe('ingen')
  })

  it('en EAN oppgitt direkte gaar rett gjennom', () => {
    const o = slaaOpp(PROD, '5000112636833')
    expect(o.slag).toBe('entydig')
    if (o.slag === 'entydig') expect(o.vare.navn).toBe('COCA-COLA 0.5L')
  })

  it('en ukjent EAN gir ingen, ikke naermeste navn', () => {
    expect(slaaOpp(PROD, '9999999999999').slag).toBe('ingen')
  })

  it('AVKORTEDE NAVN: «uten sukker» finner «UTEN SUKKE»', () => {
    // Kilden kutter varenavnet ved 20 tegn. Brukeren skriver hele ordet.
    expect(kandidater(PROD, 'coca cola uten sukker').length).toBeGreaterThan(0)
  })

  it('bare SISTE ord kan vaere kappet', () => {
    // Kuttet skjer paa slutten av strengen. «sukker» som FOERSTE ord maa
    // finnes helt - navnet baerer «sukke», og det er ikke et treff naar
    // ordet ikke staar sist i soeket.
    expect(kandidater(PROD, 'sukker cola')).toHaveLength(0)
    expect(kandidater(PROD, 'cola sukker').length).toBeGreaterThan(0)
  })

  it('AVKORTINGSREGELEN GJOER IKKE SOEKET USKARPT', () => {
    // Foerste utgave lot prefikset bli vilkaarlig kort, og da traff
    // «sukkerfri» navnet «UTEN SUKKE». Hoeyst to tegn kan mangle.
    expect(kandidater(PROD, 'cola sukkerfri')).toHaveLength(0)
    // Og navnet maa SLUTTE der. «milk» staar midt i «MUFFINS MILK
    // CHOCOLA», saa «milky» er ikke en avkorting av noe.
    expect(kandidater(PROD, 'muffins milky')).toHaveLength(0)
    // Mens en ekte avkorting fortsatt treffer: navnet slutter paa
    // «CHOCOLA».
    expect(kandidater(PROD, 'muffins chocolat')).toHaveLength(1)
  })

  it('KANARIFUGL — soeket filtrerer faktisk', () => {
    // Slutter `treffer` aa filtrere, blir hvert soek «flere» med alt i
    // seg, og testene over ville fortsatt sett fornuftige ut.
    expect(kandidater(PROD, 'pepsi')).toHaveLength(0)
  })

  it('spoersmaalet nevner varegruppen — den skiller like navn', () => {
    const o = slaaOpp(PROD, 'coca cola uten sukker')
    if (o.slag !== 'flere') throw new Error('ventet flere')
    const s = spoersmaal(o.kandidater)
    expect(s).toContain('BRUS STOR')
    expect(s).toContain('BRUS LITEN')
  })
})

// =====================================================================
// TREFFSIKKERHET ER EN OBSERVASJON, IKKE ET INTERVALL
// =====================================================================

const salgsrad = (dato: string, antall: number): Salgsrad => ({
  stasjonId: 's1', ean: 'e1', dato, antall,
  varegruppeKode: '1402', varegruppeNavn: 'BRUS MEDIUM',
})

function serie(til: string, dager: number, n: number): Salgsrad[] {
  const ut: Salgsrad[] = []
  const d = new Date(`${til}T12:00:00Z`)
  for (let i = 0; i < dager; i++) {
    ut.push(salgsrad(d.toISOString().slice(0, 10), n))
    d.setUTCDate(d.getUTCDate() - 1)
  }
  return ut
}

const M = Object.fromEntries(MODELLER.map((m) => [m.navn, m]))

describe('maalTreff', () => {
  it('maaler mot fasit og gir null naar ingenting kunne maales', () => {
    const tom = maalTreff({
      enhet: { stasjonId: 's1', ean: 'e1' }, salg: [],
      maaldatoer: ['2026-09-10'], modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(tom).toBeNull()
  })

  it('en perfekt serie gir null feil', () => {
    const salg = serie('2026-09-20', 60, 10)
    const m = maalTreff({
      enhet: { stasjonId: 's1', ean: 'e1' }, salg,
      maaldatoer: ['2026-09-18', '2026-09-19', '2026-09-20'],
      modell: M.basis, minstDagerMedSalg: 10,
    })!
    expect(m.dager).toBe(3)
    expect(m.mae).toBe(0)
    expect(m.wmape).toBe(0)
    expect(m.bias).toBe(0)
  })

  it('en dag UTEN rad hoppes over, ikke telles som 0', () => {
    // 206 av 223 708 rader har antall = 0. Fravaer er ikke null salg, og
    // en maaling som gjetter null beloenner en motor som sier lite.
    //
    // HULLET MAA LIGGE DER MOTOREN FAKTISK SVARER. Foerste utgave brukte
    // 2026-12-24, tre maaneder etter siste rad - da ga motoren
    // `ingen_basis` og dagen ble hoppet over uansett. Testen var groenn
    // av feil grunn, og en injeksjon som talte manglende dager som 0
    // gikk rett gjennom.
    const HULL = '2026-09-15'
    const salg = serie('2026-09-20', 60, 10).filter((s) => s.dato !== HULL)
    const m = maalTreff({
      enhet: { stasjonId: 's1', ean: 'e1' }, salg,
      maaldatoer: ['2026-09-20', HULL],
      modell: M.basis, minstDagerMedSalg: 10,
    })!
    // Motoren HAR dekning paa hulldagen - den mangler bare fasit.
    expect(m.dager).toBe(1)
    expect(m.mae).toBe(0)
    expect(m.wmape).toBe(0)
  })

  it('TYPEN BAERER INGEN INTERVALLFELTER', () => {
    // «22 % historisk feil» er ikke «38 +/- 22 %». Det som ikke kan
    // uttrykkes, kan ikke lekke ut i et svar.
    const salg = serie('2026-09-20', 60, 10)
    const m = maalTreff({
      enhet: { stasjonId: 's1', ean: 'e1' }, salg,
      maaldatoer: ['2026-09-20'], modell: M.basis, minstDagerMedSalg: 10,
    })!
    const felt = Object.keys(m)
    expect(felt).not.toContain('fra')
    expect(felt).not.toContain('til')
    expect(felt.join(' ')).not.toMatch(/intervall|konfidens|sannsynlig|spenn/i)
  })
})

describe('tillit', () => {
  const m = (wmape: number | null, dager = 28): Treffmaal => ({
    dager, mae: 5, medianFeil: 2, wmape, bias: 0, snittFaktisk: 20,
  })

  it('leser grensene av maalingen', () => {
    // Dale 22,2 %, Laguneparken 26,6 %, Boenes 48,1 %.
    expect(tillit(m(22.2))).toBe('god')
    expect(tillit(m(26.6))).toBe('middels')
    expect(tillit(m(33.3))).toBe('middels')
    expect(tillit(m(48.1))).toBe('svak')
  })

  it('FAA DAGER ER IKKE GOD TREFFSIKKERHET', () => {
    // Fire dager med perfekt treff sier ingenting.
    expect(tillit(m(0, 4))).toBe('ukjent')
    expect(tillit(null)).toBe('ukjent')
    expect(tillit(m(null))).toBe('ukjent')
  })

  it('KANARIFUGL — grensene skiller faktisk', () => {
    expect(new Set([tillit(m(10)), tillit(m(30)), tillit(m(60))]).size).toBe(3)
  })
})
