import { describe, it, expect } from 'vitest'
import { zipSync, strToU8 } from 'fflate'
import { parseDelingsfil, erDelingsfil } from './delingsfil'

// =====================================================================
// Kelsars egne tall fra «Timer»-arket, kolonne for kolonne:
//
//   SHELL BØNES          timebudsjett  6 654       mat 1 700 096
//   SHELL LAGUNEPARKEN                13 212,84        4 651 908
//   SHELL VARDEN                       8 957,42        2 119 896
//
// Laguneparkens mat er BP 2025s Mat paa krona. Det er den koblingen
// aarsbestemmelsen hviler paa.
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

function bok(timerArk: string, navn = ['Timer', 'Mat', 'Bilvask']): Uint8Array {
  const sheets = navn.map((n, i) => `<sheet name="${n}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('')
  const rels = navn.map((_, i) => `<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>`).join('')
  const filer: Record<string, Uint8Array> = {
    'xl/workbook.xml': strToU8(`<?xml version="1.0"?><workbook xmlns:r="r"><sheets>${sheets}</sheets></workbook>`),
    'xl/_rels/workbook.xml.rels': strToU8(`<?xml version="1.0"?><Relationships>${rels}</Relationships>`),
    'xl/sharedStrings.xml': strToU8('<?xml version="1.0"?><sst count="0"/>'),
  }
  navn.forEach((_, i) => {
    filer[`xl/worksheets/sheet${i + 1}.xml`] = strToU8(
      `<?xml version="1.0"?><worksheet><sheetData>${i === 0 ? timerArk : ''}</sheetData></worksheet>`,
    )
  })
  return zipSync(filer)
}

// Kolonnene slik St1 setter dem: 1 Butikknavn … 8 Budsjettert
// matomsetning … 15 Timebudsjett, 16 Kost per time, 17 Kronebudsjett.
const HODE = rad(1, [
  'Butikknavn', 'Regionssjef', 'Retailer', 'AGA%', 'Stengte timer per døgn',
  'Fratrekk per år', 'Grunnbemanning', 'Budsjettert matomsetning',
  'Budsjettert annen omsetning', 'Timer tillegg mat', 'Tillegg annen oms',
  'Fratrekk årsverk', 'Fradrag for Retails bidrag', '#site/cluster (ex CRT)',
  'Timebudsjett', 'Kost per time', 'Kronebudsjett timer',
])
const linje = (
  nr: number, navn: string, mat: number, timer: number, kost: number, krone: number,
) => rad(nr, [
  navn, 'Anette Borgen', 'KELSAR BIL AS', 0.141, 0, 0, 10400, mat,
  6882483, 0, 0, -1695, -226, 3, timer, kost, krone,
])

const FILA = bok(HODE
  + linje(2, 'SHELL BØNES', 1700095.8050394272, 6654, 240.99, 1603632.97)
  + linje(3, 'SHELL LAGUNEPARKEN', 4651907.996552096, 13212.836425742891, 220.76, 2916869.22)
  + linje(4, 'SHELL VARDEN', 2119896.3105635946, 8957.4214153759, 254.15, 2276487.94))

describe('erDelingsfil', () => {
  it('kjenner igjen fila på arknavnene', () => {
    expect(erDelingsfil(FILA)).toBe(true)
  })

  it('KANARIFUGL: «Timer» alene er ikke nok', () => {
    // Ordet kan staa i hvilken som helst arbeidsbok. Det er KOMBINASJONEN
    // Mat + Vask som skiller delingsfila, og en feilgjenkjenning her ville
    // sendt en tilfeldig fil inn i timebudsjettet.
    expect(erDelingsfil(bok(HODE, ['Timer', 'Noe annet']))).toBe(false)
    expect(erDelingsfil(bok(HODE, ['Mat']))).toBe(false)
    expect(erDelingsfil(bok(HODE, ['Vask', 'Noe annet']))).toBe(false)
  })

  // 2026-FILA HAR INGEN «Timer». Kravet om det arket avviste fila for
  // aaret vi driver i, helt til 2026-09-05. Faller denne, er vi tilbake
  // til at kastbudsjettet aldri kommer inn.
  it('godtar varianten uten «Timer»-ark', () => {
    expect(erDelingsfil(bok(HODE, ['Mat', 'Vask']))).toBe(true)
  })

  it('sier nei til BP-ene', () => {
    expect(erDelingsfil(bok('', ['Timebudsjett Grunnlagsfil', 'Budsjettfil til VB']))).toBe(false)
    expect(erDelingsfil(bok('', ['CR-Sales', 'Costs', 'Cluster data']))).toBe(false)
  })
})

describe('parseDelingsfil', () => {
  const r = parseDelingsfil(FILA)

  it('leser timebudsjettet som det står', () => {
    expect(r.stasjoner.map((s) => s.butikknavn))
      .toEqual(['SHELL BØNES', 'SHELL LAGUNEPARKEN', 'SHELL VARDEN'])
    expect(r.stasjoner[1].timebudsjett).toBeCloseTo(13212.84, 2)
    expect(r.stasjoner[0].timebudsjett).toBe(6654)
  })

  it('KANARIFUGL: timene LESES, de regnes ikke ut', () => {
    // Byggeklossene staar i arket - grunnbemanning 10 400, fratrekk
    // aarsverk -1695, fradrag Retails -226. Et forsoek paa aa utlede
    // timene av dem traff Boenes eksakt og bommet paa Laguneparken med
    // 2 913 timer, fordi `Tillegg annen oms` mangler i regnestykket.
    //
    // Ville parseren regnet, ville Laguneparken staatt paa 10 400 - 1 695
    // - 226 = 8 479. Den staar paa 13 212,84, som er det fila sier.
    const lag = r.stasjoner.find((s) => s.butikknavn.includes('LAGUNEPARKEN'))!
    expect(Math.round(lag.timebudsjett)).not.toBe(8479)
    expect(Math.round(lag.timebudsjett)).toBe(13213)
  })

  it('tar med matomsetningen, som året finnes av', () => {
    const lag = r.stasjoner.find((s) => s.butikknavn.includes('LAGUNEPARKEN'))!
    expect(Math.round(lag.matomsetning)).toBe(4651908)
  })

  it('leser kost per time og kronebudsjett til kontroll', () => {
    const lag = r.stasjoner.find((s) => s.butikknavn.includes('LAGUNEPARKEN'))!
    expect(lag.kostPerTime).toBeCloseTo(220.76, 2)
    expect(lag.kronebudsjett).toBeCloseTo(2916869.22, 2)
    // Og de skal henge sammen: kronebudsjett / timer ≈ kost per time.
    expect(lag.kronebudsjett! / lag.timebudsjett).toBeCloseTo(lag.kostPerTime!, 0)
  })

  it('KANARIFUGL: en rad med null timer er ikke et budsjett', () => {
    // Et timebudsjett paa null ville stengt stasjonen i planleggeren.
    // Slike rader er sumrader eller tomme, ikke stasjoner.
    const med0 = bok(HODE
      + linje(2, 'SHELL BØNES', 1700095.81, 6654, 241, 1603633)
      + linje(3, 'SUM', 0, 0, 0, 0))
    expect(parseDelingsfil(med0).stasjoner.map((s) => s.butikknavn)).toEqual(['SHELL BØNES'])
  })

  // Begge arkene kan mangle, men ikke samtidig - da er det ikke en
  // delingsfil vi kjenner igjen, og den skal SI det i stedet for aa
  // lagre ingenting og melde «parset».
  it('kaster når verken timer eller kastbudsjett finnes', () => {
    expect(() => parseDelingsfil(bok(HODE)))
      .toThrow(/verken timebudsjett .* eller kastbudsjett/)
  })

  it('kaster når kolonnene mangler', () => {
    const rart = bok(rad(1, ['Butikknavn', 'Timebudsjett']) + rad(2, ['SHELL X', 5000]))
    expect(() => parseDelingsfil(rart)).toThrow(/mangler Butikknavn, Timebudsjett/)
  })
})

// =====================================================================
// 2026-FILA: BARE «Mat» OG «Vask»
//
// Gjenkjenningen ble aapnet for denne varianten 2026-09-05. Parseren
// ble det ikke, og `lesArk` kaster naar arket ikke finnes - saa fila
// ble meldt «Feilet: Fant ikke arket. Arkene i fila er: Mat, Vask.»
// FOER kastbudsjettet under i det hele tatt ble forsoekt.
//
// Ingen test parset en fil UTEN «Timer». `bok()` legger arket inn som
// standard, saa hver eneste parse-test hadde det - og gjenkjennings-
// testen over, som gjorde det riktige, roerer aldri parseren.
// =====================================================================
describe('parseDelingsfil uten «Timer»-ark', () => {
  // Kolonnene slik de FAKTISK staar paa Mat-arket i 2026-fila.
  //
  // `#REF!` er ikke pynt: St1s egen fil har en broetet formelreferanse
  // der overskriften «Butikknavn» skulle staatt. Navnene ligger i
  // kolonnen under den likevel. Skriver vi 'Butikknavn' her, tester vi
  // en fil St1 ikke sender.
  //
  // «Budsjettert salg» finnes paa prefiks - St1 henger «(inkl. volum +
  // prisvekst)» paa, og ordlyden har alt endret seg én gang.
  const KAST_HODE = rad(1, [
    '#REF!', 'Historisk salg', 'Budsjettert salg (inkl. volum + prisvekst)',
    'Budsjettert kast%', 'Kast budsjett KR', 'Usynlig svinn',
  ])
  // Laguneparkens egne tall: 376 076 er Mat-totalen, og den er summen av
  // de seks undergruppene paa krona.
  const MAT = bok(
    KAST_HODE + rad(2, ['SHELL LAGUNEPARKEN', 4300000, 4651908, 0.0808, 376076, 152148]),
    ['Mat', 'Vask'],
  )

  it('REGRESJON: fila parses selv om «Timer» mangler', () => {
    expect(() => parseDelingsfil(MAT)).not.toThrow()
  })

  it('leser Mat-arket som avdelingstotalen', () => {
    const r = parseDelingsfil(MAT)
    expect(r.kastbudsjett).toHaveLength(1)
    expect(r.kastbudsjett[0]).toMatchObject({
      butikknavn: 'SHELL LAGUNEPARKEN',
      nivaa: 'avdeling',
      kode: '120',
      kastKr: 376076,
      budsjettertSalg: 4651908,
      usynligKr: 152148,
    })
  })

  // KANARIFUGL: uten timebudsjett skal listen vaere TOM, ikke fylt med
  // rader arket ikke bar. En parser som fant paa stasjoner her ville
  // skrevet et timebudsjett ingen har oppgitt.
  it('KANARIFUGL: ingen stasjonsrader naar «Timer» mangler', () => {
    expect(parseDelingsfil(MAT).stasjoner).toEqual([])
  })

  // Og motsatt vei: vakten maa ikke ha slaatt av Timer-lesningen for
  // filer som FAKTISK har arket. Faller denne, leser vi aldri timene.
  it('KANARIFUGL: «Timer» leses fortsatt naar arket er der', () => {
    expect(parseDelingsfil(FILA).stasjoner).toHaveLength(3)
  })

  // Venstrest-regelen er en RESERVE, ikke erstatningen. Staar
  // «Butikknavn» der, er det den som gjelder - ellers ville en kolonne
  // St1 en dag legger til venstre stille tatt over navnet.
  it('bruker «Butikknavn» naar overskriften er hel', () => {
    const helt = bok(
      rad(1, ['Butikknavn', 'Budsjettert kast%', 'Kast budsjett KR'])
      + rad(2, ['SHELL LONE', 0.07, 200000]),
      ['Mat', 'Vask'],
    )
    expect(parseDelingsfil(helt).kastbudsjett[0].butikknavn).toBe('SHELL LONE')
  })
})
