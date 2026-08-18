import { describe, expect, test } from 'vitest'
import { gjenstaar, overskrift, VIS_ANTALL, type Kilder } from './gjenstaar'

const tomt: Kilder = {
  sjekkpunkter: [], rutinerIgjen: 0, oppgaver: [], produksjon: null,
}
const med = (over: Partial<Kilder>): Kilder => ({ ...tomt, ...over })

const sjekk = (id: string, sporsmaal: string, kritisk = false, klokkeslett?: string) =>
  ({ id, sporsmaal, kritisk, klokkeslett })

describe('gjenstaar', () => {
  test('tomt skift gir tom liste', () => {
    expect(gjenstaar(tomt)).toEqual([])
  })

  test('kritisk først — det er kjøletemperaturer og mattilsynskrav', () => {
    const ut = gjenstaar(med({
      sjekkpunkter: [
        sjekk('a', 'Feie uteområdet', false, '08:00'),
        sjekk('b', 'Temperatur kjøl', true, '14:00'),
      ],
    }))
    expect(ut.map((g) => g.tekst)).toEqual(['Temperatur kjøl', 'Feie uteområdet'])
  })

  test('med klokkeslett før uten — det er mest på etterskudd', () => {
    const ut = gjenstaar(med({
      sjekkpunkter: [sjekk('a', 'Uten tid'), sjekk('b', 'Med tid', false, '10:00')],
    }))
    expect(ut.map((g) => g.tekst)).toEqual(['Med tid', 'Uten tid'])
  })

  test('tidligst først blant dem som har tidspunkt', () => {
    const ut = gjenstaar(med({
      sjekkpunkter: [
        sjekk('a', 'Kveld', false, '20:00'),
        sjekk('b', 'Morgen', false, '06:00'),
        sjekk('c', 'Middag', false, '12:00'),
      ],
    }))
    expect(ut.map((g) => g.tekst)).toEqual(['Morgen', 'Middag', 'Kveld'])
  })

  test('rutinene samles til én linje — femten linjer er en vegg', () => {
    const ut = gjenstaar(med({ rutinerIgjen: 15 }))
    expect(ut).toHaveLength(1)
    expect(ut[0].tekst).toBe('15 rutiner igjen')
    expect(ut[0].sti).toBe('/rutiner')
  })

  test('én rutine bøyes riktig', () => {
    expect(gjenstaar(med({ rutinerIgjen: 1 }))[0].tekst).toBe('1 rutine igjen')
  })

  test('ingen rutiner igjen gir ingen linje', () => {
    expect(gjenstaar(med({ rutinerIgjen: 0 }))).toEqual([])
  })

  test('fullførte oppgaver teller ikke', () => {
    const ut = gjenstaar(med({
      oppgaver: [
        { id: '1', tittel: 'Gjort', fullfort: true, frist: null },
        { id: '2', tittel: 'Ikke gjort', fullfort: false, frist: null },
      ],
    }))
    expect(ut.map((g) => g.tekst)).toEqual(['Ikke gjort'])
  })

  test('produksjon i rute er ikke et gjøremål', () => {
    expect(gjenstaar(med({ produksjon: { plan: 100, lagd: 100 } }))).toEqual([])
    expect(gjenstaar(med({ produksjon: { plan: 100, lagd: 120 } }))).toEqual([])
  })

  test('produksjon som ligger etter, sier hvor mye', () => {
    const ut = gjenstaar(med({ produksjon: { plan: 100, lagd: 60 } }))
    expect(ut[0].tekst).toBe('40 produkter igjen å lage')
  })

  test('en plan på null gir ingen linje — ikke «0 produkter igjen»', () => {
    expect(gjenstaar(med({ produksjon: { plan: 0, lagd: 0 } }))).toEqual([])
  })

  test('hvert gjøremål har et sted å gå', () => {
    const ut = gjenstaar(med({
      sjekkpunkter: [sjekk('a', 'X', true)],
      rutinerIgjen: 2,
      oppgaver: [{ id: '1', tittel: 'Y', fullfort: false, frist: null }],
      produksjon: { plan: 10, lagd: 1 },
    }))
    expect(ut).toHaveLength(4)
    for (const g of ut) expect(g.sti.startsWith('/'), g.tekst).toBe(true)
  })

  test('id-ene er unike på tvers av kilder', () => {
    // Et sjekkpunkt og en oppgave kan ha samme id i basen.
    const ut = gjenstaar(med({
      sjekkpunkter: [sjekk('1', 'Sjekkpunkt')],
      oppgaver: [{ id: '1', tittel: 'Oppgave', fullfort: false, frist: null }],
    }))
    expect(new Set(ut.map((g) => g.id)).size).toBe(2)
  })
})

describe('overskrift', () => {
  test('tomt skift feires, ikke bare tømmes', () => {
    expect(overskrift(0)).toBe('Alt er gjort')
  })

  test('entall og flertall', () => {
    expect(overskrift(1)).toBe('1 ting igjen')
    expect(overskrift(3)).toBe('3 ting igjen')
  })
})

describe('VIS_ANTALL', () => {
  test('tre — har man ti foran seg, velger man ingen', () => {
    expect(VIS_ANTALL).toBe(3)
  })
})
