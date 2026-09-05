import { describe, it, expect } from 'vitest'
import { aarsgrunnlagFra, finnAaret, type Matbudsjett } from './delingsfil-aar'
import type { Delingsrad } from '@/lib/parsere/delingsfil'

// =====================================================================
// KELSARS EGNE TALL, OG DE STEMMER IKKE PAA KRONA.
//
//   stasjon        BP25 Mat        delingsfila     avvik
//   Laguneparken   4 651 907,99    4 651 908,00         0,01
//   Varden         2 164 028,88    2 119 896,31    44 132,57
//   Boenes         1 721 635,41    1 700 095,81    21 539,60
//
// BP-fila heter `_v2` - den er revidert etter at delingsfila ble laget.
// Foerste utgave av `finnAaret` krevde EKSAKT likhet og skrev derfor
// timer for en av tre stasjoner. Naa velges aaret paa NAERHET.
// =====================================================================

const rad = (butikknavn: string, timebudsjett: number, matomsetning: number): Delingsrad =>
  ({ butikknavn, timebudsjett, matomsetning, kostPerTime: null, kronebudsjett: null })

const FILA: Delingsrad[] = [
  rad('SHELL BØNES', 6654, 1700095.8050394272),
  rad('SHELL LAGUNEPARKEN', 13212.84, 4651907.996552096),
  rad('SHELL VARDEN', 8957.42, 2119896.3105635946),
]

// Navnene kobles av `koblePaaNavn` - «SHELL BØNES» mot «St1 Bønes».
const NAVN = new Map([
  ['shell bønes', 'bones'],
  ['shell laguneparken', 'laguneparken'],
  ['shell varden', 'varden'],
])

const budsjett = (per: Record<number, Record<string, number>>): Matbudsjett =>
  new Map(Object.entries(per).map(([ar, s]) => [Number(ar), new Map(Object.entries(s))]))

// De EKTE tallene: BP25 er revidert, BP26 er et helt annet aar.
const BASEN = budsjett({
  2025: { bones: 1721635.41, laguneparken: 4651907.99, varden: 2164028.88 },
  2026: { bones: 1900000, laguneparken: 9276278, varden: 4969234 },
})

describe('finnAaret', () => {
  it('KANARIFUGL: en revidert BP skal ikke felle plasseringen', () => {
    // To av tre stasjoner avviker med 1-2 % fordi BP-en ble revidert
    // etter at delingsfila ble laget. Krever koden eksakt likhet, faar
    // bare EN stasjon timer - og de to andre meldes som "ukjente", som
    // de ikke er.
    const svar = finnAaret(FILA, NAVN, BASEN)
    expect(svar.ar).toBe(2025)
    if (svar.ar === null) throw new Error('skulle funnet aaret')
    expect(svar.kobling.size).toBe(3)
    expect(svar.ukoblet).toEqual([])
    expect(svar.avvikPst).toBeLessThan(2)
    expect(svar.avvikPst).toBeGreaterThan(0)
  })

  it('velger årgangen som ligger nærmest', () => {
    const svar = finnAaret(FILA, NAVN, BASEN)
    expect(svar.ar).toBe(2025)
  })

  it('KANARIFUGL: for langt unna er ingen plassering', () => {
    // «Naermest» er ikke det samme som «naer nok». En delingsfil for et
    // aar vi ikke har BP for, ville ellers blitt hengt paa naermeste
    // aargang uansett hvor galt det passet.
    const feilAar = budsjett({ 2026: { bones: 1900000, laguneparken: 9276278, varden: 4969234 } })
    const svar = finnAaret(FILA, NAVN, feilAar)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/for langt unna/)
  })

  it('KANARIFUGL: to årganger som passer nesten like godt gir ingen plassering', () => {
    // Da er valget en gjetning, og et timebudsjett paa feil aar er verre
    // enn ingen: planleggeren ville fordelt tallene og sett normal ut.
    const like = budsjett({
      2025: { bones: 1721635.41, laguneparken: 4651907.99, varden: 2164028.88 },
      2024: { bones: 1721600, laguneparken: 4651900, varden: 2164000 },
    })
    const svar = finnAaret(FILA, NAVN, like)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/nesten like godt/)
  })

  it('sier fra når ingen BP er lastet', () => {
    const svar = finnAaret(FILA, NAVN, new Map())
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/BP-en må komme først/)
  })

  it('sier fra når ingen stasjon lot seg koble', () => {
    const svar = finnAaret(FILA, new Map(), BASEN)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/kunne kobles til en stasjon/)
  })

  it('lar stasjoner vi ikke driver være — de er ikke en feil', () => {
    // St1 sender ofte hele klyngen.
    const medFremmed = [...FILA, rad('SHELL EN ANNEN', 5000, 123456)]
    const svar = finnAaret(medFremmed, NAVN, BASEN)
    expect(svar.ar).toBe(2025)
    if (svar.ar === null) throw new Error('skulle funnet aaret')
    expect(svar.ukoblet).toEqual(['SHELL EN ANNEN'])
  })
})

