import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { parseBp25, erBp25Fil } from './bp25'

// =====================================================================
// En liten arbeidsbok formet som St1s gamle mal. Tallene er hentet fra
// Kelsars BP25 slik at de kan krysses mot fila:
//
//   9038 «120 MAT» januar   Budget 352 897,52   varekost 181 761,21
//                           royalty 27 334 (7,75 % av budsjettet)
//
// Grunnlagsperioden er 01.09.23-31.08.24, saa jan-aug baerer 2024 og
// sep-des baerer 2023. BUDSJETTAARET STAAR INGEN STEDER I FILA.
// =====================================================================

type Celle = { k: number; v: string | number }

function rad(nr: number, celler: Celle[]): string {
  const kolonne = (n: number): string => {
    let ut = ''
    while (n > 0) { const r = (n - 1) % 26; ut = String.fromCharCode(65 + r) + ut; n = (n - r - 1) / 26 }
    return ut
  }
  const c = celler.map(({ k, v }) =>
    typeof v === 'number'
      ? `<c r="${kolonne(k)}${nr}"><v>${v}</v></c>`
      : `<c r="${kolonne(k)}${nr}" t="str"><f>X</f><v>${v}</v></c>`,
  ).join('')
  return `<row r="${nr}">${c}</row>`
}

