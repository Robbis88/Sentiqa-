import ExcelJS from 'exceljs'

// =====================================================================
// St1 0452 «Varetransaksjonsliste» — synlig svinn
//
// Verdiene er de `varetransaksjon.test.ts` alt sto og påsto, altså
// observasjoner fra den ekte fila da testen ble skrevet: tre stasjoner
// (4177, 9145, 9467), og Lones pant-transaksjon 1001 «Pant 2 kr»,
// 12.05.2026, 4 stk, 8,00 kr.
//
// Formen er den parseren møter: seks rader topptekst før dataene,
// «Butikk:»-rad, «Underleverandør:»-rad, transaksjoner, og en
// «Sum EAN»-rad som SKAL hoppes over. Sumraden er ikke pynt — at den
// utelates er en av påstandene.
// =====================================================================

const KOL = [
  'EAN', 'Varenavn', 'Varenummer', 'Operatørnr', 'Transaksjonstype',
  'Årsakskode', 'Dato', 'Nettopris', 'Antall', 'Enhet', 'Nettopris totalt',
]

type Rad = {
  ean: string; navn: string; varenr: string; operator: string
  type: string; arsak: string; dato: string
  pris: number; antall: number; total: number
}

const LONE: Rad[] = [
  { ean: '1001', navn: 'Pant 2 kr', varenr: '90001', operator: '12',
    type: 'Synlig svinn', arsak: 'Kassert', dato: '12.05.2026',
    pris: 2, antall: 4, total: 8 },
  { ean: '7038010009457', navn: 'Melk lettmelk 1L', varenr: 'unknown', operator: '12',
    type: 'Synlig svinn', arsak: 'Datovare', dato: '12.05.2026',
    pris: 21.9, antall: 3, total: 65.7 },
]

const DALE: Rad[] = [
  { ean: '7622210419941', navn: 'Kvikk Lunsj', varenr: '41994', operator: '7',
    type: 'Synlig svinn', arsak: 'Brekkasje', dato: '11.05.2026',
    pris: 18.5, antall: 2, total: 37 },
]

const VARDEN: Rad[] = [
  { ean: '7040110000012', navn: 'Baguette skinke', varenr: '11000', operator: '3',
    type: 'Synlig svinn', arsak: 'Kassert', dato: '13.05.2026',
    pris: 49.9, antall: 1, total: 49.9 },
]

export async function lagVaretransaksjon(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()
  const ws = wb.addWorksheet('Varetransaksjonsliste')

  // Seks rader topptekst — parseren begynner å lese på rad 7.
  ws.addRow(['Varetransaksjonsliste'])
  ws.addRow(['Rapport 0452'])
  ws.addRow(['Periode: 01.05.2026 - 13.05.2026'])
  ws.addRow([])
  ws.addRow(KOL)
  ws.addRow([])

  for (const [butikk, rader] of [
    ['Butikk: St1 Lone (4177)', LONE],
    ['Butikk: 9145 - St1 Dale', DALE],
    ['Butikk: St1 Varden (9467)', VARDEN],
  ] as [string, Rad[]][]) {
    ws.addRow([butikk])
    ws.addRow(['Underleverandør: Diverse'])
    for (const r of rader) {
      ws.addRow([
        r.ean, r.navn, r.varenr, r.operator, r.type, r.arsak, r.dato,
        r.pris, r.antall, 'stk', r.total,
      ])
    }
    // SKAL HOPPES OVER. Kolonne 1 er tekst, ikke tall, så den faller ut
    // av transaksjonstesten uansett — men parseren har en egen `Sum `-
    // gren, og den er verdt å møte.
    ws.addRow(['Sum EAN', '', '', '', '', '', '', '', rader.length, '',
      rader.reduce((a, r) => a + r.total, 0)])
    ws.addRow([])
  }

  return Buffer.from(await wb.xlsx.writeBuffer())
}
