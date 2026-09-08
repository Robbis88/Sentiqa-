import ExcelJS from 'exceljs'

// =====================================================================
// St1 0714 «Salgsstatistikk avdeling drilldown»
//
// Verdiene er observasjonene `salgsstatistikk.test.ts` alt sto og påsto:
// dato 30.04.2026, moms av, fem stasjoner, og Lones EAN 3000
// «HVETEBOLLE» under 120 MAT / 10 / 1201 med 5 stk og 57,30434785 kr.
//
// TRE TING I FORMEN ER IKKE PYNT:
//
//   Hierarkiet. Butikk: → Avdeling: → Vareområde: → Varegruppe: →
//   produktrader. Konteksten bæres nedover, og en produktrad arver den
//   siste av hver. Feiler arven, får bollen feil avdeling — og
//   avdelingen er det ENERGI-filteret leser.
//
//   Den EAN-løse linja. St1 sender av og til en produktrad uten EAN under
//   en «Unknown Unknown»-avdeling: kolonne 1 er tom, men navn og beløp
//   står der. Den ser ut som en blank rad. Lone manglet 70 kr av 922 056
//   i august 2026 fordi den ble hoppet over i stillhet, og det tok en
//   manuell avstemming mot St1 å oppdage.
//
//   Butikk-raden som gjentas som sum til slutt. Parseren skal ikke lage
//   en ny stasjon av den.
//
// Over tusen produktrader er også en påstand i testen, så fixturen må
// faktisk ha dem.
// =====================================================================

const STASJONER: [string, string][] = [
  ['4177', 'St1 Lone'],
  ['4185', 'St1 Laguneparken'],
  ['9038', 'St1 Bønes'],
  ['9145', 'St1 Dale'],
  ['9467', 'St1 Varden'],
]

/** Avdeling, vareområde, varegruppe — og hvor mange varer under hver. */
// Antallet er ikke tilfeldig: testen paastaar over tusen produktrader
// til sammen. Den paastanden er der for aa fange en parser som stopper
// for tidlig, og med for faa rader ville den blitt sann av seg selv.
const TRE: [string, string, string, string, string, string, number][] = [
  ['120', 'MAT', '10', 'BAKERI', '1201', 'BOLLER', 46],
  ['120', 'MAT', '10', 'BAKERI', '1202', 'BRØD', 42],
  ['130', 'DRIKKE', '20', 'KALD DRIKKE', '1301', 'BRUS', 44],
  ['130', 'DRIKKE', '20', 'KALD DRIKKE', '1302', 'ENERGIDRIKK', 40],
  ['140', 'KIOSK', '30', 'SNACKS', '1401', 'SJOKOLADE', 50],
  ['150', 'TOBAKK', '40', 'TOBAKK', '1501', 'SIGARETTER', 38],
  ['1000', 'ENERGI', '90', 'DRIVSTOFF', '9001', 'BENSIN', 6],
]

export async function lagSalgsstatistikk(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()
  const ws = wb.addWorksheet('Salgsstatistikk')

  ws.addRow(['Salgsstatistikk avdeling drilldown'])
  ws.addRow(['St1 Norge AS'])
  ws.addRow(['Dato: 30.04.2026  Inkluder moms: false'])
  ws.addRow([])
  ws.addRow([])
  ws.addRow(['EAN', 'Varenavn', 'Varenr.', 'Antall totalt', 'Antall tilbud',
    'Omsetning eks mva', '', '', '', '', 'Bto.fortj. kr', 'Bto.fortj. %'])
  ws.addRow([])

  let ean = 3000
  for (const [nr, navn] of STASJONER) {
    ws.addRow([`Butikk: ${navn} (${nr})`])

    for (const [ak, an, ok, on, gk, gn, antall] of TRE) {
      ws.addRow([`Avdeling: ${ak} ${an}`])
      ws.addRow([`Vareområde: ${ok} ${on}`])
      ws.addRow([`Varegruppe: ${gk} ${gn}`])

      for (let i = 0; i < antall; i++) {
        // Den ene raden testen kjenner ved navn og tall.
        const erBollen = nr === '4177' && gk === '1201' && i === 0
        const kode = erBollen ? '3000' : String(ean)
        ws.addRow([
          kode,
          erBollen ? 'HVETEBOLLE' : `${gn} ${i + 1}`,
          `V${kode}`,
          erBollen ? 5 : 1 + ((i * 3) % 17),
          0,
          erBollen ? 57.30434785 : 10 + ((i * 7.3) % 240),
          '', '', '', '',
          erBollen ? 21.4 : 4 + ((i * 2.1) % 90),
          erBollen ? 37.3 : 30 + (i % 25),
        ])
        if (!erBollen) ean += 1
      }
      ws.addRow([])
    }

    // EAN-LOES PRODUKTLINJE. Tom kolonne 1, navn og beloep staar.
    ws.addRow(['Avdeling: Unknown Unknown'])
    ws.addRow(['Vareområde: Unknown'])
    ws.addRow(['Varegruppe: Unknown'])
    ws.addRow(['', 'Not Available / Unknown', '', 1, 0, 70, '', '', '', '', 12, 17.1])
    ws.addRow([])

    // Stasjonen gjentas som avslutningssum - skal ikke gi en ny stasjon.
    ws.addRow([`Butikk: ${navn} (${nr})`])
    ws.addRow([])
  }

  return Buffer.from(await wb.xlsx.writeBuffer())
}
