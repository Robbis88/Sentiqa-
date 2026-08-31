import { describe, it, expect } from 'vitest'
import { finnAaret, type Matbudsjett } from './delingsfil-aar'
import type { Delingsrad } from '@/lib/parsere/delingsfil'

// =====================================================================
// Tallene er Kelsars egne. `Budsjettert matomsetning` i delingsfila skal
// vaere BP-ens Mat paa krona:
//
//   SHELL LAGUNEPARKEN   4 651 908  =  BP 2025 kode 120
//   SHELL VARDEN         2 119 896
//   SHELL BOENES         1 700 096
// =====================================================================

const rad = (butikknavn: string, timebudsjett: number, matomsetning: number): Delingsrad =>
  ({ butikknavn, timebudsjett, matomsetning, kostPerTime: null, kronebudsjett: null })

const FILA: Delingsrad[] = [
  rad('SHELL BØNES', 6654, 1700095.8050394272),
  rad('SHELL LAGUNEPARKEN', 13212.84, 4651907.996552096),
  rad('SHELL VARDEN', 8957.42, 2119896.3105635946),
]

const NAVN = new Map([
  ['shell bønes', 'bones'],
  ['shell laguneparken', 'laguneparken'],
  ['shell varden', 'varden'],
])

const budsjett = (per: Record<number, Record<string, number>>): Matbudsjett =>
  new Map(Object.entries(per).map(([ar, s]) => [Number(ar), new Map(Object.entries(s))]))

const BASEN = budsjett({
  2025: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
  2026: { bones: 1_900_000, laguneparken: 5_000_000, varden: 2_300_000 },
})

describe('finnAaret', () => {
  it('finner året ved å kjenne igjen matomsetningen', () => {
    const svar = finnAaret(FILA, NAVN, BASEN)
    expect(svar.ar).toBe(2025)
  })

  it('KANARIFUGL: ALLE stasjonene må treffe samme år', () => {
    // Treffer to av tre, er det like sannsynlig at fila hoerer til et
    // annet aar som at den tredje raden avviker. Et timebudsjett paa feil
    // aar er verre enn ingen: planleggeren ville fordelt fjoraarets timer
    // paa aarets maaneder, og planen ville sett helt normal ut.
    const nesten = budsjett({
      2025: { bones: 1700095.81, laguneparken: 4651908, varden: 9_999_999 },
    })
    const svar = finnAaret(FILA, NAVN, nesten)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/Fant ingen BP-årgang/)
  })

  it('KANARIFUGL: toleransen er én krone, ikke «omtrent»', () => {
    // Tallene kommer fra samme kilde og skal vaere identiske. Slingring
    // her ville bare gjort det lettere aa treffe FEIL aar.
    const tiKronerFeil = budsjett({
      2025: { bones: 1700105.81, laguneparken: 4651908, varden: 2119896.31 },
    })
    expect(finnAaret(FILA, NAVN, tiKronerFeil).ar).toBeNull()

    const enKroneFeil = budsjett({
      2025: { bones: 1700096.5, laguneparken: 4651908, varden: 2119896.31 },
    })
    expect(finnAaret(FILA, NAVN, enKroneFeil).ar).toBe(2025)
  })

  it('KANARIFUGL: to årganger som passer like godt gir INGEN plassering', () => {
    // To identiske budsjettaar er usannsynlig, men ikke umulig - og da
    // er «velg det nyeste» en gjetning forkledd som en regel.
    const tvetydig = budsjett({
      2025: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
      2026: { bones: 1700095.81, laguneparken: 4651908, varden: 2119896.31 },
    })
    const svar = finnAaret(FILA, NAVN, tvetydig)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/2025 og 2026/)
  })

  it('sier fra når ingen stasjon hører til kjeden', () => {
    const svar = finnAaret(FILA, new Map(), BASEN)
    expect(svar.ar).toBeNull()
    expect(svar.ar === null && svar.grunn).toMatch(/hører til denne kjeden/)
  })

  it('krever bare de stasjonene kjeden faktisk har', () => {
    // Delingsfila kan inneholde stasjoner vi ikke driver - St1 sender
    // ofte hele klyngen. De skal ikke hindre plassering.
    const medFremmed = [...FILA, rad('SHELL EN ANNEN', 5000, 123456)]
    expect(finnAaret(medFremmed, NAVN, BASEN).ar).toBe(2025)
  })
})
