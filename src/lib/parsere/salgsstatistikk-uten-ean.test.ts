import { describe, it, expect } from 'vitest'
import ExcelJS from 'exceljs'
import { parseSalgsstatistikk } from './salgsstatistikk'

// =====================================================================
// LINJER UTEN EAN BLIR IKKE LAGRET - OG DET SKAL IKKE VAERE STILLE
//
// St1-fila kan ha produktlinjer uten EAN: «Not Available / Unknown»
// under en «Unknown Unknown»-avdeling. Parseren kjenner en produktrad
// paa at kolonne 1 er et tall, saa slike linjer hoppes over.
//
// AA droppe dem er riktig: `daglig_salg` upserter paa
// (retailer_id, stasjon_id, dato, ean), og Postgres regner NULL-er som
// forskjellige i en unik indeks - hver reimport ville lagt til en ny
// rad. AA endre noekkelen for dette er ute av proporsjon.
//
// Men det var STILLE. Lone manglet 70 kr av 922 056 i august 2026 mot
// St1s egen maanedsfil, og det tok en manuell avstemming aa finne.
//
// ---------------------------------------------------------------------
// HVORFOR EN BYGGET FIL OG IKKE EKSEMPELFILA
//
// `salgsstatistikk.test.ts` leser en ekte fil som er git-ignorert, saa
// hele den suiten hopper over i CI. En kanarifugl som bare kjoerer paa
// min maskin er ingen kanarifugl. Denne bygger arbeidsboka selv og
// kjoerer overalt.
// =====================================================================

const KOL = { ean: 1, varenavn: 2, varenr: 3, antall: 4, tilbud: 5, oms: 6 }

async function byggFil(): Promise<Buffer> {
  const wb = new ExcelJS.Workbook()
  const ws = wb.addWorksheet('0714_SalesStatisticsWithDrill')

  ws.getRow(1).getCell(1).value = '0714 - Salgsstatistikk'
  ws.getRow(3).getCell(1).value = 'Dato: 01.08.2026'
  ws.getRow(8).getCell(1).value = 'Butikk: St1 Test (4177)'

  // En vanlig avdeling med en vanlig produktlinje.
  ws.getRow(9).getCell(1).value = 'Avdeling: 120 MAT'
  ws.getRow(10).getCell(1).value = 'Vareområde: 10 BAKERI'
  ws.getRow(11).getCell(1).value = 'Varegruppe: 1201 BOLLER'
  const ok = ws.getRow(12)
  ok.getCell(KOL.ean).value = '3000'
  ok.getCell(KOL.varenavn).value = 'HVETEBOLLE'
  ok.getCell(KOL.varenr).value = 'Unknown'
  ok.getCell(KOL.antall).value = 298
  ok.getCell(KOL.tilbud).value = 259
  ok.getCell(KOL.oms).value = 3846.64

  // Og den ekte formen fra Lone: ingen EAN, navn «Not Available».
  ws.getRow(13).getCell(1).value = 'Avdeling: Unknown Unknown'
  ws.getRow(14).getCell(1).value = 'Vareområde: Unknown Unknown'
  ws.getRow(15).getCell(1).value = 'Varegruppe: Unknown Unknown'
  const utenEan = ws.getRow(16)
  utenEan.getCell(KOL.varenavn).value = 'Not Available'
  utenEan.getCell(KOL.varenr).value = 'Unknown'
  utenEan.getCell(KOL.antall).value = 13
  utenEan.getCell(KOL.tilbud).value = 0
  utenEan.getCell(KOL.oms).value = 69.86

  return Buffer.from(await wb.xlsx.writeBuffer())
}

describe('salgsstatistikk: linjer uten EAN', () => {
  it('KANARIFUGL: en linje uten EAN telles og beløpet bevares', async () => {
    // Uten dette er utelatelsen usynlig igjen, og neste gang maa noen
    // avstemme mot St1 for haand for aa oppdage den.
    const r = await parseSalgsstatistikk(await byggFil())
    expect(r.utenEan.antall, 'linja uten EAN ble ikke talt').toBe(1)
    expect(Math.round(r.utenEan.kroner), 'beløpet ble ikke bevart').toBe(70)
  })

  it('den vanlige linja lagres som før', async () => {
    // Telleren skal ikke ha spist noe som HAR EAN.
    const r = await parseSalgsstatistikk(await byggFil())
    const linjer = r.stasjoner.flatMap((s) => s.linjer)
    expect(linjer).toHaveLength(1)
    expect(linjer[0].ean).toBe('3000')
    expect(linjer[0].varenavn).toBe('HVETEBOLLE')
    expect(linjer[0].avdelingNavn).toBe('MAT')
  })

  it('en fil uten slike linjer gir null', async () => {
    // Ellers ville hver eneste import faatt en merknad, og da leses den
    // ikke naar den betyr noe.
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('0714_SalesStatisticsWithDrill')
    ws.getRow(1).getCell(1).value = '0714 - Salgsstatistikk'
    ws.getRow(3).getCell(1).value = 'Dato: 01.08.2026'
    ws.getRow(8).getCell(1).value = 'Butikk: St1 Test (4177)'
    ws.getRow(9).getCell(1).value = 'Avdeling: 120 MAT'
    const rad = ws.getRow(10)
    rad.getCell(KOL.ean).value = '3000'
    rad.getCell(KOL.varenavn).value = 'HVETEBOLLE'
    rad.getCell(KOL.oms).value = 100

    const r = await parseSalgsstatistikk(Buffer.from(await wb.xlsx.writeBuffer()))
    expect(r.utenEan).toEqual({ antall: 0, kroner: 0 })
  })
})
