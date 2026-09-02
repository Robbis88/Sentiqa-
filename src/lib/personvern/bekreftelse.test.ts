import { describe, expect, test, vi } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

vi.mock('server-only', () => ({}))
vi.mock('@/lib/supabase/admin', () => ({
  lagSupabaseAdminKlient: () => { throw new Error('ingen nøkkel i test') },
}))

const { sisteBekreftelse, skrivBekreftelse } = await import('./bekreftelse')

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

// =====================================================================
// SKRIVINGEN ER SPEILBILDET AV LESINGEN
//
// `kontrolltiltak_ins` (0145) tillot en nettbrettsesjon aa skrive en
// § 9-2-bekreftelse for HVILKEN SOM HELST ansatt paa sin stasjon. Appen
// skriver alltid vaktkapselens egen id - men RLS avgjoer hva som ER
// mulig, ikke hva skjermen tilbyr.
//
// Lukket i 0168: policyen tar bare lederens egen rad, og nettbrettets
// skrives serverside med identiteten `lesAktivAnsatt` alt har bevist.
// =====================================================================

/** Fake som noterer raden som ble forsoekt skrevet. */
function skrivespion(feil: { code?: string; message: string } | null = null) {
  const rader: Record<string, unknown>[] = []
  const tabeller: string[] = []
  return {
    rader,
    tabeller,
    klient: {
      from: (t: string) => {
        tabeller.push(t)
        return { insert: async (r: Record<string, unknown>) => { rader.push(r); return { error: feil } } }
      },
    },
  }
}

describe('skrivBekreftelse: raden som skrives', () => {
  test('KANARIFUGL: skriver ansatt_id, aldri bruker_id', () => {
    // Nettbrettets konto er en ENHET, ikke personen som bekrefter.
    // Settes `bruker_id`, ville én rad dekket hele stasjonen.
    const s = skrivespion()
    return skrivBekreftelse(ANSATT, 'kjede-1', 'stasjon-1', 'v3', s.klient).then(() => {
      expect(s.tabeller[0]).toBe('kontrolltiltak_bekreftelse')
      expect(s.rader[0].ansatt_id).toBe('ansatt-1')
      expect(s.rader[0].bruker_id, 'nettbrettets konto ble skrevet som personen').toBeNull()
    })
  })

  test('kjede og stasjon kommer fra serveren, ikke fra kapselen', async () => {
    const s = skrivespion()
    await skrivBekreftelse(ANSATT, 'kjede-1', 'stasjon-1', 'v3', s.klient)
    expect(s.rader[0].retailer_id).toBe('kjede-1')
    expect(s.rader[0].stasjon_id).toBe('stasjon-1')
    expect(s.rader[0].versjon).toBe('v3')
  })

  test('stasjonsloes er lovlig - bekreftelsen gjelder personen', async () => {
    const s = skrivespion()
    await skrivBekreftelse(ANSATT, 'kjede-1', null, 'v3', s.klient)
    expect(s.rader[0].stasjon_id).toBeNull()
  })

  test('en dublett er ikke en feil, men heller ikke en ny rad', async () => {
    // De to skal ikke kvitteres likt - samme regel som i `bekreftLest`.
    const ny = await skrivBekreftelse(ANSATT, 'k', null, 'v3', skrivespion().klient)
    const igjen = await skrivBekreftelse(ANSATT, 'k', null, 'v3',
      skrivespion({ code: '23505', message: 'duplicate key' }).klient)
    expect(ny).toEqual({ slag: 'ny' })
    expect(igjen).toEqual({ slag: 'fantes' })
  })

  test('en ekte feil returneres som feil', async () => {
    const svar = await skrivBekreftelse(ANSATT, 'k', null, 'v3',
      skrivespion({ code: '42501', message: 'ikke lov' }).klient)
    expect(svar).toEqual({ slag: 'feil', melding: 'ikke lov' })
  })

  test('KANARIFUGL: uten tjenestenøkkel skrives INGENTING, og det sies fra', async () => {
    // Admin-klienten kaster her (mocken oeverst). Da ble ingen rad
    // skrevet, og hun skal ikke faa «Takk, registrert».
    const svar = await skrivBekreftelse(ANSATT, 'k', null, 'v3')
    expect(svar.slag).toBe('feil')
  })
})

describe('bekreftLest bruker de to veiene riktig', () => {
  const raa = readFileSync(
    join(process.cwd(), 'src', 'app', '(beskyttet)', 'mine-opplysninger', 'handlinger.ts'), 'utf8',
  )
  // Uten kommentarene - de omtaler nettopp det vi leter etter.
  const kilde = raa.split('\n').filter((l) => !l.trim().startsWith('//')).join('\n')

  test('KANARIFUGL: kilden lar seg lese, og kommentarene er strippet', () => {
    expect(kilde).toContain('export async function bekreftLest')
    expect(kilde, 'kommentarene ble ikke fjernet').not.toContain('TO VEIER')
  })

  test('nettbrettet gaar serverside, den innloggede gjennom RLS', () => {
    expect(kilde).toContain('skrivBekreftelse(')
    expect(kilde, 'den innloggede skriver ikke lenger sin egen rad')
      .toContain('bruker_id: bruker.id')
  })

  test('KANARIFUGL: nettbrettets id settes ikke lenger gjennom RLS', () => {
    // Sto `ansatt_id: ansatt?.id ?? null` igjen i RLS-innsettingen, ville
    // den brede veien vaert aapen ved siden av den smale.
    expect(kilde).not.toContain('ansatt_id: ansatt?.id')
    expect(kilde, 'RLS-innsettingen skal skrive null').toContain('ansatt_id: null')
  })
})
