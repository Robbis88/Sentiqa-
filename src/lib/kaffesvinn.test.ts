import { describe, expect, test } from 'vitest'
import { andelUjustert, lagKaffevarsel, type Kaffemaaling } from './kaffesvinn'

// `toLocaleString('nb-NO')` bruker U+00A0 mellom tusenene, ikke
// mellomrom. Haandskrevne strenger ser identiske ut og feiler likevel.
// Samme formatterer paa begge sider er eneste sikre maate.
const kr = (n: number) => `${n.toLocaleString('nb-NO')} kr`

// Roberts eget eksempel, 2026-08-23: «hvis kaffelojalitet er -2000 kr og
// kaffe/te er 2000, så er det rett justert. Er kaffe/te 1000 kr, mangler
// det justering på 1000 kr.»
const RETT: Kaffemaaling = {
  kaffeKr: 2000,
  lojalitetKr: -2000,
  manglerKr: 0,
  maaneder: 7,
  vanligste: { varenavn: 'PÅFYLL KAFFE MEDIUM', krPerKopp: 3.6 },
}

const som = (endring: Partial<Kaffemaaling>): Kaffemaaling => ({ ...RETT, ...endring })

describe('regelen: 130xx skal gå i null', () => {
  test('balanserer de, er alt registrert og ingenting meldes', () => {
    expect(lagKaffevarsel(RETT)).toBeNull()
  })

  test('overskudd meldes ikke — da er det ikke kopper som mangler', () => {
    // Mer talt enn ventet. Et varsel om aa slaa inn FLERE ville vaert
    // direkte feil.
    expect(lagKaffevarsel(som({ manglerKr: -8000, lojalitetKr: -20_000 }))).toBeNull()
  })

  test('mangler justering: teksten sier begge sidene av regnestykket', () => {
    const v = lagKaffevarsel(som({
      kaffeKr: 96_000, lojalitetKr: -65_000, manglerKr: 31_000,
    }))
    expect(v).not.toBeNull()
    expect(v!.tekst, 'manko paa kaffen').toContain(kr(96_000))
    expect(v!.tekst, 'det som ER slaatt inn').toContain(kr(65_000))
    expect(v!.tekst, 'differansen').toContain(kr(31_000))
  })

  test('varselet sier et ANTALL, ikke bare en sum', () => {
    // «31 000 kr mangler» er sant og ubrukelig.
    const v = lagKaffevarsel(som({
      kaffeKr: 96_000, lojalitetKr: -65_000, manglerKr: 31_000,
    }))!
    expect(v.kopper).toBe(Math.round(31_000 / 3.6))
    expect(v.tekst).toContain('PÅFYLL KAFFE MEDIUM')
    expect(v.tekst).toMatch(/Slå inn [\d\s ]+PÅFYLL/)
  })
})

describe('tersklene slipper vanlig svinn gjennom', () => {
  test('smaa kroner meldes ikke, uansett andel', () => {
    // Robert: «de har alltid litt svinn paa kaffe hver mnd.» Soel, kanner
    // som toemmes og feilslag ligger i det samme tallet.
    expect(lagKaffevarsel(som({
      kaffeKr: 3000, lojalitetKr: -1000, manglerKr: 2000,
    })), '200 % ujustert, men bare 2 000 kr').toBeNull()
  })

  test('stor sum paa liten andel meldes heller ikke', () => {
    expect(lagKaffevarsel(som({
      kaffeKr: 306_000, lojalitetKr: -300_000, manglerKr: 6000,
    })), '6 000 kr, men bare 2 % ujustert').toBeNull()
  })

  test('begge over terskelen gir varsel', () => {
    expect(lagKaffevarsel(som({
      kaffeKr: 56_000, lojalitetKr: -50_000, manglerKr: 6000,
    })), '6 000 kr og 12 % — under andelsgrensen').toBeNull()
    expect(lagKaffevarsel(som({
      kaffeKr: 60_000, lojalitetKr: -50_000, manglerKr: 10_000,
    })), '10 000 kr og 20 %').not.toBeNull()
  })

  test('ingen utdeling slaatt inn i det hele tatt: kronene alene avgjor', () => {
    // Da finnes ingen andel aa maale mot, men manko paa kaffen staar der
    // like fullt. Uten dette ville den verste stasjonen sluppet unna.
    const v = lagKaffevarsel(som({ kaffeKr: 40_000, lojalitetKr: 0, manglerKr: 40_000 }))
    expect(v).not.toBeNull()
    expect(v!.kopper).toBeGreaterThan(10_000)
  })
})

describe('grunnlaget maa holde', () => {
  test('uten en vanligste vare staar varselet, men uten antall', () => {
    const v = lagKaffevarsel(som({
      kaffeKr: 96_000, lojalitetKr: -65_000, manglerKr: 31_000, vanligste: null,
    }))
    expect(v).not.toBeNull()
    expect(v!.kopper).toBeNull()
    expect(v!.tekst).toContain('Slå inn påfyllene som er gitt bort')
    expect(v!.tekst).not.toMatch(/Slå inn \d/)
  })

  test('kr per kopp paa null gir ikke deling paa null', () => {
    const v = lagKaffevarsel(som({
      kaffeKr: 96_000, lojalitetKr: -65_000, manglerKr: 31_000,
      vanligste: { varenavn: 'PÅFYLL KAFFE MEDIUM', krPerKopp: 0 },
    }))
    expect(v!.kopper).toBeNull()
  })
})

describe('andelen som ikke er slaatt inn', () => {
  test('halvparten av utdelingen ujustert', () => {
    expect(andelUjustert(10_000, -20_000)).toBe(50)
  })

  test('KANARIFUGL: ingen registrert utdeling gir ingen andel', () => {
    // «100 %» ville vaert et paafunn, ikke en maaling — og et paafunn
    // som ser ut som et tall er verre enn ingen tall.
    expect(andelUjustert(10_000, 0)).toBeNull()
    expect(andelUjustert(10_000, 500)).toBeNull()
  })

  test('én desimal, saa den kan sammenliknes maaned for maaned', () => {
    expect(andelUjustert(1234, -10_000)).toBe(12.3)
  })
})
