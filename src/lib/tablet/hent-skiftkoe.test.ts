import { describe, expect, it } from 'vitest'
import { hentSkiftkoe } from './hent-skiftkoe'

function klient(utf = [{ rutine_id: 'natt', dato: '2026-09-16' }], feil = false, antall = 1) {
  const kall: { tabell: string; filter: [string, unknown][] }[] = []
  const data: Record<string, unknown> = {
    rutineskjemaer: [{ id: 'n', tid_start: '22:00', tid_slutt: '06:00', ukedager: [] }],
    rutiner: Array.from({ length: antall }, () => ({ id: 'natt', skjema_id: 'n', ukedager: [], opprettet_dato: '2026-01-01' })),
    rutine_utforinger: utf,
  }
  const supabase = { from(tabell: string) {
    const rad = { tabell, filter: [] as [string, unknown][] }
    kall.push(rad)
    const q: unknown = new Proxy({}, { get(_t, felt) {
      if (felt === 'then') {
        const svar = Promise.resolve({ data: data[tabell], error: feil ? { message: 'timeout' } : null })
        return svar.then.bind(svar)
      }
      return (...args: unknown[]) => { if (felt === 'eq' || felt === 'in') rad.filter.push([String(args[0]), args[1]]); return q }
    } })
    return q
  } } as unknown as Parameters<typeof hentSkiftkoe>[0]
  return { supabase, kall }
}

const naa = { dato: '2026-09-17', ukedag: 4, minutter: 60 }
describe('smal uthenting av nettbrettets skiftkoe', () => {
  it('nattvakten leser gaarssdagens avhuking med tre stasjonsbundne kall', async () => {
    const { supabase, kall } = klient()
    await expect(hentSkiftkoe(supabase, 'egen-stasjon', naa)).resolves.toEqual({ igjen: 0, totalt: 1, vaktdatoer: ['2026-09-16'] })
    expect(kall.map(k => k.tabell)).toEqual(['rutineskjemaer', 'rutiner', 'rutine_utforinger'])
    for (const k of kall) expect(k.filter).toContainEqual(['stasjon_id', 'egen-stasjon'])
    expect(kall[2].filter).toContainEqual(['dato', ['2026-09-16']])
  })
  it('dagens avhuking kan ikke fullfoere gaarsdagens nattvakt', async () => {
    await expect(hentSkiftkoe(klient([{ rutine_id: 'natt', dato: '2026-09-17' }]).supabase, 's', naa)).resolves.toMatchObject({ igjen: 1 })
  })
  it('en tom vakt trenger ikke avhukingshistorikk', async () => {
    const { supabase, kall } = klient([], false, 0)
    await expect(hentSkiftkoe(supabase, 's', naa)).resolves.toMatchObject({ igjen: 0 })
    expect(kall).toHaveLength(2)
  })
  it('databasefeil og avkortet rutinesett kan ikke se ut som ferdig arbeid', async () => {
    await expect(hentSkiftkoe(klient([], true).supabase, 's', naa)).rejects.toThrow('timeout')
    await expect(hentSkiftkoe(klient([], false, 1000).supabase, 's', naa)).rejects.toThrow()
  })
})
