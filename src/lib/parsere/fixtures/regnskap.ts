import ExcelJS from 'exceljs'

// =====================================================================
// Azets månedsregnskap — «Cluster»-arket og ett ark per stasjon
//
// Den tyngste av fixturene, og den viktigste: denne fila mater
// /regnskap, lønnskosten og BP-sammenligningen. Verdiene er
// observasjonene testene alt sto og påsto:
//
//   Cluster       «190 Kelsar Bil AS», Denne periode 01.12.2025,
//                 120 Mat 1 458 573,90 mot budsjett 1 633 870,31,
//                 Omsetning totalt 5 289 620,30
//   Per stasjon   Lone 120 Mat 273 865,21 mot 289 180,63,
//                 konto 633 mellom 6 000 og 7 000 mot budsjett over 7 000
//
// ---------------------------------------------------------------------
// TRE STEDER FORMEN BÆRER EN FEIL SOM HAR SKJEDD
//
//   «Denne periode» mot «Hittil i år». Leses feil felt, blir perioden
//   01.01 i stedet for 01.12 — altså riktig år og feil måned, som er
//   den slags feil ingen ser på en skjerm. Begge feltene ligger i
//   fixturen, med ULIKE datoer, så en parser som leser feil felt blir
//   rød.
//
//   «Omsetning totalt» på stasjonsarket. Rollupen skal HOPPES OVER der,
//   ellers dobbelttelles stasjonens omsetning. Raden ligger derfor med.
//
//   Konto 739. Den står ikke i `KONTO_NAVN`, så parseren skriver
//   «Konto 739». Det er den ekte tilstanden i produksjon (sonden fant
//   739 og 745), og fra `0192` avgjør den samme stillheten hvem som får
//   se raden.
//
// ARKENE DELES AV TRE PARSERE, og de leser kolonne 2 ulikt:
// `parseRegnskapStasjoner` som nivå («ProdGrN» = rollup),
// `parseUsynligSvinn` som type («Prod» = enkeltprodukt). Derfor er
// produktrader og rollup-rader ulike rader her — ikke av
// bekvemmelighet, men fordi de ER ulike i fila.
// =====================================================================

const RETAILER = '190 Kelsar Bil AS'

const STASJONER: [string, string][] = [
  ['4177', 'ST1 Lone'],
  ['4185', 'ST1 Laguneparken'],
  ['9038', 'ST1 Bønes'],
  ['9145', 'ST1 Dale'],
  ['9467', 'ST1 Varden'],
]

/** Avdelingsrollup: kode, navn, og Lones tall der testen kjenner dem. */
const AVDELINGER: [string, string][] = [
  ['120', 'Mat'],
  ['130', 'Drikke'],
  ['140', 'Kiosk'],
  ['150', 'Tobakk'],
  ['1000', 'Energi'],
]

/** Driftskonti per stasjon. 739 er med vilje ukjent for kontoplanen. */
const KONTI: [string, number, number][] = [
  ['501', 42180.5, 41000],
  ['503', 118420.9, 121000],
  ['540', 22110.4, 22800],
  ['627', 8120, 8000],
  ['633', 6420.75, 7310.5],
  ['634', 9910.2, 9000],
  ['739', 0, 0.01],
  ['746', 1204.5, 900],
]

function clusterArk(wb: ExcelJS.Workbook): void {
  const ws = wb.addWorksheet('Cluster')

  ws.getRow(1).getCell(3).value = RETAILER
  // BEGGE PERIODEFELTENE, med ULIKE datoer. Leses «Hittil i år» i
  // stedet, blir svaret 2025-01-01 og testen roeper.
  ws.getRow(2).getCell(1).value = 'Denne periode 01.12.2025 - 31.12.2025'
  ws.getRow(2).getCell(9).value = 'Hittil i år 01.01.2025 - 31.12.2025'
  ws.getRow(3).values = ['Kode', 'Sort', 'Post', 'Regnskap', 'Budsjett',
    'Avvik', 'Index', '', 'Regnskap hittil', 'Budsjett hittil']

  const rad = (
    kode: string, sort: number, post: string,
    reg: number, bud: number, hReg = 0, hBud = 0,
  ) => ws.addRow([kode, sort, post, reg, bud, reg - bud,
    bud ? ((reg - bud) / bud) * 100 : 0, '', hReg, hBud])

  // En seksjonsrad kjennes paa at kolonne 4 er ordet «Regnskap».
  const seksjon = (navn: string) => ws.addRow(['', '', navn, 'Regnskap',
    'Budsjett', 'Avvik', 'Index', '', 'Regnskap', 'Budsjett'])

  ws.addRow([])

  seksjon('Omsetning')
  rad('120', 10, '120 Mat', 1458573.9, 1633870.31, 17102884.1, 18120440)
  rad('130', 20, '130 Drikke', 1102411.2, 1150000, 13220110, 13800000)
  rad('140', 30, '140 Kiosk', 980220.4, 1010000, 11760000, 12120000)
  rad('150', 40, '150 Tobakk', 748414.8, 760000, 8981000, 9120000)
  rad('', 90, 'Omsetning totalt', 5289620.3, 5553870.31, 63465000, 66646000)

  seksjon('Bruttofortjeneste')
  rad('120', 10, '120 Mat', 612010.5, 690000, 7344000, 8280000)
  rad('130', 20, '130 Drikke', 501220.1, 520000, 6014000, 6240000)
  rad('', 90, 'Bruttofortjeneste totalt', 1113230.6, 1210000, 13358000, 14520000)

  seksjon('Driftskostnader')
  rad('501', 10, '501 Faste lønninger', 210900, 205000, 2530800, 2460000)
  rad('503', 20, '503 Timelønn', 592100, 605000, 7105200, 7260000)
  rad('622', 30, '622 Royalty', 462800, 470000, 5553600, 5640000)
  rad('633', 40, '633 Forbruksmateriell', 32100, 36000, 385200, 432000)
  rad('', 99, 'Resultat', 118420.4, 140000, 1421000, 1680000)

  ws.addRow([])
  ws.addRow(['', '', 'Kommentarer'])
  ws.addRow(['', '', 'Alt som staar under her skal ikke leses.'])
  ws.addRow(['999', 1, '999 Skal aldri leses', 1, 1, 0, 0, '', 0, 0])
}

