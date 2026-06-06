import ExcelJS from 'exceljs'

const dir = 'C:/Koder/Sentiqa-/eksempelfiler'
function celle(v) {
  if (v === null || v === undefined) return ''
  if (typeof v === 'object') {
    if ('richText' in v) return v.richText.map((t) => t.text).join('')
    if ('result' in v) return v.result
    if ('text' in v) return v.text
    if (v instanceof Date) return v.toISOString().slice(0, 10)
  }
  return v
}

const wb = new ExcelJS.Workbook()
await wb.xlsx.readFile(`${dir}/Salgsstatistikk 2026-05-01.xlsx`)
const ws = wb.worksheets[0]

console.log('RAD 1 (tittel):', JSON.stringify(celle(ws.getRow(1).getCell(1).value)))
console.log('RAD 3 (dato)  :', JSON.stringify(celle(ws.getRow(3).getCell(1).value)))
console.log('\nHierarki-/kontekstrader (col1 med prefiks), full tekst:')
const sett = { Butikk: [], Avdeling: new Set(), 'Vareområde': new Set(), Varegruppe: new Set() }
let antProdukt = 0
for (let r = 1; r <= ws.rowCount; r++) {
  const c1 = String(celle(ws.getRow(r).getCell(1).value))
  if (c1.startsWith('Butikk:')) sett.Butikk.push(`[rad ${r}] ${c1}`)
  else if (c1.startsWith('Avdeling:')) sett['Avdeling'].add(c1)
  else if (c1.startsWith('Vareområde:')) sett['Vareområde'].add(c1)
  else if (c1.startsWith('Varegruppe:')) sett['Varegruppe'].add(c1)
  else if (/^\d/.test(c1) && r > 7) antProdukt++
}
console.log('  BUTIKKER:', sett.Butikk.length); sett.Butikk.forEach((b) => console.log('   ', b))
console.log('  AVDELINGER:', [...sett['Avdeling']].join(' ; '))
console.log('  VAREOMRÅDER (utvalg):', [...sett['Vareområde']].slice(0, 8).join(' ; '))
console.log('  VAREGRUPPER (antall):', sett['Varegruppe'].size)
console.log('  PRODUKTRADER (ca):', antProdukt, 'av', ws.rowCount, 'rader')
