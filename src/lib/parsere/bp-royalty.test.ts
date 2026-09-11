import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { avstemming, lesRoyaltysatser, skalLagres } from './bp-royalty'

// =====================================================================
// «Cluster data» fra BP26. Tallene er Kelsars egne, slik at de kan
// krysses mot fila — og slik at avstemmingen maaler noe ekte.
// =====================================================================

const kolonne = (n: number): string => {
  let ut = ''
  while (n > 0) { const r = (n - 1) % 26; ut = String.fromCharCode(65 + r) + ut; n = (n - r - 1) / 26 }
  return ut
}

function rad(nr: number, celler: (string | number | null)[]): string {
  const c = celler.map((v, i) => {
    if (v === null) return ''
    const r = `${kolonne(i + 1)}${nr}`
    return typeof v === 'number'
      ? `<c r="${r}"><v>${v}</v></c>`
      : `<c r="${r}" t="str"><f>X</f><v>${v}</v></c>`
  }).join('')
  return `<row r="${nr}">${c}</row>`
}

function bok(rader: string, arknavn = 'Cluster data'): Uint8Array {
  return zipSync({
    'xl/workbook.xml': strToU8(
      `<?xml version="1.0"?><workbook xmlns:r="r"><sheets>`
      + `<sheet name="${arknavn}" sheetId="1" r:id="rId1"/></sheets></workbook>`),
    'xl/_rels/workbook.xml.rels': strToU8(
      `<?xml version="1.0"?><Relationships>`
      + `<Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>`),
    'xl/sharedStrings.xml': strToU8('<?xml version="1.0"?><sst count="0"/>'),
    'xl/worksheets/sheet1.xml': strToU8(
      `<?xml version="1.0"?><worksheet><sheetData>${rader}</sheetData></worksheet>`),
  })
}

// Kolonne 1 er tom i arket; etikett/verdi ligger i 2 og 3, og aaret i 7/8.
const KELSAR = [
  rad(1, [null, null, null, null, null, null, 'Navn på selskap', 'KELSAR BIL AS']),
  rad(3, [null, null, null, null, null, null, 'År', 2026]),
  rad(4, [null, 'Sum CR salg', 68249457.10348654]),
  rad(5, [null, 'Hvorav omsetning Bilvask og Selvvask', 8553540.421993729]),
  rad(6, [null, 'Hvorav omsetning Pant', 349341.55]),
  rad(7, [null, 'Bruttofortjeneste CR salg', 33775958.21003566]),
  rad(16, [null, 'Sum Royalty', 10093457.901742566]),
  rad(17, [null, 'Hvorav royalty Bilvask og Selvvask', 4158800.3885931913]),
  rad(18, [null, 'Royalty lav sats (årlig)', 0.10000000000000159]),
  rad(19, [null, 'Royalty lav sats (replan)', 0.10000000000000167]),
  rad(20, [null, 'Royalty høy sats (bilvask og selvvask)', 0.6]),
  rad(21, [null, 'Royalty pant', 0]),
].join('')

