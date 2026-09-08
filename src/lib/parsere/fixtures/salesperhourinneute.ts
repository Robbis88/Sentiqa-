import ExcelJS from 'exceljs'

// =====================================================================
// St1 0603 «Timesalgsrapport med inne- og utekunder»
//
// Verdiene er observasjonene `salesperhourinneute.test.ts` alt sto og
// påsto: fem stasjoner, 24 timebøtter, og Bønes med 2 999,07 kr i
// time 0-1 med 0 innekunder og 7 utekunder, og 68/31 i time 6-7.
//
// TIME 0-1 MED 0 INNE OG 7 UTE ER IKKE PYNT. Det er 0603-fella: butikken
// er stengt om natten, men pumpa selger, og en parser som leste «antall
// kunder» som én kolonne ville trodd stasjonen hadde sju kunder inne kl.
// 00. Se [[sentiqa-bemanningsplanlegger]].
//
// TOTAL-RADEN LIGGER MED. Parseren skal bryte på «Totalt», og at den gjør
// det er en av påstandene — uten raden ville testen bestått også for en
// parser som tok totalen med som en sjette stasjon.
// =====================================================================

const STASJONER = ['St1 Bønes', 'St1 Dale', 'St1 Laguneparken', 'St1 Lone', 'St1 Varden']

/** Bønes, slik testen kjenner den. Resten er variasjoner over samme form. */
const BONES: Record<string, [number, number, number]> = {
  // time: [salg, innekunder, utekunder]
  '0-1': [2999.07, 0, 7],
  '6-7': [8841.2, 68, 31],
}

function timerFor(navn: string, i: number): [string, number, number, number][] {
  const ut: [string, number, number, number][] = []
  for (let t = 0; t < 24; t++) {
    const nokkel = `${t}-${t + 1}`
    const kjent = navn === 'St1 Bønes' ? BONES[nokkel] : undefined
    if (kjent) { ut.push([nokkel, kjent[0], kjent[1], kjent[2]]); continue }
    // Stengt butikk om natten, aapen fra 6: samme form som den ekte fila.
    const inne = t >= 6 && t <= 22 ? 20 + ((t * 7 + i * 3) % 60) : 0
    const ute = 5 + ((t * 5 + i * 2) % 40)
    ut.push([nokkel, 500 + t * 137 + i * 11, inne, ute])
  }
  return ut
}

export async function lagSalesPerHourInneUte(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()
  const ws = wb.addWorksheet('Timesalg inne ute')

  ws.addRow(['Timesalgsrapport med inne- og utekunder'])
  ws.addRow(['Dato: 10.06.2026'])
  for (let i = 0; i < 4; i++) ws.addRow([])
  ws.addRow(['Time', 'Salg', 'Kostpris', 'Mva', '', '', 'Antall varer',
    'Innekunder', '', '', 'Utekunder'])
  ws.addRow([])

  STASJONER.forEach((navn, i) => {
    ws.addRow([navn])
    ws.addRow([]) // total-rad mellom navn og timer - parseren hopper over tomme
    for (const [time, salg, inne, ute] of timerFor(navn, i)) {
      ws.addRow([
        time, salg, salg * 0.68, salg * 0.2, '', '',
        Math.round(inne * 2.3 + ute), inne, '', '', ute,
      ])
    }
    ws.addRow([])
  })

  ws.addRow(['Totalt'])
  ws.addRow(['0-1', 99999, 0, 0, '', '', 0, 0, '', '', 0])

  return Buffer.from(await wb.xlsx.writeBuffer())
}
