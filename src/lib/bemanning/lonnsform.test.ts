import { describe, expect, test } from 'vitest'
import { blandetLonnsform, type VaktRad } from './lonnsform'

const v = (navn: string | null, timelonnet: boolean | null, fra = 8, til = 16): VaktRad =>
  ({ navn, timelonnet, fra_time: fra, til_time: til })

describe('blandet lønnsform på samme navn', () => {
  test('fire fastlønn og én glemt timelønn blir meldt', () => {
    // Lone man–fre er fem rader. Rettes fire av dem, sier ingenting på
    // skjermen fra om den femte: sortert etter navn og ukedag ser det
    // ut som om alt er i orden.
    const funn = blandetLonnsform([
      v('Lone', false), v('Lone', false), v('Lone', false), v('Lone', false),
      v('Lone', true),
    ])
    expect(funn).toHaveLength(1)
    expect(funn[0].navn).toBe('Lone')
    expect(funn[0].fastlonnede).toBe(4)
    expect(funn[0].timelonnede).toBe(1)
    expect(funn[0].flertall, 'flertallet sier hvilken vei rettingen gaar').toBe('fastlønn')
    expect(funn[0].timerIMindretall, 'én vakt på åtte timer').toBe(8)
  })

  test('ensartet lønnsform er ikke et funn, uansett hvilken', () => {
    // KANARIFUGL: melder denne noe, staar det et varsel paa hver eneste
    // stasjon - og da leser ingen det naar det gjelder.
    expect(blandetLonnsform([v('Lone', true), v('Lone', true)])).toEqual([])
    expect(blandetLonnsform([v('Lone', false), v('Lone', false)])).toEqual([])
  })

  test('to ulike personer blandes ikke sammen', () => {
    expect(blandetLonnsform([v('Lone', true), v('Bjørn', false)])).toEqual([])
  })

  test('samme navn skrevet ulikt spørres det om', () => {
    // «Ola Nordmann» og «ola  nordmann» er verdt et spørsmål. Er det to
    // personer, er svaret nei, og ingenting er ødelagt — funksjonen
    // retter aldri noe selv.
    const funn = blandetLonnsform([v('Ola Nordmann', true), v('ola  nordmann', false)])
    expect(funn).toHaveLength(1)
    expect(funn[0].navn, 'navnet vises slik det foerst ble skrevet').toBe('Ola Nordmann')
  })

  test('rader uten navn hoppes over', () => {
    // Da finnes det ikke noe aa spoerre om, og et varsel uten navn er
    // umulig aa foelge opp.
    expect(blandetLonnsform([v(null, true), v(null, false), v('  ', true)])).toEqual([])
  })

  test('timelonnet: null teller som fastlønn, slik resten av koden gjør', () => {
    // `.filter((f) => f.timelonnet)` behandler null og false likt. Gjorde
    // ikke denne det samme, ville den meldt funn paa rader som resten av
    // systemet regner som ensartede.
    expect(blandetLonnsform([v('Lone', null), v('Lone', false)])).toEqual([])
    expect(blandetLonnsform([v('Lone', null), v('Lone', true)])).toHaveLength(1)
  })

  test('størst avvik først', () => {
    // Den med flest timer paa spill er den som haster.
    const funn = blandetLonnsform([
      v('Lone', true, 8, 10), v('Lone', false),
      v('Bjørn', true, 5, 16), v('Bjørn', false),
    ])
    expect(funn.map((f) => f.navn)).toEqual(['Bjørn', 'Lone'])
    expect(funn[0].timerIMindretall).toBe(11)
  })

  test('mindretallet måles i timer, ikke i rader', () => {
    // Én rad paa elleve timer veier tyngre enn to paa to.
    const funn = blandetLonnsform([
      v('Lone', true, 5, 16), v('Lone', false, 8, 10), v('Lone', false, 8, 10),
    ])
    expect(funn[0].flertall).toBe('fastlønn')
    expect(funn[0].timerIMindretall, 'mindretallet er den ene lange vakten').toBe(11)
  })
})
