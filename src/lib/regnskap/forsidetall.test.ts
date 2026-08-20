import { describe, expect, test } from 'vitest'
import { forsidetall, type Regnskapslinje } from './forsidetall'

// =====================================================================
// Retning og dom er to forskjellige ting.
//
// Feilen som ble funnet i bølge 4B.2: lønn 12 % over budsjett sto med
// grønn pil opp på eierens forside. Tallet gikk opp, og forsiden leste
// «opp» som «bra».
//
// Testene her måler KOBLINGEN — at lønn er merket som kostnad — ikke
// regelen. Regelen er `motBudsjett`, og den har sine egne tester siden
// den ble skrevet. Det var aldri regelen som var feil; det var at
// forsiden ikke brukte den.
// =====================================================================

const linje = (seksjon: string, post: string, regnskap: number, budsjett: number): Regnskapslinje =>
  ({ seksjon, post, regnskap, budsjett })

/** Et komplett månedsregnskap, slik forsiden faktisk møter det. */
const maaned = (lonn: number): Regnskapslinje[] => [
  linje('omsetning', 'Omsetning totalt', 2_200_000, 2_000_000),
  linje('bruttofortjeneste', 'Bruttofortjeneste totalt', 800_000, 750_000),
  linje('resultat', 'Resultat ex 9900', 300_000, 250_000),
  linje('driftskostnader', 'Personalkostnad ex 9900', lonn, 500_000),
]

const finn = (linjer: Regnskapslinje[], kode: string) =>
  forsidetall(linjer).find((t) => t.kode === kode)!

describe('lønn mot budsjett', () => {
  test('lønn OVER budsjett er en dårlig nyhet, selv om tallet går opp', () => {
    const lonn = finn(maaned(560_000), 'lonn')
    expect(lonn.mot.avvik).toBeGreaterThan(0) // retningen: opp
    expect(lonn.mot.bra).toBe(false) // dommen: dårlig
  })

  test('lønn UNDER budsjett er en god nyhet, selv om tallet går ned', () => {
    const lonn = finn(maaned(440_000), 'lonn')
    expect(lonn.mot.avvik).toBeLessThan(0) // retningen: ned
    expect(lonn.mot.bra).toBe(true) // dommen: bra
  })

  test('retning og dom kan peke hver sin vei i samme bilde', () => {
    const alle = forsidetall(maaned(560_000))
    const oms = alle.find((t) => t.kode === 'omsetning')!
    const lonn = alle.find((t) => t.kode === 'lonn')!

    // Begge går OPP.
    expect(oms.mot.avvik).toBeGreaterThan(0)
    expect(lonn.mot.avvik).toBeGreaterThan(0)
    // Og dommene er motsatte. Det er hele poenget: en side som farger
    // etter fortegnet kan ikke vise begge disse riktig samtidig.
    expect(oms.mot.bra).toBe(true)
    expect(lonn.mot.bra).toBe(false)
  })

  test('to prosents bom er budsjettpresisjon, ikke en hendelse', () => {
    // 505 000 mot 500 000 er 1 %. Ingen dom, altså ingen farge.
    expect(finn(maaned(505_000), 'lonn').mot.bra).toBeNull()
  })

  test('uten budsjett er det ingenting å avvike fra', () => {
    const uten: Regnskapslinje[] = [
      { seksjon: 'driftskostnader', post: 'Personalkostnad ex 9900', regnskap: 500_000, budsjett: null },
    ]
    const lonn = finn(uten, 'lonn')
    expect(lonn.mot.avvikProsent).toBeNull()
    expect(lonn.mot.bra).toBeNull()
  })
})

describe('maalingen virker', () => {
  // KANARIFUGL. Postnavnene matches med regex mot regnskapet slik det
  // importeres. Slutter ett av dem aa treffe - en kolonne skifter navn,
  // en seksjon skrives om - forsvinner tallet i STILLHET fra forsiden.
  // Ingen feil, ingen tom plass: bare ett kort mindre enn i gaar.
  test('finner alle fire i et komplett regnskap', () => {
    const funnet = forsidetall(maaned(560_000)).map((t) => t.kode)
    expect(funnet).toEqual(['omsetning', 'brutto', 'resultat', 'lonn'])
  })

  test('tar ikke med et tall som ikke finnes', () => {
    expect(forsidetall([]).length).toBe(0)
  })

  // Rekkefolgen er informasjon: omsetning forst, loenn sist.
  test('rekkefolgen er den samme hver gang', () => {
    const snudd = [...maaned(560_000)].reverse()
    expect(forsidetall(snudd).map((t) => t.kode))
      .toEqual(forsidetall(maaned(560_000)).map((t) => t.kode))
  })
})