describe('lesRoyaltysatser', () => {
  it('leser de tre satsene og aaret', () => {
    const r = lesRoyaltysatser(bok(KELSAR))!
    expect(r).not.toBeNull()
    expect(r.lavSats).toBe(0.1)
    expect(r.hoySatsVask).toBe(0.6)
    expect(r.pantSats).toBe(0)
    expect(r.ar).toBe(2026)
  })

  it('runder bort formelstoeyen', () => {
    // Arket leverer 0.10000000000000159. Kolonnen i basen er numeric(6,5),
    // og en royaltysats har ikke seksten desimaler.
    const r = lesRoyaltysatser(bok(KELSAR))!
    expect(Number.isInteger(r.lavSats * 1e5)).toBe(true)
  })

  it('tar den AARLIGE satsen, ikke replan', () => {
    const medUlikReplan = KELSAR.replace(
      `<v>0.10000000000000167</v>`, `<v>0.085</v>`)
    const r = lesRoyaltysatser(bok(medUlikReplan))!
    expect(r.lavSats).toBe(0.1)
  })

  it('leser kontrolltallene', () => {
    const r = lesRoyaltysatser(bok(KELSAR))!
    expect(r.sumRoyalty).toBeCloseTo(10093457.9, 0)
    expect(r.omsetningVask).toBeCloseTo(8553540.42, 0)
    expect(r.royaltyVask).toBeCloseTo(4158800.39, 0)
  })

  it('gir null naar arket ikke finnes', () => {
    expect(lesRoyaltysatser(bok(KELSAR, 'Timebudsjett Grunnlagsfil'))).toBeNull()
  })

  it('KANARI: gir null naar EN sats mangler, ikke en halvlest rad', () => {
    // En delvis lest sats er verre enn ingen: den ser komplett ut og
    // gir feil kroner i hver beregning som bruker den.
    const utenHoy = KELSAR.replace(
      `<c r="C20"><v>0.6</v></c>`, '')
    const r = lesRoyaltysatser(bok(utenHoy))
    expect(r).toBeNull()
  })
})

describe('avstemming', () => {
  it('BPs egne tall gaar opp paa oeret', () => {
    const a = avstemming(lesRoyaltysatser(bok(KELSAR))!)!
    expect(a).not.toBeNull()
    expect(a.stemmer).toBe(true)
    expect(Math.abs(a.avvikKr)).toBeLessThan(1)
  })

  it('KANARI: en feil sats faar avstemmingen til aa ryke', () => {
    // Uten denne maaler testen over ingenting.
    const feil = KELSAR.replace(`<v>0.10000000000000159</v>`, `<v>0.12</v>`)
    const a = avstemming(lesRoyaltysatser(bok(feil))!)!
    expect(a.stemmer).toBe(false)
  })

  it('gir null naar kontrolltallene mangler, i stedet for aa antyde', () => {
    const uten = KELSAR.replace(`<c r="C16"><v>10093457.901742566</v></c>`, '')
    expect(avstemming(lesRoyaltysatser(bok(uten))!)).toBeNull()
  })
})

describe('skalLagres', () => {
  it('lagrer satser som stemmer, uten aa si noe', () => {
    const b = skalLagres(lesRoyaltysatser(bok(KELSAR)))
    expect(b.lagre).toBe(true)
    expect(b.notat).toBeNull()
  })

  it('KANARI: satser som IKKE stemmer blir ikke lagret', () => {
    // Dette er regelen hele modulen finnes for. En sats ingen har proevd
    // er en sats hele systemet siden bygger kroneverdier paa.
    const feil = KELSAR.replace(`<v>0.10000000000000159</v>`, `<v>0.12</v>`)
    const b = skalLagres(lesRoyaltysatser(bok(feil)))
    expect(b.lagre).toBe(false)
    expect(b.notat).toMatch(/IKKE lagret/)
    expect(b.notat).toMatch(/Resten av BP-en er lagret/)
  })

  it('lagrer uproevde satser, men SIER at de er uproevde', () => {
    // «Uproevd» og «feil» er ikke det samme, og en import som tier om
    // forskjellen gjoer dem like.
    const uten = KELSAR.replace(`<c r="C16"><v>10093457.901742566</v></c>`, '')
    const b = skalLagres(lesRoyaltysatser(bok(uten)))
    expect(b.lagre).toBe(true)
    expect(b.notat).toMatch(/mangler kontrolltallene/)
  })

  it('sier ingenting naar fila ikke har satser i det hele tatt', () => {
    // BP25 baerer dem annerledes. Det er ikke en feil ved fila, og skal
    // ikke staa som en merknad paa importen.
    expect(skalLagres(null)).toEqual({ lagre: false, notat: null })
  })
})
