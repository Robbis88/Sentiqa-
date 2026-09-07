import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { BP_LONNSKODER } from './bp'

// =====================================================================
// SAMME LOENNSKODER I TYPESCRIPT OG I SQL
//
// `bp_maaned_for_mine_stasjoner` (0183) finnes fordi butikksjefen ikke
// leser `bp_linje` direkte - BP-en er kjedens dokument. Funksjonen maa
// derfor filtrere paa de samme 5xxx-kodene som `BP_LONNSKODER`.
//
// Naa staar lista to steder. Legger noen til en kode i TypeScript uten
// aa roere migrasjonen, faar eieren et budsjett butikksjefen ikke faar -
// samme tall, to svar, avhengig av hvem som ser paa. Det er den
// vanskeligste feilen aa oppdage, fordi begge sider ser riktige ut hver
// for seg.
//
// Kanarifugl: fjern en kode fra SQL-en, og denne skal bli roed.
// =====================================================================
describe('BP-lønnskodene', () => {
  const sql = readFileSync(
    join(process.cwd(), 'supabase', 'migrations', '0183_bp_maaned_for_butikksjef.sql'),
    'utf8',
  )

  it('er de samme i migrasjonen som i TypeScript', () => {
    // Kodene staar i `and l.kode in ('5010', '5012', ...)`.
    const blokk = sql.match(/and l\.kode in \(([^)]*)\)/)
    expect(blokk, 'fant ikke kodelista i 0183').not.toBeNull()

    const iSql = new Set(
      [...blokk![1].matchAll(/'(\d{4})'/g)].map((m) => m[1]),
    )
    expect([...iSql].sort()).toEqual([...BP_LONNSKODER].sort())
  })

  // Uten denne ville testen over bestaatt om BEGGE listene ble tomme.
  it('lista er ikke tom', () => {
    expect(BP_LONNSKODER.size).toBeGreaterThan(0)
  })
})
