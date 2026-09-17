import { expect, test, vi } from 'vitest'
vi.mock('server-only', () => ({}))
import { tellDagRutiner } from './rutiner-dag'
import { hentDagRutiner } from './rutiner-dag'
import type { SupabaseClient } from '@supabase/supabase-js'

test('nevneren bruker skjema, ukedag og opprettelse; teller utelater uvedkommende og duplikater', () => {
  const rutine = (id: string, ekstra = {}) => ({ id, skjema_id: 'morgen', ukedager: [], opprettet_dato: '2026-01-01', ...ekstra })
  const resultat = tellDagRutiner([{ id: 'morgen', ukedager: [] }, { id: 'kveld', ukedager: [] }], [rutine('a'), rutine('b', { skjema_id: 'kveld' }), rutine('ukentlig', { ukedager: [1] }), rutine('ny', { opprettet_dato: '2026-09-18' }), rutine('inaktiv', { skjema_id: 'stengt' }), rutine('uten', { skjema_id: null })], [{ rutine_id: 'a', dato: '2026-09-17' }, { rutine_id: 'a', dato: '2026-09-17' }, { rutine_id: 'ukentlig', dato: '2026-09-17' }], '2026-09-17')
  expect(resultat).toEqual({ totalt: 2, utfort: 1 })
})
test('nattvaktutføring bindes til startdatoen og flyttes ikke til neste dags brøk', () => {
  const skjema = [{ id: 'natt', ukedager: [3] }]
  const rutiner = [{ id: 'n', skjema_id: 'natt', ukedager: [], opprettet_dato: '2026-01-01' }]
  const gjort = [{ rutine_id: 'n', dato: '2026-09-16' }]
  expect(tellDagRutiner(skjema, rutiner, gjort, '2026-09-16')).toEqual({ totalt: 1, utfort: 1 })
  expect(tellDagRutiner(skjema, rutiner, gjort, '2026-09-17')).toEqual({ totalt: 0, utfort: 0 })
})

function klient(feil = false) {
  const data: Record<string, Record<string, unknown>[]> = {
    rutineskjemaer: ['a', 'b'].map(stasjon_id => ({ id: stasjon_id, stasjon_id, aktiv: true, ukedager: [], slettet_tid: null })),
    rutiner: ['a', 'b'].map(stasjon_id => ({ id: stasjon_id, stasjon_id, skjema_id: stasjon_id, ukedager: [], opprettet_dato: '2026-01-01', slettet_tid: null })),
    rutine_utforinger: [{ stasjon_id: 'b', rutine_id: 'b', dato: '2026-09-17' }],
  }
  return { from(tabell: string) {
    let rader = data[tabell]
    const q = { select: () => q, eq: (kolonne: string, verdi: unknown) => { rader = rader.filter(r => r[kolonne] === verdi); return q }, is: (kolonne: string, verdi: unknown) => { rader = rader.filter(r => r[kolonne] === verdi); return q }, limit: () => Promise.resolve(feil ? { data: null, error: { message: 'timeout' } } : { data: rader, error: null }) }
    return q
  } } as unknown as SupabaseClient
}
test('en annen tildelt stasjons utføringer forbedrer ikke valgt stasjons brøk', async () => {
  expect(await hentDagRutiner(klient(), '2026-09-17', 'a')).toEqual({ totalt: 1, utfort: 0 })
  expect(await hentDagRutiner(klient(), '2026-09-17', 'b')).toEqual({ totalt: 1, utfort: 1 })
  expect(await hentDagRutiner(klient(), '2026-09-17')).toEqual({ totalt: 2, utfort: 1 })
})
test('databasefeil blir ikke en vellykket nullbrøk', async () => {
  await expect(hentDagRutiner(klient(true), '2026-09-17', 'a')).rejects.toThrow()
})
