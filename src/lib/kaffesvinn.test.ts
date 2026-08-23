import { describe, expect, test } from 'vitest'
import { kopperPerAvtaleDag, lagKaffevarsel, type Kaffemaaling } from './kaffesvinn'

// Lone, desember 2025 – juni 2026, målt mot produksjon. Kassa sa 73,5 %
// etter alle registrerte påfyll, tellingen sa 48,1 %.
const LONE: Kaffemaaling = {
  kassaOmsetningKr: 300_000,
  kassaBruttoKr: 220_500, // 73,5 %
  kassaBruttoUtenUtdelingKr: 249_300, // 83,1 %
  regnskapOmsetningKr: 286_710,
  regnskapBruttoKr: 137_908, // 48,1 %
  maaneder: 7,
  vanligste: { varenavn: 'PÅFYLL KAFFE MEDIUM', krPerKopp: 3.82 },
}

const som = (endring: Partial<Kaffemaaling>): Kaffemaaling => ({ ...LONE, ...endring })

describe('varselet fyrer på det som kan gjøres noe med', () => {
  test('Lone får varsel, og det sier et antall kopper', () => {
    const v = lagKaffevarsel(LONE)
    expect(v).not.toBeNull()
    expect(v!.type).toBe('kaffe_paafyll')
    // «11 % av kaffemarginen mangler» er sant og ubrukelig.
    expect(v!.kopper).toBeGreaterThan(15_000)
    expect(v!.tekst).toContain('PÅFYLL KAFFE MEDIUM')
    expect(v!.tekst).toMatch(/Slå inn [\d\s ]+ PÅFYLL/)
  })

  test('teksten sier begge tallene, så anslaget kan etterprøves', () => {
    const v = lagKaffevarsel(LONE)!
    expect(v.tekst, 'kassa').toContain('73,5 %')
    expect(v.tekst, 'tellingen').toContain('48,1 %')
  })

  test('en stasjon som har orden får ingenting', () => {
    // KANARIFUGL: fyrer denne, staar det varsel paa hver stasjon hver
    // maaned - og da leser ingen det naar det gjelder.
    expect(lagKaffevarsel(som({
      regnskapBruttoKr: 219_000, regnskapOmsetningKr: 300_000, // 73 % mot 73,5
    }))).toBeNull()
  })

  test('Laguneparken FANT penger ved tellingen, og det er ikke et varsel', () => {
    // Regnskapet bedre enn kassa. Da er det ikke kopper som mangler, og
    // et varsel om aa slaa inn flere ville vaert direkte feil.
    expect(lagKaffevarsel(som({
      kassaBruttoKr: 113_700, kassaOmsetningKr: 300_000, // 37,9 %
      regnskapBruttoKr: 127_500, regnskapOmsetningKr: 300_000, // 42,5 %
    }))).toBeNull()
  })
})

describe('tersklene slipper vanlig svinn gjennom', () => {
  test('smaa kroner paa stort avvik meldes ikke', () => {
    // Soel, kanner som toemmes og feilslag ligger i det samme gapet, og
    // de er ikke noe butikksjefen kan slaa inn.
    const v = lagKaffevarsel(som({
      kassaOmsetningKr: 10_000, kassaBruttoKr: 8_000, // 80 %
      regnskapOmsetningKr: 10_000, regnskapBruttoKr: 7_000, // 70 %, altsaa 10 pp
    }))
    expect(v, '10 pp, men bare 1 000 kr').toBeNull()
  })

  test('smaa avvik paa store kroner meldes heller ikke', () => {
    const v = lagKaffevarsel(som({
      kassaOmsetningKr: 1_000_000, kassaBruttoKr: 800_000, // 80 %
      regnskapOmsetningKr: 1_000_000, regnskapBruttoKr: 780_000, // 78 %, 2 pp
    }))
    expect(v, '20 000 kr, men bare 2 pp').toBeNull()
  })

  test('begge over terskelen gir varsel', () => {
    expect(lagKaffevarsel(som({
      kassaOmsetningKr: 200_000, kassaBruttoKr: 160_000, // 80 %
      regnskapOmsetningKr: 200_000, regnskapBruttoKr: 148_000, // 74 %, 6 pp, 12 000 kr
    }))).not.toBeNull()
  })
})

describe('grunnlaget maa holde', () => {
  test('ingen omsetning gir ingen margin, og dermed ingen dom', () => {
    expect(lagKaffevarsel(som({ regnskapOmsetningKr: 0 }))).toBeNull()
    expect(lagKaffevarsel(som({ kassaOmsetningKr: 0 }))).toBeNull()
  })

  test('brutto stoerre enn omsetningen er en feil i grunnlaget', () => {
    // Samme vakt som `v_bp_status_avdeling`. DRIFT viste -3536 % foer den
    // fantes.
    expect(lagKaffevarsel(som({ regnskapBruttoKr: 999_999 }))).toBeNull()
  })

  test('uten en vanligste vare staar varselet, men uten antall', () => {
    // Teksten maa fortsatt vaere sann og handlingen fortsatt mulig.
    const v = lagKaffevarsel(som({ vanligste: null }))
    expect(v).not.toBeNull()
    expect(v!.kopper).toBeNull()
    expect(v!.tekst).toContain('Slå inn påfyllene som er gitt bort')
    expect(v!.tekst).not.toMatch(/Slå inn \d/)
  })

  test('kr per kopp paa null gir ikke deling paa null', () => {
    const v = lagKaffevarsel(som({
      vanligste: { varenavn: 'PÅFYLL KAFFE MEDIUM', krPerKopp: 0 },
    }))
    expect(v!.kopper).toBeNull()
  })
})

describe('kopper per avtalekunde per dag', () => {
  test('Lone laa paa 0,36 - det er ikke en kaffeavtale noen ville kjopt', () => {
    expect(kopperPerAvtaleDag(7257, 95, 213)).toBe(0.36)
  })

  test('og lander paa 1,31 naar de manglende legges til', () => {
    // Laguneparken laa paa 1,47 med like mange avtaler. Det er den
    // kontrollen som gjor anslaget troverdig.
    expect(kopperPerAvtaleDag(7257 + 19_068, 95, 213)).toBe(1.3)
    expect(kopperPerAvtaleDag(29_398, 94, 213)).toBe(1.47)
  })

  test('null avtaler eller null dager gir ingen brok', () => {
    expect(kopperPerAvtaleDag(100, 0, 213)).toBeNull()
    expect(kopperPerAvtaleDag(100, 95, 0)).toBeNull()
  })
})
