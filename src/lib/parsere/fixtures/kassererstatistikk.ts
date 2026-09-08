import ExcelJS from 'exceljs'

// =====================================================================
// St1 0018 «Kassererstatistikk» — ett ark per stasjon
//
// Verdiene er observasjonene `kassererstatistikk.test.ts` alt sto og
// påsto: fem stasjoner, dato 11.05.2026, og Lones kasserer 12
// «Øien, Julian» med 9 199,88 kr på 70 bonger.
//
// RADPOSISJONENE VARIERER MELLOM ARK, og det er ikke tilfeldig — det
// står i parserens egen kommentar, og det er grunnen til at den leter
// etter «Butikk:» og «Nr» i stedet for å anta faste radnumre. Fixturen
// gir derfor arkene ULIK topptekstlengde med vilje. Var alle like, ville
// testen vært grønn også for en parser som antok faste rader.
//
// Se [[sentiqa-kasserer-ikke-rangering]]: 999999 er kassa selv, ikke en
// person, og hører med i formen.
// =====================================================================

type Kasserer = {
  nr: string; navn: string; oms: number; bonger: number
  returAnt: number; returBelop: number
  makAnt: number; makBelop: number
  slettAnt: number; slettBelop: number
}

const K = (
  nr: string, navn: string, oms: number, bonger: number,
  returAnt = 0, returBelop = 0, makAnt = 0, makBelop = 0,
  slettAnt = 0, slettBelop = 0,
): Kasserer => ({
  nr, navn, oms, bonger, returAnt, returBelop, makAnt, makBelop, slettAnt, slettBelop,
})

const ARK: { butikk: string; toppradere: number; kasserere: Kasserer[] }[] = [
  {
    butikk: 'Butikk: St1 Lone (4177)',
    toppradere: 1,
    kasserere: [
      K('12', 'Øien, Julian', 9199.88, 70, 2, 149.8, 5, 612.4, 1, 89),
      K('9', 'Delt bruker', 4102.5, 41, 1, 39.9, 3, 271, 0, 0),
      K('999999', 'Kassen', 812.4, 9),
    ],
  },
  {
    butikk: 'Butikk: 4185 - St1 Laguneparken',
    toppradere: 2,
    kasserere: [K('4', 'Hansen, Mia', 15320.1, 118, 3, 220, 7, 899.5, 0, 0)],
  },
  {
    butikk: 'Butikk: St1 Bønes (9038)',
    toppradere: 1,
    kasserere: [K('21', 'Nguyen, An', 22110.4, 164, 5, 401.2, 11, 1420.9, 2, 178)],
  },
  {
    butikk: 'Butikk: 9145 - St1 Dale',
    toppradere: 3,
    kasserere: [K('7', 'Berg, Ola', 7740.6, 66, 1, 59.9, 4, 388, 0, 0)],
  },
  {
    butikk: 'Butikk: St1 Varden (9467)',
    toppradere: 1,
    kasserere: [K('3', 'Solheim, Kari', 11002.2, 92, 2, 130, 6, 705.3, 1, 45)],
  },
]

const TOPP = ['Nr', 'Navn', 'Omsetning', 'Bonger', 'Retur ant', 'Retur beløp',
  'Makulerte ant', 'Makulerte beløp', 'Slettede ant', 'Slettede beløp']

export async function lagKassererstatistikk(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()

  for (const ark of ARK) {
    const ws = wb.addWorksheet(ark.butikk.replace(/[^\w]+/g, ' ').trim().slice(0, 28))
    ws.addRow(['Kassererstatistikk 11.05.2026'])
    for (let i = 0; i < ark.toppradere; i++) ws.addRow([])
    ws.addRow([ark.butikk])
    ws.addRow([])
    ws.addRow(TOPP)
    for (const k of ark.kasserere) {
      ws.addRow([k.nr, k.navn, k.oms, k.bonger, k.returAnt, k.returBelop,
        k.makAnt, k.makBelop, k.slettAnt, k.slettBelop])
    }
    // SUMRADEN SKAL IKKE BLI EN KASSERER. Parseren bryter på den.
    ws.addRow(['Sum butikk', '', ark.kasserere.reduce((a, k) => a + k.oms, 0),
      ark.kasserere.reduce((a, k) => a + k.bonger, 0)])
  }

  // Et tomt ark til slutt. St1-fila har dem, og parseren hopper over ark
  // uten «Butikk:» - uten et her ville den grenen aldri blitt kjørt.
  wb.addWorksheet('Tomt')

  return Buffer.from(await wb.xlsx.writeBuffer())
}
