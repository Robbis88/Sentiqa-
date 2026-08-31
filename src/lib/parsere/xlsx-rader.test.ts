import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { lesArk, type Celleverdi } from './xlsx-rader'

// =====================================================================
// Bygger en minimal xlsx i minnet. Å teste mot en ekte 11 MB-fil ville
// bundet testen til en fil som ikke ligger i repoet — og den ville ikke
// kunne vise hva som skjer med de formene vi IKKE har for hånden.
// =====================================================================

function bok(arkXml: string, delteStrenger: string[] = [], arknavn = 'Ark1'): Uint8Array {
  const si = delteStrenger.map((s) => `<si><t>${s}</t></si>`).join('')
  // fflate vil ha bytes, ikke strenger.
  return zipSync({
    'xl/workbook.xml': strToU8(
      `<?xml version="1.0"?><workbook xmlns:r="r"><sheets>` +
      `<sheet name="${arknavn}" sheetId="1" r:id="rId1"/>` +
      `<sheet name="Annet" sheetId="2" r:id="rId2"/>` +
      `</sheets></workbook>`),
    'xl/_rels/workbook.xml.rels': strToU8(
      `<?xml version="1.0"?><Relationships>` +
      `<Relationship Id="rId1" Target="worksheets/sheet1.xml"/>` +
      `<Relationship Id="rId2" Target="worksheets/sheet2.xml"/>` +
      `</Relationships>`),
    'xl/sharedStrings.xml': strToU8(
      `<?xml version="1.0"?><sst count="${delteStrenger.length}">${si}</sst>`),
    'xl/worksheets/sheet1.xml': strToU8(
      `<?xml version="1.0"?><worksheet><sheetData>${arkXml}</sheetData></worksheet>`),
    'xl/worksheets/sheet2.xml': strToU8(
      `<?xml version="1.0"?><worksheet><sheetData/></worksheet>`),
  })
}

function les(data: Uint8Array, arknavn = 'Ark1') {
  const rader: { nr: number; celler: Map<number, Celleverdi> }[] = []
  const svar = lesArk(data, (n) => n === arknavn, (r) => rader.push(r))
  return { rader, svar }
}

