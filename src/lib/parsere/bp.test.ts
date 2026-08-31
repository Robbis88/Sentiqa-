import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { parseBp, erBpFil } from './bp'

// =====================================================================
// BP26-formatet: «Timebudsjett Grunnlagsfil» og «Budsjettfil til VB».
//
// Tallene er Laguneparkens egne fra BP26 slik at de kan krysses mot fila.
// Merk at 3010 staar KREDIT (negativt) i fila og skal bli positiv
// omsetning her.
// =====================================================================

const kolonne = (n: number): string => {
  let ut = ''
  while (n > 0) { const r = (n - 1) % 26; ut = String.fromCharCode(65 + r) + ut; n = (n - r - 1) / 26 }
  return ut
}

/** `delt: true` skriver cella som en delt formel uten `ref` — den formen
 *  ExcelJS mister verdien for. Se kanarifuglen nederst. */
function rad(nr: number, celler: (string | number | null)[], delt = false): string {
  const c = celler.map((v, i) => {
    if (v === null) return ''
    const r = `${kolonne(i + 1)}${nr}`
    const f = delt ? '<f t="shared" si="9"/>' : ''
    return typeof v === 'number'
      ? `<c r="${r}">${f}<v>${v}</v></c>`
      : `<c r="${r}" t="str">${f || '<f>X</f>'}<v>${v}</v></c>`
  }).join('')
  return `<row r="${nr}">${c}</row>`
}