function bok(arkNavn: string[], ark: Record<string, string>): Uint8Array {
  const sheets = arkNavn.map((n, i) => `<sheet name="${n}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('')
  const rels = arkNavn.map((_, i) => `<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>`).join('')
  const filer: Record<string, Uint8Array> = {
    'xl/workbook.xml': strToU8(`<?xml version="1.0"?><workbook xmlns:r="r"><sheets>${sheets}</sheets></workbook>`),
    'xl/_rels/workbook.xml.rels': strToU8(`<?xml version="1.0"?><Relationships>${rels}</Relationships>`),
    'xl/sharedStrings.xml': strToU8('<?xml version="1.0"?><sst count="0"/>'),
  }
  arkNavn.forEach((n, i) => {
    filer[`xl/worksheets/sheet${i + 1}.xml`] =
      strToU8(`<?xml version="1.0"?><worksheet><sheetData>${ark[n] ?? ''}</sheetData></worksheet>`)
  })
  return zipSync(filer)
}

// Overskriftsraden i «CR-Sales». MERK «Period» i BÅDE kolonne 9 (som er
// «Jan») og kolonne 22/29/35 (som er «01»). Det er fella `iBlokk` finnes for.
const SALG_HODE = rad(2, [
  { k: 9, v: 'Period' }, { k: 13, v: 'Budget' }, { k: 19, v: 'Purchase cost' },
  { k: 21, v: 'Budget year' }, { k: 22, v: 'Period' },
  { k: 23, v: 'VB-myynti' }, { k: 24, v: 'Site ID' }, { k: 25, v: 'ProdCode' },
  { k: 26, v: 'DbCurrAm' }, { k: 27, v: 'CrCurrAm' },
  { k: 28, v: 'Budget year' }, { k: 29, v: 'Period' },
  { k: 30, v: 'VB-ostot' }, { k: 31, v: 'Site ID' },
  { k: 32, v: 'DbCurrAm' }, { k: 33, v: 'CrCurrAm' },
  { k: 34, v: 'Budget year' }, { k: 35, v: 'Period' },
  { k: 36, v: 'VB-royalty' }, { k: 37, v: 'Site ID' },
  { k: 38, v: 'DbCurrAm' }, { k: 39, v: 'CrCurrAm' },
])

// Overskriftsraden i «Costs». Her staar aar og periode FORAN kontoen,
// og «Period» finnes ogsaa i kolonne 9 som «Jan».
const KOST_HODE = rad(3, [
  { k: 9, v: 'Period' }, { k: 10, v: 'Prev. 12 months' }, { k: 13, v: 'Budget' },
  { k: 15, v: 'Budget year' }, { k: 16, v: 'Period' }, { k: 17, v: 'VB AcNo' },
  { k: 18, v: 'Site Id' }, { k: 19, v: 'DbCurAm' }, { k: 20, v: 'CrCurAm' },
])

function salgsrad(
  nr: number, site: string, gruppe: string, maaned: string, aar: number,
  salg: number, varekost: number, royalty: number,
): string {
  return rad(nr, [
    { k: 6, v: `${site} SHELL TESTSTASJON` }, { k: 7, v: gruppe },
    // Menneskeblokken: maanedsnavn, ikke tall.
    { k: 9, v: ['', 'Jan', 'Feb', 'Mar'][Number(maaned)] ?? 'Jan' },
    { k: 21, v: aar }, { k: 22, v: maaned },
    { k: 23, v: 3020 }, { k: 24, v: site }, { k: 25, v: gruppe.split(' ')[0] },
    { k: 27, v: salg }, { k: 28, v: aar }, { k: 29, v: maaned },
    { k: 30, v: 4010 }, { k: 31, v: site }, { k: 32, v: varekost },
    { k: 34, v: aar }, { k: 35, v: maaned },
    { k: 36, v: 6312 }, { k: 37, v: site }, { k: 38, v: royalty },
  ])
}

function kostrad(
  nr: number, site: string, konto: number, navn: string,
  maaned: string, aar: number, belop: number,
): string {
  return rad(nr, [
    { k: 6, v: `${site} SHELL TESTSTASJON` },
    ...(navn ? [{ k: 8, v: navn }] : []),
    { k: 9, v: 'Jan' },
    { k: 15, v: aar }, { k: 16, v: maaned }, { k: 17, v: konto },
    { k: 18, v: site }, { k: 19, v: belop },
  ])
}

const CR_SALES = SALG_HODE
  + salgsrad(4, '9038', '120 MAT', '01', 2024, 352897.52, 181761.21, 27349.56)
  + salgsrad(5, '9038', '120 MAT', '02', 2024, 324980.60, 167382.49, 25185.99)
  // September hoerer til grunnlagsaaret FOER: 2023.
  + salgsrad(6, '9038', '120 MAT', '09', 2023, 378790.79, 195097.63, 29356.29)
  + salgsrad(7, '9038', '210 BILVASK', '01', 2024, 100000, 25000, 60000)
  + rad(8, [{ k: 6, v: '9038 SHELL TESTSTASJON' }, { k: 9, v: '-' }, { k: 13, v: 999999 }])

const COSTS = KOST_HODE
  + kostrad(4, '9038', 5010, 'Site Salary costs', '01', 2024, 375449.01)
  + kostrad(5, '9038', 5010, '', '02', 2024, 342777.50)
  + kostrad(6, '9038', 6613, 'Rep & vedlikehold', '01', 2024, 40204)

const ARK = ['Kontroll', 'CR-Sales', 'Costs', 'Cluster data']
const FIL = bok(ARK, { 'CR-Sales': CR_SALES, Costs: COSTS })

describe('erBp25Fil', () => {
  it('kjenner igjen den gamle malen på arknavnene', () => {
    expect(erBp25Fil(FIL)).toBe(true)
  })

  it('sier nei til BP26, som har helt andre ark', () => {
    const bp26 = bok(
      ['Timebudsjett Grunnlagsfil', 'Budsjettfil til VB', 'Cluster data'], {},
    )
    expect(erBp25Fil(bp26)).toBe(false)
  })
})

describe('parseBp25', () => {
  const r = parseBp25(FIL)
  const s = r.stasjoner[0]

  it('KANARIFUGL: budsjettåret er grunnlagsåret PLUSS ETT', () => {
    // Fila sier 2024 overalt. Grunnlagsperioden slutter i august, saa
    // budsjettet gjelder 2025. Leses aarstallet raatt, havner BP25 paa
    // 2024 - oppaa BP24, og med feil fjoraar aa sammenligne mot.
    expect(r.ar).toBe(2025)
  })

  it('KANARIFUGL: «Period» leses fra VB-blokken, ikke fra månedsnavnet', () => {
    // Kolonne 9 er «Jan», kolonne 16/29 er «01». Tas den foerste, gir
    // `parseInt('Jan')` NaN og HVER ENESTE rad faller ut i stillhet.
    // Summen blir 0 kroner - ikke en feil, bare et budsjett paa null.
    const salg = s.maaneder.reduce((a, m) => a + m.salgKr, 0)
    const kost = s.maaneder.reduce((a, m) => a + m.konti.reduce((x, k) => x + k.belopKr, 0), 0)
    expect(Math.round(salg)).toBe(Math.round(352897.52 + 324980.60 + 378790.79 + 100000))
    expect(Math.round(kost)).toBe(Math.round(375449.01 + 342777.50 + 40204 + 27349.56 + 25185.99 + 29356.29 + 60000))
  })

  it('legger radene på riktig måned', () => {
    expect(Math.round(s.maaneder[0].salgKr)).toBe(Math.round(352897.52 + 100000))
    expect(Math.round(s.maaneder[1].salgKr)).toBe(Math.round(324980.60))
    expect(Math.round(s.maaneder[8].salgKr)).toBe(Math.round(378790.79))
    expect(s.maaneder[2].salgKr).toBe(0)
  })

  it('normaliserer varegruppenavnet til samme form som BP26', () => {
    // «120 MAT» og «120 Mat» skal se like ut naar de stilles ved siden
    // av hverandre. Koden er noekkelen, men navnet vises.
    const mat = s.maaneder[0].kategorier.find((k) => k.kode === '120')!
    expect(mat.post).toBe('120 Mat')
    expect(Math.round(mat.salgKr)).toBe(352898)
    expect(Math.round(mat.varekostKr)).toBe(181761)
  })

  it('samler royaltyen på konto 6312, som BP26 bruker', () => {
    const roy = s.maaneder[0].konti.find((k) => k.kode === '6312')!
    expect(roy.post).toBe('6312 Royalty')
    expect(Math.round(roy.belopKr)).toBe(Math.round(27349.56 + 60000))
  })

  it('KANARIFUGL: lønnssplitten oppfinnes ikke', () => {
    // 2025-malen foerer all loenn paa 5010. Legges den paa `fastlonnKr`,
    // ser BP26s fastloenn ut som et kutt fra 4,6 til 1,8 millioner - et
    // kutt som aldri har funnet sted.
    expect(s.maaneder[0].timelonnKr).toBe(0)
    expect(s.maaneder[0].fastlonnKr).toBe(0)
    const lonn = s.maaneder[0].konti.find((k) => k.kode === '5010')!
    expect(Math.round(lonn.belopKr)).toBe(375449)
    expect(lonn.post).toBe('5010 Site Salary costs')
  })

  it('bærer kontonavnet videre til rader som ikke gjentar det', () => {
    // Navnet staar bare paa foerste rad i hver blokk.
    expect(s.maaneder[1].konti.find((k) => k.kode === '5010')!.post)
      .toBe('5010 Site Salary costs')
  })

  it('KANARIFUGL: timebudsjettet finnes ikke, og påstås ikke', () => {
    // BP25-malen har ikke timer. `0` ville sett ut som «null timer»;
    // `null` er «vet ikke», og analysen hopper da over kr/time.
    expect(s.timerAar).toBeNull()
  })

  it('KANARIFUGL: sumrader uten VB-blokk endrer ingenting', () => {
    // Hver blokk avsluttes med en sumrad: belop i menneskeblokken, men
    // ingen periode i VB-en. Telles den med, dubleres hele aaret.
    // Beviset er at fila UTEN sumraden gir nøyaktig samme svar.
    const utenSum = parseBp25(bok(ARK, {
      'CR-Sales': CR_SALES.replace(rad(8, [
        { k: 6, v: '9038 SHELL TESTSTASJON' }, { k: 9, v: '-' }, { k: 13, v: 999999 },
      ]), ''),
      Costs: COSTS,
    }))
    const sum = (x: typeof r) =>
      x.stasjoner[0].maaneder.reduce((a, m) => a + m.salgKr, 0)
    expect(sum(utenSum)).toBe(sum(r))
    expect(Math.round(sum(r))).toBe(1156669)
  })

  it('kaster når det ikke finnes budsjettrader', () => {
    const tom = bok(ARK, { 'CR-Sales': SALG_HODE, Costs: KOST_HODE })
    expect(() => parseBp25(tom)).toThrow(/ingen budsjettrader/)
  })
})
