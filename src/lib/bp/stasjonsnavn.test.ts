import { describe, it, expect } from 'vitest'
import { koblePaaNavn } from './stasjonsnavn'

// Kelsars faktiske navn: basen sier «St1 …», delingsfila sier «SHELL …».
const MINE = [
  { id: 'bones', navn: 'St1 Bønes' },
  { id: 'laguneparken', navn: 'St1 Laguneparken' },
  { id: 'varden', navn: 'St1 Varden' },
  { id: 'dale', navn: 'St1 Dale' },
  { id: 'lone', navn: 'St1 Lone' },
]

describe('koblePaaNavn', () => {
  it('kobler på tvers av kjedemerket', () => {
    const { kobling, ukoblet } = koblePaaNavn(MINE, [
      'SHELL BØNES', 'SHELL LAGUNEPARKEN', 'SHELL VARDEN',
    ])
    expect(kobling.get('shell bønes')).toBe('bones')
    expect(kobling.get('shell laguneparken')).toBe('laguneparken')
    expect(kobling.get('shell varden')).toBe('varden')
    expect(ukoblet).toEqual([])
  })

  it('tar eksakt treff når navnene er like', () => {
    const { kobling } = koblePaaNavn(MINE, ['St1 Dale', 'st1  lone  '])
    expect(kobling.get('st1 dale')).toBe('dale')
    expect(kobling.get('st1 lone')).toBe('lone')
  })

  it('KANARIFUGL: to stasjoner med samme stedsnavn kobles IKKE', () => {
    // «Shell Sentrum» og «St1 Sentrum» er to ulike stasjoner. Et treff
    // her ville vaert en gjetning, og timebudsjettet hadde havnet paa
    // feil sted uten at noe sa fra.
    const to = [
      { id: 'a', navn: 'Shell Sentrum' },
      { id: 'b', navn: 'St1 Sentrum' },
    ]
    const { kobling, ukoblet } = koblePaaNavn(to, ['ESSO SENTRUM'])
    expect(kobling.size).toBe(0)
    expect(ukoblet).toEqual(['ESSO SENTRUM'])
  })

  it('KANARIFUGL: eksakt treff vinner, den tvetydige meldes', () => {
    // Har fila BÅDE «SHELL VARDEN» og «ST1 VARDEN», er den siste
    // utvetydig min - navnet stemmer helt. Den foerste er da en ANNEN
    // stasjon som deler stedsnavn, og den skal ikke kobles.
    //
    // Foerste utgave av testen krevde at BEGGE ble avvist. Det var for
    // strengt: et eksakt navnetreff er sterkere bevis enn den korte
    // formen, og aa kaste det ville gjort en ekte kobling umulig.
    const { kobling, ukoblet } = koblePaaNavn(MINE, ['SHELL VARDEN', 'ST1 VARDEN'])
    expect(kobling.get('st1 varden')).toBe('varden')
    expect(kobling.has('shell varden')).toBe(false)
    expect(ukoblet).toEqual(['SHELL VARDEN'])
  })

  it('KANARIFUGL: to korte former som peker samme vei kobles ingen av dem', () => {
    // Uten et eksakt treff aa falle tilbake paa er tvetydigheten ekte,
    // og «foerste treff vinner» ville skjult den.
    const { kobling, ukoblet } = koblePaaNavn(MINE, ['SHELL VARDEN', 'ESSO VARDEN'])
    expect(kobling.size).toBe(0)
    expect(ukoblet).toEqual(['SHELL VARDEN', 'ESSO VARDEN'])
  })

  it('melder fra om navn som ikke finnes hos oss', () => {
    // St1 sender ofte hele klyngen. De fremmede skal ikke kobles, men de
    // skal heller ikke forsvinne i stillhet.
    const { kobling, ukoblet } = koblePaaNavn(MINE, ['SHELL BØNES', 'SHELL EN ANNEN'])
    expect(kobling.size).toBe(1)
    expect(ukoblet).toEqual(['SHELL EN ANNEN'])
  })

  it('takler navn på ett ord', () => {
    const { kobling } = koblePaaNavn([{ id: 'x', navn: 'Laguneparken' }], ['LAGUNEPARKEN'])
    expect(kobling.get('laguneparken')).toBe('x')
  })
})