function bok(timer: string, budsjett: string, navn = ['Timebudsjett Grunnlagsfil', 'Budsjettfil til VB']): Uint8Array {
  const sheets = navn.map((n, i) => `<sheet name="${n}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('')
  const rels = navn.map((_, i) => `<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>`).join('')
  const ark = [timer, budsjett]
  const filer: Record<string, Uint8Array> = {
    'xl/workbook.xml': strToU8(`<?xml version="1.0"?><workbook xmlns:r="r"><sheets>${sheets}</sheets></workbook>`),
    'xl/_rels/workbook.xml.rels': strToU8(`<?xml version="1.0"?><Relationships>${rels}</Relationships>`),
    'xl/sharedStrings.xml': strToU8('<?xml version="1.0"?><sst count="0"/>'),
  }
  navn.forEach((_, i) => {
    filer[`xl/worksheets/sheet${i + 1}.xml`] =
      strToU8(`<?xml version="1.0"?><worksheet><sheetData>${ark[i] ?? ''}</sheetData></worksheet>`)
  })
  return zipSync(filer)
}

const TIMER = rad(1, ['Butikknr', 'Timebudsjett']) + rad(2, ['9038', 13877.65]) + rad(3, ['9145', 9512.73])

// Butikknr | Butikknavn | Varegruppenr | Varegruppenavn | Kontonr |
// Kontonavn | Tekst | DbIncCst | CrCurAm | Yr | Pr | Beløp pivot | Varekategori
const HODE = rad(1, [
  'Butikknr', 'Butikknavn', 'Varegruppenr', 'Varegruppenavn', 'Kontonr',
  'Kontonavn', 'Tekst', 'DbIncCst', 'CrCurAm', 'Yr', 'Pr', 'Beløp pivot', 'Varekategori',
])
const linje = (
  nr: number, bnr: string, konto: string, kontonavn: string,
  pr: string, belop: number, kat: string | null, delt = false,
) => rad(nr, [bnr, 'SHELL', null, null, konto, kontonavn, null, null, null, '2026', pr, belop, kat], delt)

const BUDSJETT = HODE
  + linje(2, '9038', '3010', 'CR salg', '01', -352897.52, '120 [Mat]')
  + linje(3, '9038', '4090', 'Varekost', '01', 181761.21, '120 [Mat]')
  + linje(4, '9038', '3010', 'CR salg', '02', -324980.60, '120 [Mat]')
  + linje(5, '9038', '5012', 'Timelønn', '01', 624119, null)
  + linje(6, '9038', '5010', 'Fastlønn', '01', 155123, null)
  + linje(7, '9038', '6420', 'Kostnader', '01', 64651, null)
  + linje(8, '9145', '3010', 'CR salg', '01', -100000, '180 [Tobakk]')

const FIL = bok(TIMER, BUDSJETT)

describe('erBpFil', () => {
  it('kjenner igjen BP26 på arknavnene', async () => {
    expect(await erBpFil(FIL)).toBe(true)
  })

  it('sier nei til den gamle St1-malen', async () => {
    expect(await erBpFil(bok('', '', ['CR-Sales', 'Costs']))).toBe(false)
  })

  it('KANARIFUGL: formatet foelger IKKE aarstallet', async () => {
    // Antakelsen var "gammel mal til og med 2025, ny fra 2026". Den er
    // FEIL: Kelsars BP for 2025 er den gamle malen for Laguneparken,
    // Varden og Boenes, mens DALES BP FOR SAMME AAR er den nye
    // arbeidsboka. St1 flyttet stasjonene over hver for seg.
    //
    // Hadde koden rutet paa aar, ville Dales fil blitt lest med feil
    // parser - og den ville kastet, ikke gitt gale tall. Men neste gang
    // kunne det gaatt motsatt vei.
    const dale2025 = bok(
      // Ingen `Timebudsjett Grunnlagsfil` - Dales fil har den ikke.
      '',
      HODE + linje(2, '4185', '3010', 'CR salg', '01', -100000, '120 [Mat]'),
      ['Hjelpeark', 'Budsjettfil til VB'],
    )
    expect(await erBpFil(dale2025)).toBe(true)
    const r = await parseBp(dale2025)
    expect(r.ar).toBe(2026) // aaret kommer fra `Yr`, ikke fra formatet
    expect(r.stasjoner[0].timerAar).toBeNull()
  })
})

describe('parseBp', () => {
  const r = parseBp(FIL)

  it('KANARIFUGL: «Yr» er budsjettåret i BP26', async () => {
    // Motsatt av BP25, der samme slags felt er GRUNNLAGSAARET. Leses den
    // ene som den andre, havner budsjettet paa feil aar - og fjoraaret
    // det sammenlignes mot blir et annet enn det brukeren tror.
    expect((await r).ar).toBe(2026)
  })

  it('KANARIFUGL: CR-salg står kredit i fila og skal bli positiv omsetning', async () => {
    // Snus fortegnet feil vei, blir omsetningen negativ - og en graf
    // tegner det like villig som et riktig tall.
    const s = (await r).stasjoner.find((x) => x.butikknummer === '9038')!
    expect(Math.round(s.maaneder[0].salgKr)).toBe(352898)
    expect(Math.round(s.maaneder[0].varekostKr)).toBe(181761)
    // Rund ETTER subtraksjonen: 352 897,52 - 181 761,21 = 171 136,31.
    // Rundes hvert ledd foerst, blir svaret 171 137 - ett krone-avvik som
    // ser ut som en parserfeil neste gang noen leser testen.
    expect(Math.round(s.maaneder[0].bruttoKr)).toBe(Math.round(352897.52 - 181761.21))
  })

  it('leser varegruppen ut av «120 [Mat]»', async () => {
    const s = (await r).stasjoner.find((x) => x.butikknummer === '9038')!
    const mat = s.maaneder[0].kategorier.find((k) => k.kode === '120')!
    expect(mat.post).toBe('120 Mat')
    expect(Math.round(mat.salgKr)).toBe(352898)
    expect(Math.round(mat.varekostKr)).toBe(181761)
  })

  it('splitter timelønn og fastlønn, og tar dem også med som konti', async () => {
    const s = (await r).stasjoner.find((x) => x.butikknummer === '9038')!
    expect(s.maaneder[0].timelonnKr).toBe(624119)
    expect(s.maaneder[0].fastlonnKr).toBe(155123)
    expect(s.maaneder[0].konti.find((k) => k.kode === '5012')!.belopKr).toBe(624119)
    expect(s.maaneder[0].konti.find((k) => k.kode === '6420')!.belopKr).toBe(64651)
  })

  it('leser timebudsjettet per stasjon', async () => {
    const st = (await r).stasjoner
    expect(st.find((x) => x.butikknummer === '9038')!.timerAar).toBeCloseTo(13877.65, 2)
    expect(st.find((x) => x.butikknummer === '9145')!.timerAar).toBeCloseTo(9512.73, 2)
  })

  it('legger radene på riktig måned', async () => {
    const s = (await r).stasjoner.find((x) => x.butikknummer === '9038')!
    expect(Math.round(s.maaneder[1].salgKr)).toBe(324981)
    expect(s.maaneder[2].salgKr).toBe(0)
  })

  it('KANARIFUGL: delte formler uten ref mister ikke verdien', () => {
    // GRUNNEN TIL AT DENNE PARSEREN BLE MIGRERT VEKK FRA ExcelJS.
    // Excel skriver en delt formel én gang med `ref` og lar resten peke
    // tilbake med bare `si`. ExcelJS' stroemmeleser gir da null, og et
    // aarsbudsjett blir stille for lavt - slik BP25 ble januar alene.
    const delt = bok(TIMER, HODE
      + linje(2, '9038', '3010', 'CR salg', '01', -100000, '120 [Mat]')
      + linje(3, '9038', '3010', 'CR salg', '02', -200000, '120 [Mat]', true)
      + linje(4, '9038', '3010', 'CR salg', '03', -300000, '120 [Mat]', true))
    return parseBp(delt).then((x) => {
      const s = x.stasjoner.find((y) => y.butikknummer === '9038')!
      expect(s.maaneder.map((m) => Math.round(m.salgKr)).slice(0, 3))
        .toEqual([100000, 200000, 300000])
    })
  })

  it('tåler at timebudsjettarket mangler i en revidert BP', async () => {
    // Timene er da allerede lagret fra forrige innlasting. `null` er
    // «vet ikke», og lagringen lar den staa.
    const uten = bok('', BUDSJETT, ['Hjelpeark', 'Budsjettfil til VB'])
    const x = await parseBp(uten)
    expect(x.stasjoner.find((y) => y.butikknummer === '9038')!.timerAar).toBeNull()
    expect(Math.round(x.stasjoner.find((y) => y.butikknummer === '9038')!.maaneder[0].salgKr))
      .toBe(352898)
  })

  it('kaster når ingen av arkene finnes', async () => {
    await expect(parseBp(bok('', '', ['Pivot', 'Hjelpeark'])))
      .rejects.toThrow(/fant verken/)
  })

  it('kaster når kolonnene mangler', async () => {
    const rart = bok(TIMER, rad(1, ['Noe', 'Annet']) + rad(2, ['9038', 1]))
    await expect(parseBp(rart)).rejects.toThrow(/mangler forventede kolonner/)
  })
})
