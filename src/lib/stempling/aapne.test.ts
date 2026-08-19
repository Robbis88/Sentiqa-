import { describe, it, expect } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAapneVakter } from './aapne'

type Rad = {
  id: string; ansatt_nr: string; ansatt_navn: string
  stasjon_id: string; tidspunkt: string; type: 'inn' | 'ut'
}

/**
 * Supabase-klient som svarer med gitte rader.
 *
 * Fanger opp `gte`/`lt` slik at testene kan se hvilket vindu spørringen
 * faktisk ba om — det er den delen av logikken som er lett å ta feil av.
 */
function fakeKlient(svar: { data?: Rad[]; error?: unknown }) {
  const sett: Record<string, string> = {}
  const kjede: Record<string, unknown> = {}
  for (const m of ['select', 'eq', 'is', 'order']) {
    kjede[m] = () => kjede
  }
  kjede.gte = (_k: string, v: string) => { sett.fra = v; return kjede }
  kjede.lt = (_k: string, v: string) => { sett.til = v; return kjede }
  kjede.then = (los: (r: unknown) => void) =>
    los({ data: svar.data ?? null, error: svar.error ?? null })
  return {
    klient: { from: () => kjede } as unknown as SupabaseClient,
    sett,
  }
}

const h = (
  id: string, nr: string, tidspunkt: string, type: 'inn' | 'ut',
): Rad => ({
  id, ansatt_nr: nr, ansatt_navn: `Ansatt ${nr}`,
  stasjon_id: 's1', tidspunkt, type,
})

describe('hentAapneVakter', () => {
  // Rettelsen peker paa denne id-en. Uten den kan butikksjefen se at en
  // vakt staar aapen, men ikke gjore noe med den.
  it('gir id-en til innstemplingen som mangler ut', async () => {
    const { klient } = fakeKlient({ data: [
      h('h-1', '1009', '2026-08-10T05:00:00Z', 'inn'),
    ] })
    const aapne = await hentAapneVakter(klient, 's1', 2026, 8)
    expect(aapne?.[0].innId).toBe('h-1')
  })

  it('gir tom liste når alle vakter er lukket', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-10T05:00:00Z', 'inn'),
      h('2', '1009', '2026-08-10T13:00:00Z', 'ut'),
    ] })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toEqual([])
  })

  it('finner vakten som aldri ble stemplet ut', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-10T05:00:00Z', 'inn'),
    ] })
    const aapne = await hentAapneVakter(klient, 's1', 2026, 8)
    expect(aapne).toHaveLength(1)
    expect(aapne?.[0].ansattNr).toBe('1009')
  })

  // «Inn mens inne» gir TO avvik i avledningen: den forlatte
  // innstemplingen (aapen) og den som kom for tidlig (dobbel_inn). Bare
  // den forste er en aapen vakt — den andre blir lukket av ut-en. Teller
  // vi begge, rapporterer sperren samme problem to ganger.
  it('teller «inn mens inne» én gang, og peker på den forlatte innstemplingen', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-10T05:00:00Z', 'inn'),
      h('2', '1009', '2026-08-10T09:00:00Z', 'inn'),
      h('3', '1009', '2026-08-10T13:00:00Z', 'ut'),
    ] })
    const aapne = await hentAapneVakter(klient, 's1', 2026, 8)
    expect(aapne).toHaveLength(1)
    expect(aapne?.[0].siden).toBe('2026-08-10T05:00:00Z')
  })

  it('en utstempling uten inn gir ingen åpen vakt', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-10T13:00:00Z', 'ut'),
    ] })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toEqual([])
  })

  // Skillet som hele sperren hviler på: «ingen åpne» og «jeg vet ikke»
  // må ikke se like ut for den som skal kjøre lønn.
  it('svarer null — ikke tom liste — når spørringen feiler', async () => {
    const { klient } = fakeKlient({ error: { code: '57014', message: 'timeout' } })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toBeNull()
  })

  // Men en tabell som ikke finnes er ikke uvisshet: da er stemplingen
  // ikke tatt i bruk, og ingen KAN staa innstemplet. Blokkerte vi her,
  // ville sperren stoppe lonnsfila som virker i dag.
  it('svarer tom liste når tabellen ikke finnes ennå', async () => {
    const { klient } = fakeKlient({
      error: { code: '42P01', message: 'relation "stempling_hendelse" does not exist' },
    })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toEqual([])
  })

  it('strekker vinduet et døgn i hver ende', async () => {
    const { klient, sett } = fakeKlient({ data: [] })
    await hentAapneVakter(klient, 's1', 2026, 8)
    expect(sett.fra.startsWith('2026-07-31')).toBe(true)
    expect(sett.til.startsWith('2026-09-02')).toBe(true)
  })

  // Vakten fra 31. juli hentes inn av strekket, men hoerer til juli.
  it('kaster åpne vakter som hører til nabomåneden', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-07-31T20:00:00Z', 'inn'),
    ] })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toEqual([])
  })

  // 1. september 01:00 norsk tid er 31. august 23:00 UTC. Sammenlignet
  // paa ISO-strengen ville denne havnet i august.
  it('regner måneden i norsk tid, ikke UTC', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-31T23:00:00Z', 'inn'),
    ] })
    expect(await hentAapneVakter(klient, 's1', 2026, 8)).toEqual([])
    expect(await hentAapneVakter(klient, 's1', 2026, 9)).toHaveLength(1)
  })

  it('sorterer eldste først, så den som har stått lengst kommer øverst', async () => {
    const { klient } = fakeKlient({ data: [
      h('1', '1009', '2026-08-20T05:00:00Z', 'inn'),
      h('2', '1010', '2026-08-05T05:00:00Z', 'inn'),
    ] })
    const aapne = await hentAapneVakter(klient, 's1', 2026, 8)
    expect(aapne?.map((v) => v.ansattNr)).toEqual(['1010', '1009'])
  })
})