// =====================================================================
// AARET NAAR «Timer»-ARKET IKKE FINNES
//
// 2026-fila har bare Mat og Vask. Hele importen leste aaret av
// `r.stasjoner` - Timer-radene - og den lista er TOM for den fila.
// Svaret ble «Ingen av stasjonene i delingsfila () kunne kobles», med
// tom parentes, fordi det ikke var noen aa nevne.
//
// Tallet finnes: Mat-arkets «Budsjettert salg» ER Timer-arkets
// «Budsjettert matomsetning».
// =====================================================================
describe('aarsgrunnlagFra', () => {
  const kast = (butikknavn: string, nivaa: 'avdeling' | 'vareomrade', bud: number | null) => ({
    butikknavn, nivaa, kode: nivaa === 'avdeling' ? '120' : '10', navn: 'MAT',
    kastPst: 0.08, kastKr: 1000, historiskSalg: null, budsjettertSalg: bud, usynligKr: null,
  })

  it('bruker «Timer»-radene naar de finnes', () => {
    const ut = aarsgrunnlagFra({ stasjoner: FILA, kastbudsjett: [kast('SHELL X', 'avdeling', 9)] })
    expect(ut).toBe(FILA)
  })

  it('faller tilbake paa Mat-arkets budsjetterte salg', () => {
    const ut = aarsgrunnlagFra({
      stasjoner: [],
      kastbudsjett: [kast('SHELL LAGUNEPARKEN', 'avdeling', 4651908)],
    })
    expect(ut).toEqual([{ butikknavn: 'SHELL LAGUNEPARKEN', matomsetning: 4651908 }])
  })

  // KANARIFUGL: undergruppene er ikke aarsgrunnlag. Bakeriets budsjett
  // er en broekdel av matomsetningen, og seks slike i snittet ville
  // gjort avviket mot BP-en meningsloest - og med det aarsvalget.
  it('KANARIFUGL: undergruppene teller ikke', () => {
    const ut = aarsgrunnlagFra({
      stasjoner: [],
      kastbudsjett: [
        kast('SHELL LAGUNEPARKEN', 'avdeling', 4651908),
        kast('SHELL LAGUNEPARKEN', 'vareomrade', 1010167),
      ],
    })
    expect(ut).toHaveLength(1)
    expect(ut[0].matomsetning).toBe(4651908)
  })

  // Uten tallet kan raden ikke plassere fila, og en rad uten
  // matomsetning i grunnlaget ville trukket snittet mot ingenting.
  it('hopper over rader uten budsjettert salg', () => {
    expect(aarsgrunnlagFra({ stasjoner: [], kastbudsjett: [kast('SHELL X', 'avdeling', null)] }))
      .toEqual([])
  })

  // HELE VEIEN: grunnlaget fra Mat-arket skal faktisk finne aaret.
  it('finner aaret fra Mat-arket alene', () => {
    const ut = aarsgrunnlagFra({
      stasjoner: [],
      kastbudsjett: FILA.map((f) => kast(f.butikknavn, 'avdeling', f.matomsetning)),
    })
    expect(finnAaret(ut, NAVN, BASEN).ar).toBe(2025)
  })
})
