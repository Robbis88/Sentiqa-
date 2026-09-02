import { describe, expect, test } from 'vitest'
import { hoppetNotat } from './hoppede'

// =====================================================================
// EN BP-MAANED SOM BLE HOPPET OVER SKAL SES
//
// `lagreBp` skriver ikke `bp_*`-linjer for maaneder som alt er avlagt i
// regnskapet. Det er RIKTIG - en avlagt maaned baerer sitt eget budsjett
// - men det skjedde i stillhet.
//
// Det er grunnen til at BP maa lastes opp FOER regnskapet, en regel som
// bare har bodd i hodet paa den som visste. Laster en ny kjede opp i
// motsatt rekkefoelge, faar de en ramme uten de maanedene, og sida ser
// like ferdig ut.
// =====================================================================

describe('hoppetNotat', () => {
  test('ingenting hoppet gir ingen merknad', () => {
    // Ellers ville hver eneste BP-import faatt en merknad, og da leses
    // den ikke naar den betyr noe.
    expect(hoppetNotat([], 12)).toBeNull()
    expect(hoppetNotat([{ stasjon: '4177', maaneder: [] }], 12)).toBeNull()
  })

  test('KANARIFUGL: maanedene navngis, ikke bare telles', () => {
    // «2 maaneder hoppet over» tvinger leseren til aa gjette hvilke, og
    // da blir merknaden noe man ser bort fra. Samme grunn som i
    // `stasjonsdekning.ts`.
    const n = hoppetNotat([{ stasjon: '4177', maaneder: [1, 2] }], 12)!
    expect(n).toContain('januar')
    expect(n).toContain('februar')
    expect(n).toContain('4177')
  })

  test('maanedene staar i rekkefoelge, og stasjonene sortert', () => {
    // To kjoeringer av samme fil skal gi samme tekst.
    const n = hoppetNotat([
      { stasjon: '9467', maaneder: [3, 1] },
      { stasjon: '4177', maaneder: [2] },
    ], 12)!
    expect(n.indexOf('4177')).toBeLessThan(n.indexOf('9467'))
    expect(n.indexOf('januar')).toBeLessThan(n.indexOf('mars'))
  })

  test('KANARIFUGL: alle maaneder hoppet sies med egne ord', () => {
    // Da er BP-en i praksis uten virkning, og det er en ANNEN sak enn at
    // et par maaneder alt var avlagt. Sies de likt, ser det verste
    // tilfellet ut som det normale.
    const alle = hoppetNotat([{ stasjon: '4177', maaneder: [1,2,3,4,5,6,7,8,9,10,11,12] }], 12)!
    const noen = hoppetNotat([{ stasjon: '4177', maaneder: [1, 2] }], 12)!
    expect(alle).toMatch(/Ingen av maanedene|Ingen av månedene/)
    expect(noen).not.toMatch(/Ingen av maanedene|Ingen av månedene/)
  })

  test('merknaden sier hva man skal gjoere annerledes', () => {
    // Uten det er den bare en observasjon. Rekkefoelgen BP -> regnskap er
    // hele poenget.
    expect(hoppetNotat([{ stasjon: '4177', maaneder: [1] }], 12)).toMatch(/BP før regnskapet/)
  })

  test('en fil uten maaneder gir ikke «alle hoppet»', () => {
    // `maanederIFila = 0` er ikke det samme som at alt er hoppet over.
    const n = hoppetNotat([{ stasjon: '4177', maaneder: [1] }], 0)!
    expect(n).not.toMatch(/Ingen av/)
  })
})
