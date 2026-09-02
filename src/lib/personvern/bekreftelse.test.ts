import { describe, expect, test, vi } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

vi.mock('server-only', () => ({}))
vi.mock('@/lib/supabase/admin', () => ({
  lagSupabaseAdminKlient: () => { throw new Error('ingen nøkkel i test') },
}))

const { sisteBekreftelse } = await import('./bekreftelse')

// =====================================================================
// EN NOEKKEL SOM OMGAAR RLS MAA HA EN MAALT FLATE
//
// `sisteBekreftelse` leser med tjenestenoekkelen, altsaa forbi RLS. Da er
// det ikke policyen som avgrenser den lenger - det er denne funksjonen.
// Derfor maales flaten her: hvilke kolonner, hvilke filtre, hvor mange
// rader.
//
// Grunnen til at den finnes: nettbrettet skriver `ansatt_id` med
// `bruker_id = null` (0145) og treffer ingen gren i lesepolicyen
// (`0147`). Databasen kan ikke vite hvem som staar paa vakt - `checkInn`
// setter en signert kapsel og etterlater ingen rad.
// =====================================================================

/** Fake som noterer hva som ble spurt om. */
function spion(svar: unknown = null) {
  const kall: { metode: string; args: unknown[] }[] = []
  const kjede: Record<string, unknown> = {}
  for (const m of ['select', 'eq', 'order', 'limit']) {
    kjede[m] = (...args: unknown[]) => { kall.push({ metode: m, args }); return kjede }
  }
  kjede.maybeSingle = async () => ({ data: svar })
  return {
    kall,
    klient: { from: (t: string) => { kall.push({ metode: 'from', args: [t] }); return kjede } },
  }
}

const ANSATT = { id: 'ansatt-1', navn: 'Kari' }
const rad = { versjon: 'v3', bekreftet_tid: '2026-08-20T10:00:00Z' }

describe('sisteBekreftelse: flaten', () => {
  test('leser BARE de to kolonnene siden spør om', async () => {
    // Utvides utvalget, leses persondata ingen ba om - og med
    // tjenestenoekkelen er det ingen policy som stopper det.
    const s = spion(rad)
    await sisteBekreftelse(ANSATT, 'kjede-1', s.klient)
    const select = s.kall.find((k) => k.metode === 'select')!
    expect(select.args[0]).toBe('versjon, bekreftet_tid')
    expect(select.args[0]).not.toMatch(/\*/)
  })

  test('KANARIFUGL: filtrerer paa BAADE ansatt og kjede', async () => {
    // Kjeden er andre laas, av samme grunn som i `lesAktivAnsatt`: to lag
    // som maa svikte samtidig. Faller den ut, kan en id fra en annen
    // kjede leses - og RLS er ikke der til aa ta imot.
    const s = spion(rad)
    await sisteBekreftelse(ANSATT, 'kjede-1', s.klient)
    const eq = s.kall.filter((k) => k.metode === 'eq').map((k) => k.args)
    expect(eq).toContainEqual(['ansatt_id', 'ansatt-1'])
    expect(eq).toContainEqual(['retailer_id', 'kjede-1'])
    expect(eq, 'flere filtre enn de to').toHaveLength(2)
  })

  test('én rad, nyeste først', async () => {
    const s = spion(rad)
    await sisteBekreftelse(ANSATT, 'kjede-1', s.klient)
    expect(s.kall.find((k) => k.metode === 'limit')!.args[0]).toBe(1)
    expect(s.kall.find((k) => k.metode === 'order')!.args[0]).toBe('bekreftet_tid')
    expect(s.kall.find((k) => k.metode === 'from')!.args[0]).toBe('kontrolltiltak_bekreftelse')
  })

  test('leser fra riktig tabell og gir versjonen tilbake', async () => {
    const svar = await sisteBekreftelse(ANSATT, 'kjede-1', spion(rad).klient)
    expect(svar).toEqual({ versjon: 'v3', bekreftetTid: '2026-08-20T10:00:00Z' })
  })

  test('ingen rad gir null, ikke en tom bekreftelse', async () => {
    expect(await sisteBekreftelse(ANSATT, 'kjede-1', spion(null).klient)).toBeNull()
  })

  test('KANARIFUGL: uten tjenestenøkkel feiler den LUKKET', async () => {
    // Admin-klienten kaster her (se mocken oeverst). Da vet vi ikke om hun
    // har bekreftet, og da skal hun spoerres - ikke slippes forbi.
    expect(await sisteBekreftelse(ANSATT, 'kjede-1')).toBeNull()
  })
})

describe('sisteBekreftelse: hvem som kaller den', () => {
  const side = readFileSync(
    join(process.cwd(), 'src', 'app', '(beskyttet)', 'mine-opplysninger', 'page.tsx'), 'utf8',
  ).replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '')

  test('bare nettbrettveien bruker den', () => {
    // Den innloggede leser sin egen rad gjennom RLS - foerste gren i
    // `0147` virker for henne. Aa sende henne samme vei ville brukt
    // tjenestenoekkelen paa noe policyen alt loeser.
    expect(side).toContain('sisteBekreftelse(ansatt')
    expect(side, 'den innloggede gaar fortsatt gjennom RLS').toMatch(/eq\('bruker_id', bruker\.id\)/)
  })

  test('KANARIFUGL: id-en kommer fra lesAktivAnsatt, ikke fra en parameter', () => {
    // Hele sikkerheten hviler paa at `ansatt` er PIN-bevist og
    // stasjonsavgrenset. Kommer den fra `searchParams`, er dette feil
    // verktoey - se kommentaren i `admin.ts`.
    expect(side).toMatch(/lesAktivAnsatt\(supabase\)/)
    expect(side).not.toMatch(/sisteBekreftelse\(\s*(searchParams|sp|params)/)
  })
})
