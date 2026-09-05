import { describe, it, expect } from 'vitest'
import {
  BP_TIL_REGNSKAP, BP_LONNSKODER, BP_ANDRE_PERSONAL, ukjenteLonnskoder,
} from './bp'
import { LONNSKONTI, ANDRE_PERSONALKONTI } from './maaned'

// Kodene som faktisk står i `regnskapslinjer` for `bp_kostnad`, hentet
// 2026-09-05. Alle 43, ikke et utvalg — en liste som bare inneholder de
// kjente ville aldri utløst vakten under.
const BP_KODER_I_BASEN = [
  '3705', '3750', '5010', '5012', '5090', '5400', '5401', '5917', '5932',
  '5945', '5961', '6110', '6270', '6275', '6312', '6315', '6410', '6420',
  '6510', '6520', '6570', '6600', '6601', '6610', '6611', '6612', '6640',
  '6650', '6710', '6730', '6731', '6732', '6740', '6810', '6900', '7140',
  '7309', '7410', '7510', '7531', '7770', '7780', '7790',
]

describe('BP-mappingen', () => {
  it('peker bare på konti som finnes på regnskapssiden', () => {
    for (const [bp, reg] of Object.entries(BP_TIL_REGNSKAP)) {
      expect(LONNSKONTI, `${bp} -> ${reg}`).toContain(reg)
    }
  })

  it('er én-til-én — to BP-koder kan ikke bli samme regnskapskonto', () => {
    const mål = Object.values(BP_TIL_REGNSKAP)
    expect(new Set(mål).size).toBe(mål.length)
  })

  // GRENSEN MÅ GÅ LIKT PÅ BEGGE SIDER. Regnskapet holder 590 utenfor
  // lønnskosten; BP-ens 59xx må derfor også ligge utenfor. Gjør den ikke
  // det, sammenlignes en avlagt måned uten pensjon med en åpen måned
  // med — og forskjellen leses som lønnsvekst.
  it('holder 59xx utenfor lønn, slik 590 er det', () => {
    for (const k of BP_ANDRE_PERSONAL) {
      expect(BP_LONNSKODER.has(k), k).toBe(false)
      expect(k.startsWith('59')).toBe(true)
    }
    expect(ANDRE_PERSONALKONTI).toContain('590')
  })
})

describe('ukjenteLonnskoder', () => {
  it('sier ingenting om kontoplanen slik den står i dag', () => {
    expect(ukjenteLonnskoder(BP_KODER_I_BASEN)).toEqual([])
  })

  // KANARIFUGL. Uten denne kan vakten slutte å se uten at noe blir rødt
  // — og en vakt som ikke ser, ser ut som en vakt som ikke finner noe.
  //
  // St1 utvidet fra 18 til over femti konti mellom BP25 og BP26. Neste
  // årgang kan ha en `5013`, og da skal den ROPE, ikke forsvinne ut av
  // budsjettet mens avviket ser ut som god kostnadsstyring.
  it('KANARIFUGL: en ny 5xxx-kode er et funn', () => {
    expect(ukjenteLonnskoder([...BP_KODER_I_BASEN, '5013'])).toEqual(['5013'])
  })

  it('bryr seg ikke om konti utenfor 5-serien', () => {
    expect(ukjenteLonnskoder(['6420', '7790', '3705'])).toEqual([])
  })

  it('nevner hver ukjent kode én gang', () => {
    expect(ukjenteLonnskoder(['5013', '5013', '5014'])).toEqual(['5013', '5014'])
  })
})
