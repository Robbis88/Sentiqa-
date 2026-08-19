import { describe, it, expect } from 'vitest'
import { avstem, kanSnuStasjon, TERSKEL_TIMER, type Kildetimer } from './avstem'

const k = (nr: string, navn: string, minutter: number): Kildetimer =>
  ({ ansattNr: nr, navn, minutter })

describe('avstem', () => {
  it('gir null avvik når kildene er enige', () => {
    const svar = avstem([k('1009', 'Kari', 480)], [k('1009', 'Kari', 480)])
    expect(svar.avvikTimer).toBe(0)
    expect(svar.linjer[0].avvikProsent).toBe(0)
    expect(svar.antallOverTerskel).toBe(0)
  })

  it('summerer flere vakter per ansatt', () => {
    const svar = avstem(
      [k('1009', 'Kari', 480), k('1009', 'Kari', 300)],
      [k('1009', 'Kari', 780)],
    )
    expect(svar.linjer[0].importTimer).toBe(13)
    expect(svar.linjer[0].tabletTimer).toBe(13)
  })

  it('regner avviket som tablet minus import', () => {
    const svar = avstem([k('1009', 'Kari', 480)], [k('1009', 'Kari', 540)])
    expect(svar.linjer[0].avvikTimer).toBe(1)
    expect(svar.linjer[0].avvikProsent).toBe(12.5)
  })

  // En som ikke har begynt aa stemple er ikke et avvik paa null - hun er
  // grunnen til at stasjonen ikke kan snus ennaa.
  it('tar med den som bare finnes i importen', () => {
    const svar = avstem([k('1010', 'Ola', 600)], [])
    expect(svar.linjer[0].bareI).toBe('import')
    expect(svar.linjer[0].tabletTimer).toBe(0)
  })

  it('tar med den som bare har stemplet', () => {
    const svar = avstem([], [k('1010', 'Ola', 600)])
    expect(svar.linjer[0].bareI).toBe('tablet')
    expect(svar.linjer[0].avvikProsent).toBeNull()
  })

  it('lar navnet fra stemplingen vinne, fordi det er ferskest', () => {
    const svar = avstem([k('1009', 'Kari Hansen', 60)], [k('1009', 'Kari Nordmann', 60)])
    expect(svar.linjer[0].navn).toBe('Kari Nordmann')
  })

  it('sorterer største avvik øverst', () => {
    const svar = avstem(
      [k('1', 'A', 600), k('2', 'B', 600), k('3', 'C', 600)],
      [k('1', 'A', 610), k('2', 'B', 900), k('3', 'C', 600)],
    )
    expect(svar.linjer.map((l) => l.ansattNr)).toEqual(['2', '1', '3'])
  })

  // Avrunding skal ikke telle. easy@work runder til naermeste fem
  // minutter; over tjue vakter blir det noen minutter uansett.
  it('teller ikke avvik under terskelen', () => {
    const svar = avstem([k('1009', 'Kari', 600)], [k('1009', 'Kari', 612)])
    expect(svar.linjer[0].avvikTimer).toBeLessThanOrEqual(TERSKEL_TIMER)
    expect(svar.antallOverTerskel).toBe(0)
  })

  it('teller avvik over terskelen', () => {
    const svar = avstem([k('1009', 'Kari', 600)], [k('1009', 'Kari', 640)])
    expect(svar.antallOverTerskel).toBe(1)
  })
})

describe('kanSnuStasjon', () => {
  it('sier ja når begge kilder har timer og ingen avviker', () => {
    expect(kanSnuStasjon(avstem(
      [k('1', 'A', 600), k('2', 'B', 480)],
      [k('1', 'A', 600), k('2', 'B', 480)],
    ))).toBe(true)
  })

  it('sier nei når nettbrettet ikke har timer ennå', () => {
    expect(kanSnuStasjon(avstem([k('1', 'A', 600)], []))).toBe(false)
  })

  it('sier nei når importen mangler — da er det ingenting å avstemme mot', () => {
    expect(kanSnuStasjon(avstem([], [k('1', 'A', 600)]))).toBe(false)
  })

  // Det viktigste tilfellet: totalen stemmer, men to personer faar feil
  // lonn. En sjekk paa summen alene ville sagt ja.
  it('sier nei når to avvik opphever hverandre i sum', () => {
    const svar = avstem(
      [k('1', 'A', 600), k('2', 'B', 600)],
      [k('1', 'A', 720), k('2', 'B', 480)],
    )
    expect(svar.avvikTimer).toBe(0)
    expect(kanSnuStasjon(svar)).toBe(false)
  })
})