describe('lesArk', () => {
  it('KANARIFUGL: en delt formel UTEN ref beholder den bufrede verdien', () => {
    // DETTE ER HELE GRUNNEN TIL AT FILA FINNES.
    //
    // Excel skriver en delt formel én gang med `ref`, og lar de øvrige
    // cellene peke tilbake med bare `si`. ExcelJS' stroemmeleser gir
    // verdien for den foerste og NULL for resten. Paa BP25 ble
    // Laguneparkens Mat da 352 898 - januar alene - i stedet for
    // 4 651 908. Tallet saa ut som et tall, og budsjettet som et budsjett.
    const b = bok(
      `<row r="1">` +
      `<c r="A1"><f t="shared" ref="A1:A3" si="0">SUM(B1)</f><v>111</v></c></row>` +
      `<row r="2"><c r="A2"><f t="shared" si="0"/><v>222</v></c></row>` +
      `<row r="3"><c r="A3"><f t="shared" si="0"/><v>333</v></c></row>`,
    )
    const { rader } = les(b)
    expect(rader.map((r) => r.celler.get(1))).toEqual([111, 222, 333])
  })

  it('leser vanlige formler, tall og tomme celler', () => {
    const b = bok(
      `<row r="1">` +
      `<c r="A1"><v>42</v></c>` +
      `<c r="B1"><f>A1*2</f><v>84</v></c>` +
      `<c r="C1"/>` +
      `<c r="D1"><f>UDEFINERT()</f></c>` +
      `</row>`,
    )
    const { rader } = les(b)
    expect(rader[0].celler.get(1)).toBe(42)
    expect(rader[0].celler.get(2)).toBe(84)
    // Tom celle og formel uten bufret verdi finnes ikke i raden.
    expect(rader[0].celler.has(3)).toBe(false)
    expect(rader[0].celler.has(4)).toBe(false)
  })

  it('slår opp delte strenger og leser formelstrenger', () => {
    const b = bok(
      `<row r="1">` +
      `<c r="A1" t="s"><v>1</v></c>` +
      `<c r="B1" t="str"><f>Data!C1</f><v>01</v></c>` +
      `<c r="C1" t="inlineStr"><is><t>rett </t><t>fra cella</t></is></c>` +
      `</row>`,
      ['Mat', 'Tobakk'],
    )
    const { rader } = les(b)
    expect(rader[0].celler.get(1)).toBe('Tobakk')
    // «01» maa forbli en streng. Blir den tallet 1, mister maaneden
    // ledende null og «10» og «01» kan ikke lenger skilles fra hverandre.
    expect(rader[0].celler.get(2)).toBe('01')
    expect(rader[0].celler.get(3)).toBe('rett fra cella')
  })

  it('KANARIFUGL: kolonner forbi Z havner på riktig plass', () => {
    // VB-blokken i BP25 ligger i kolonne X til AL. Regnes AA som 27
    // feil, leses royaltyen som varekost - to tall som begge er
    // plausible, og ingen av dem der de skal.
    const b = bok(
      `<row r="1">` +
      `<c r="Z1"><v>26</v></c><c r="AA1"><v>27</v></c>` +
      `<c r="AL1"><v>38</v></c><c r="BA1"><v>53</v></c></row>`,
    )
    const { rader } = les(b)
    expect(rader[0].celler.get(26)).toBe(26)
    expect(rader[0].celler.get(27)).toBe(27)
    expect(rader[0].celler.get(38)).toBe(38)
    expect(rader[0].celler.get(53)).toBe(53)
  })

  it('hopper over tomme rader uten å telle dem', () => {
    // BP25-arkene er formatert ned til rad 1 048 576. Telles de tomme
    // radene med, ser et ark paa 4 500 rader ut som et paa en million.
    const b = bok(
      `<row r="1"><c r="A1"><v>1</v></c></row>` +
      `<row r="2"/><row r="3"><c r="A3"/></row>` +
      `<row r="4"><c r="A4"><v>4</v></c></row>`,
    )
    const { rader, svar } = les(b)
    expect(rader.map((r) => r.nr)).toEqual([1, 4])
    expect(svar.antallRader).toBe(2)
  })

  it('KANARIFUGL: et ark som ikke finnes kaster, det gir ikke tomt svar', () => {
    // Et tomt resultat og et fravaerende ark maa ikke se like ut. Det
    // ene er «ingen budsjettlinjer», det andre er «feil fil».
    const b = bok(`<row r="1"><c r="A1"><v>1</v></c></row>`)
    expect(() => lesArk(b, (n) => n === 'Finnes ikke', () => {}))
      .toThrow(/Ark1, Annet/)
  })

  it('avkoder XML-entiteter i tekst', () => {
    const b = bok(`<row r="1"><c r="A1" t="s"><v>0</v></c></row>`, ['Rep &amp; vedlikehold'])
    expect(les(b).rader[0].celler.get(1)).toBe('Rep & vedlikehold')
  })

it('KANARIFUGL: arknavn trimmes', () => {
    // Et arknavn med mellomrom bak ser identisk ut i Excel, men
    // `['timer '].includes('timer')` er USANT. En gjenkjenning som feiler
    // paa et usynlig tegn gir «ukjent filtype» paa en fil som er helt i
    // orden - og ingen kan se hvorfor.
    const b = bok('<row r="1"><c r="A1"><v>1</v></c></row>', [], ' Ark1 ')
    const { svar } = les(b, 'Ark1')
    expect(svar.arknavn).toBe('Ark1')
  })

  it('leser arket uansett hvilken del det ligger i', () => {
    // Rekkefoelgen i zip-en sier ingenting om rekkefoelgen i boka.
    const b = bok(`<row r="1"><c r="A1"><v>7</v></c></row>`, [], 'CR-Sales')
    const { rader, svar } = les(b, 'CR-Sales')
    expect(svar.arknavn).toBe('CR-Sales')
    expect(rader[0].celler.get(1)).toBe(7)
  })
})
