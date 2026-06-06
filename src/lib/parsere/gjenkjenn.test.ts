import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { gjenkjennRapporttype } from './gjenkjenn'
import type { Rapporttype } from './typer'

const dir = join(process.cwd(), 'eksempelfiler')

// (filnavn, forventet rapporttype) for de ekte eksempelfilene.
const SAKER: [string, Rapporttype][] = [
  ['Salgsstatistikk 2026-05-01.xlsx', 'st1_salgsstatistikk'],
  ['0758_SalesPerHour 2026-05-13 (1).xlsx', 'st1_salesperhour'],
  ['0018_CashierStatistics_std 2026-05-13.xlsx', 'st1_cashierstats'],
  ['Varetransaksjonsliste 2026-05-13.xlsx', 'salgsgrid_varetrans'],
  ['190 Kelsar Bil AS 202512-202512_3 (1).xlsx', 'visma_resultat'],
]

describe('gjenkjennRapporttype', () => {
  for (const [filnavn, forventet] of SAKER) {
    const sti = join(dir, filnavn)
    it.skipIf(!existsSync(sti))(`gjenkjenner ${forventet}`, async () => {
      expect(await gjenkjennRapporttype(readFileSync(sti))).toBe(forventet)
    })
  }
})