function stasjonsark(wb: ExcelJS.Workbook, nr: string, navn: string, i: number): void {
  const ws = wb.addWorksheet(`${nr} ${navn}`)

  ws.getRow(1).getCell(1).value = `${nr} ${navn}`
  ws.getRow(2).getCell(1).value = 'Denne periode 01.12.2025 - 31.12.2025'
  // Toppteksten MAA ha «Usynlig» innen rad 6 - `parseUsynligSvinn`
  // bruker den til aa bekrefte at oppsettet stemmer, og hopper over
  // arket helt hvis den mangler.
  ws.getRow(3).values = [
    'Kode', 'Nivå', 'Type', 'NivåTall', '', '', 'Navn', 'Salg', 'Budsjett',
    'Index', 'Brutto', '', 'Brutto budsjett', '', '', '', '', '', '',
    'Kast', '', '', 'Usynlig', 'Usynlig %',
  ]

  const erLone = nr === '4177'

  // --- Avdelingsrollup (Oms + nivaa med «Gr») ------------------------
  for (const [kode, avdnavn] of AVDELINGER) {
    const salg = erLone && kode === '120' ? 273865.21 : 90000 + i * 4100 + Number(kode) * 7
    const bud = erLone && kode === '120' ? 289180.63 : salg * 1.04
    const rad: (string | number)[] = new Array(13).fill('')
    rad[0] = kode
    rad[1] = 'ProdGrN'
    rad[2] = 'Oms'
    rad[3] = '2'
    rad[6] = `${kode} ${avdnavn}`
    rad[7] = salg
    rad[8] = bud
    rad[9] = bud ? ((salg - bud) / bud) * 100 : 0
    rad[10] = salg * 0.31
    rad[12] = bud * 0.32
    ws.addRow(rad)
  }

  // SKAL HOPPES OVER paa stasjonsarket - ellers dobbelttelles omsetningen.
  const total: (string | number)[] = new Array(13).fill('')
  total[1] = 'ProdGrN'
  total[2] = 'Oms'
  total[6] = 'Omsetning totalt'
  total[7] = 999999
  total[8] = 999999
  ws.addRow(total)

  // --- Enkeltprodukter (usynlig svinn) -------------------------------
  const produkter: [string, string, number, number][] = [
    // kode, navn, salg, usynlig kr (+ manko, - overskudd)
    ['13010', '13010 KAFFE', 210400, erLone ? 18420.5 : 6100 + i * 900],
    ['12010', '12010 BAKERI', 142100, 4210.25],
    ['14010', '14010 SJOKOLADE', 98400, -1320.75],
  ]
  for (const [kode, pnavn, salg, usynlig] of produkter) {
    const rad: (string | number)[] = new Array(24).fill('')
    rad[0] = kode
    rad[1] = 'Prod'
    rad[2] = 'Oms'
    rad[3] = '1'
    rad[6] = pnavn
    rad[7] = salg
    rad[11] = 31.2
    rad[19] = 2100
    rad[22] = usynlig
    rad[23] = salg ? (usynlig / salg) * 100 : 0
    ws.addRow(rad)
  }

  // --- Driftskonti (Res, nivaa 1, kode >= 500) -----------------------
  for (const [kode, reg, bud] of KONTI) {
    const rad: (string | number)[] = new Array(9).fill('')
    rad[0] = kode
    rad[1] = 'Konto'
    rad[2] = 'Res'
    rad[3] = '1'
    rad[6] = `Konto ${kode}`
    rad[7] = erLone ? reg : reg * (1 + i / 10)
    rad[8] = erLone ? bud : bud * (1 + i / 10)
    ws.addRow(rad)
  }

  // Under 500 - skal IKKE bli en driftskostnad.
  const under: (string | number)[] = new Array(9).fill('')
  under[0] = '300'
  under[1] = 'Konto'
  under[2] = 'Res'
  under[3] = '1'
  under[6] = 'Konto 300'
  under[7] = 5000
  under[8] = 5000
  ws.addRow(under)
}

export async function lagRegnskap(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()
  clusterArk(wb)
  STASJONER.forEach(([nr, navn], i) => stasjonsark(wb, nr, navn, i))

  // Strukturelt ark. `parseRegnskapStasjoner` hopper over det paa navnet;
  // uten et her ville den grenen aldri blitt kjort.
  const admin = wb.addWorksheet('9900 Admin')
  admin.getRow(3).getCell(23).value = 'Usynlig'

  return Buffer.from(await wb.xlsx.writeBuffer())
}
