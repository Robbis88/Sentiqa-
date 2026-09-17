import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentKjede, type Stasjonsrad } from './a1-kjede'

// =====================================================================
// MÅLEPORT OG TILGANGSBEVIS FOR KJEDESTRIPA
//
// To ting bevises her, og de henger sammen:
//
//   1. STRIPA HENTER INGEN STASJONER SELV. Den tar serverens
//      RLS-filtrerte liste som argument. En tellende klient viser at
//      `stasjoner` ALDRI spørres — stripa er ikke et sikkerhetslag, og
//      skal ikke se ut som ett.
//
//   2. RUNDTURENE ER `5N + 1` I VERSTE FALL. Naivt med vilje. Batching
//      er mulig, men «kryss» er relativt per stasjon, og en
//      optimalisering før vi har målt ville vært en gjetning.
// =====================================================================

type Kall = { slag: 'from' | 'rpc'; navn: string }

type Noekkel = { stasjon_id: string; kilde_maaned: string }

/**
 * Rader FULLE nok til at motoren faktisk gjoer jobben sin.
 *
 * Foerste utgave ga bare `stasjon_id` og `kilde_maaned`. Da ble ingen
 * rad `betalt`, `personer` ble tom, og `kryssRader` hoppet over RPC-en -
 * saa rundturstellingen maalte en kjede som aldri skjedde.
 */
const heleVakter = (n: Noekkel[]) => n.map((r, i) => ({
  ...r, lokasjon: 'X', ansatt_nr: '1009', ansatt_navn: 'Lars',
  dato: '2026-08-03', fra_dato: '2026-08-03', fra_tid: '07:00', til_tid: '15:00',
  minutter: 480, lengde_timer: 8, betalt: true,
  avvik_grunn: null, import_jobb_id: null, id: `v${i}`,
}))

const heleRegister = (n: Noekkel[]) => n.map((r) => ({
  ...r, ansatt_nr: '1009', navn: 'Lars', timesats: 210, betalingsfrekvens: 'time',
}))

function fakeKlient(vakter: Noekkel[], register: Noekkel[], kall: Kall[]) {
  const klient = {
    rpc(navn: string) {
      kall.push({ slag: 'rpc', navn })
      return Promise.resolve({ data: [], error: null })
    },
    from(tabell: string) {
      kall.push({ slag: 'from', navn: tabell })
      let rader: Record<string, unknown>[] =
        tabell === 'basisvakt' ? heleVakter(vakter)
          : tabell === 'lonnsregister' ? heleRegister(register)
            : []
      const q = {
        order: () => q,
        select: () => q,
        eq: (kol: string, v: string) => {
          rader = rader.filter((r) => r[kol] === v)
          return q
        },
        in: (kol: string, v: string[]) => {
          rader = rader.filter((r) => v.includes(r[kol] as string))
          return q
        },
        range: (fra: number, til: number) =>
          Promise.resolve({ data: rader.slice(fra, til + 1), error: null }),
      }
      return q
    },
  }
  return klient as unknown as SupabaseClient
}

const stasjon = (n: number): Stasjonsrad =>
  ({ id: `id-${n}`, butikknummer: String(9000 + n), navn: `Stasjon ${n}` })

describe('tilgang — stripa utvider aldri stasjonssettet', () => {
  it('spør ALDRI `stasjoner` selv', async () => {
    const kall: Kall[] = []
    await hentKjede(
      fakeKlient([{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }], [], kall),
      [stasjon(1), stasjon(2)],
    )
    expect(kall.map((k) => k.navn)).not.toContain('stasjoner')
    // Bare de tre tabellene A1 faktisk trenger.
    expect([...new Set(kall.map((k) => k.navn))].sort())
      .toEqual(['a1_registeroppslag', 'ansatt_avtale', 'basisvakt', 'lonnsregister'])
  })

  it('spør bare om de stasjonene den fikk', async () => {
    const kall: Kall[] = []
    const k = await hentKjede(
      fakeKlient(
        [
          { stasjon_id: 'id-1', kilde_maaned: '2026-08' },
          // En stasjon kalleren IKKE ga oss. Den skal aldri dukke opp.
          { stasjon_id: 'id-99', kilde_maaned: '2026-09' },
        ], [], kall,
      ),
      [stasjon(1)],
    )
    expect(k.rader.map((r) => r.id)).toEqual(['id-1'])
    // Og maaneden skal IKKE bli 2026-09, som bare den fremmede har.
    expect(k.maaned).toBe('2026-08')
  })
})

describe('måleport — rundturer og tid', () => {
  it('N=1 med begge kilder: 2 + 1 + 3 = 6', async () => {
    const kall: Kall[] = []
    const k = await hentKjede(
      fakeKlient(
        [{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }],
        [{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }],
        kall,
      ),
      [stasjon(1)],
    )
    expect(kall).toHaveLength(6)
    expect(k.maaling.rundturer).toBe(6)
    expect(k.maaling.stasjoner).toBe(1)
  })

  it('formelen vokser lineært: 5N + 1', async () => {
    const maalt: [number, number][] = []
    for (const n of [1, 2, 5, 10]) {
      const kall: Kall[] = []
      const stasjoner = Array.from({ length: n }, (_, i) => stasjon(i + 1))
      const vakter = stasjoner.map((s) => ({ stasjon_id: s.id, kilde_maaned: '2026-08' }))
      const k = await hentKjede(fakeKlient(vakter, vakter, kall), stasjoner)
      maalt.push([n, k.maaling.rundturer])
      expect(kall.length, `N=${n}`).toBe(k.maaling.rundturer)
    }
    console.log('\n  N -> rundturer: ' + maalt.map(([n, r]) => `${n}->${r}`).join('  ') + '\n')
    expect(maalt).toEqual([[1, 6], [2, 11], [5, 26], [10, 51]])
  })

  it('en stasjon uten arbeidstid koster 2, ikke 3 — RPC-en hoppes over', async () => {
    const kall: Kall[] = []
    // id-1 har begge, id-2 har bare register -> ingen RPC for id-2.
    const k = await hentKjede(
      fakeKlient(
        [{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }],
        [
          { stasjon_id: 'id-1', kilde_maaned: '2026-08' },
          { stasjon_id: 'id-2', kilde_maaned: '2026-08' },
        ],
        kall,
      ),
      [stasjon(1), stasjon(2)],
    )
    // 2N oppdagelse (4) + 1 avtale + 3 (id-1) + 2 (id-2) = 10
    expect(k.maaling.rundturer).toBe(10)
    expect(kall.filter((c) => c.slag === 'rpc')).toHaveLength(1)
  })

  it('ingen kilder i det hele tatt: ingen avtalekall, ingen kildekall', async () => {
    const kall: Kall[] = []
    const k = await hentKjede(fakeKlient([], [], kall), [stasjon(1), stasjon(2)])
    expect(k.maaned).toBeNull()
    expect(k.sum).toEqual({ slag: 'ingen_grunnlag', totalt: 2 })
    // Bare de 2N oppdagelseskallene.
    expect(k.maaling.rundturer).toBe(4)
  })

  it('måler tid, og motortiden er en delmengde av totalen', async () => {
    const kall: Kall[] = []
    const k = await hentKjede(
      fakeKlient(
        [{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }],
        [{ stasjon_id: 'id-1', kilde_maaned: '2026-08' }],
        kall,
      ),
      [stasjon(1)],
    )
    expect(k.maaling.motorMs).toBeGreaterThanOrEqual(0)
    expect(k.maaling.totaltMs).toBeGreaterThanOrEqual(k.maaling.motorMs)
  })
})
