import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, it, expect } from 'vitest'
import { gjenkjennRapporttype } from './gjenkjenn'
import type { Rapporttype } from './typer'
import { lagSalgsstatistikk } from './fixtures/salgsstatistikk'
import { lagSalesPerHourInneUte } from './fixtures/salesperhourinneute'
import { lagKassererstatistikk } from './fixtures/kassererstatistikk'
import { lagVaretransaksjon } from './fixtures/varetransaksjon'

// =====================================================================
// GJENKJENNINGEN ER RUTEREN, OG DEN HOPPET OVER SEG SELV
//
// Fem `it.skipIf(!existsSync(sti))` mot filer i `eksempelfiler/`, som er
// gitignored. Ingen av dem kjørte i CI — og heller ikke lokalt, siden
// mappa er tom.
//
// Det er den dyreste av de skippede suitene: gjenkjenningen bestemmer
// HVILKEN parser en opplastet fil går til. Tar den feil, får man ikke en
// feilmelding, man får feil tall i riktig tabell.
//
// Fire av de fem har fixture nå. Den femte (Azets-regnskapet) har det
// ikke ennå, og står med `skipIf` — synlig, ikke skjult.
// =====================================================================

const DIR = join(process.cwd(), 'eksempelfiler')

const MED_FIXTURE: [string, Rapporttype, () => Promise<Buffer>][] = [
  ['Salgsstatistikk 2026-05-01.xlsx', 'st1_salgsstatistikk', lagSalgsstatistikk],
  ['Timesalgsrapport med inne- og utekunder 2026-06-10.xlsx',
    'st1_salesperhour_inneute', lagSalesPerHourInneUte],
  ['0018_CashierStatistics_std 2026-05-13.xlsx', 'st1_cashierstats', lagKassererstatistikk],
  ['Varetransaksjonsliste 2026-05-13.xlsx', 'salgsgrid_varetrans', lagVaretransaksjon],
]

const UTEN_FIXTURE: [string, Rapporttype][] = [
  ['190 Kelsar Bil AS 202512-202512_3 (1).xlsx', 'regnskap_resultat'],
]

describe('gjenkjennRapporttype', () => {
  for (const [filnavn, forventet, lagFixture] of MED_FIXTURE) {
    const sti = join(DIR, filnavn)
    const ekte = existsSync(sti)
    it(`gjenkjenner ${forventet} (${ekte ? 'ekte fil' : 'fixture'})`, async () => {
      const data = ekte ? readFileSync(sti) : await lagFixture()
      expect(await gjenkjennRapporttype(data)).toBe(forventet)
    })
  }

  for (const [filnavn, forventet] of UTEN_FIXTURE) {
    const sti = join(DIR, filnavn)
    it.skipIf(!existsSync(sti))(`gjenkjenner ${forventet}`, async () => {
      expect(await gjenkjennRapporttype(readFileSync(sti))).toBe(forventet)
    })
  }

  it('KANARIFUGL: en arbeidsbok som ikke ligner noe, blir ukjent', async () => {
    // Uten denne kunne gjenkjenningen returnert samme svar på alt og
    // fortsatt vært grønn på hver sak over.
    const { default: ExcelJS } = await import('exceljs')
    const wb = new ExcelJS.Workbook()
    wb.addWorksheet('Ark1').addRow(['Noe helt annet'])
    const data = Buffer.from(await wb.xlsx.writeBuffer())
    expect(await gjenkjennRapporttype(data)).toBe('ukjent')
  })
})
