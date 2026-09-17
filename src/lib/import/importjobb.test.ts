import { describe, expect, it } from 'vitest'
import { finnRaaFil, sikreImportjobb } from './importjobb'

function klient(svar: { data: unknown; error: { message: string; code?: string } | null }[]) {
  const kall: { tabell: string; felt: string; args: unknown[] }[] = []
  const db = { from(tabell: string) {
    const resultat = svar.shift()!
    const q: unknown = new Proxy({}, { get(_t, felt) {
      if (felt === 'then') return Promise.resolve(resultat).then.bind(Promise.resolve(resultat))
      return (...args: unknown[]) => { kall.push({ tabell, felt: String(felt), args }); return q }
    } })
    return q
  } } as unknown as Parameters<typeof sikreImportjobb>[0]
  return { db, kall }
}

describe('råfil uten importjobb kan repareres ved retry', () => {
  it('oppretter manglende jobb og beholder samme råfil og tenant', async () => {
    const { db, kall } = klient([{ data: [], error: null }, { data: { id: 'jobb' }, error: null }])
    expect(await sikreImportjobb(db, 'kjede', 'fil')).toEqual({ jobbId: 'jobb', opprettet: true })
    expect(kall).toContainEqual({ tabell: 'import_jobber', felt: 'eq', args: ['retailer_id', 'kjede'] })
    expect(kall).toContainEqual({ tabell: 'import_jobber', felt: 'insert', args: [{ id: 'fil', raa_fil_id: 'fil', retailer_id: 'kjede' }] })
  })
  it('retry bruker eksisterende jobb uten å opprette eller starte den på nytt', async () => {
    const { db, kall } = klient([{ data: [{ id: 'eksisterende' }], error: null }])
    expect(await sikreImportjobb(db, 'kjede', 'fil')).toEqual({ jobbId: 'eksisterende', opprettet: false })
    expect(kall.some((k) => k.felt === 'insert')).toBe(false)
  })
  it('lesefeil blir ikke tatt for manglende jobb', async () => {
    const { db, kall } = klient([{ data: null, error: { message: 'timeout' } }])
    await expect(sikreImportjobb(db, 'kjede', 'fil')).rejects.toThrow('timeout')
    expect(kall.some((k) => k.felt === 'insert')).toBe(false)
  })
  it('jobbinnsettingsfeil blir aldri bekreftet mottak', async () => {
    const { db } = klient([{ data: [], error: null }, { data: null, error: { message: 'avvist' } }])
    await expect(sikreImportjobb(db, 'kjede', 'fil')).rejects.toThrow('Last opp fila på nytt')
  })
  it('SHA-oppslag er bundet til aktiv fil i egen kjede', async () => {
    const { db, kall } = klient([{ data: [{ id: 'sammefil' }], error: null }])
    expect(await finnRaaFil(db, 'kjede', 'hash')).toBe('sammefil')
    expect(kall).toContainEqual({ tabell: 'raa_filer', felt: 'eq', args: ['retailer_id', 'kjede'] })
    expect(kall).toContainEqual({ tabell: 'raa_filer', felt: 'is', args: ['slettet_tid', null] })
  })
  it('samtidig reparasjon bruker vinnerens jobb og gir ikke dobbel behandling', async () => {
    const { db, kall } = klient([tom(), { data: null, error: { code: '23505', message: 'samtidig insert' } },
      { data: [{ id: 'fil' }], error: null }])
    expect(await sikreImportjobb(db, 'kjede', 'fil')).toEqual({ jobbId: 'fil', opprettet: false })
    expect(kall.filter((k) => k.felt === 'insert')).toHaveLength(1)
  })
})

function tom() { return { data: [], error: null } }
