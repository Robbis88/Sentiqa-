import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentA1Maaneder } from './a1-maaneder'

const BONES = 'sss-bones'
const LONE = 'sss-lone'

type Rad = { stasjon_id: string; kilde_maaned: string }

function fakeKlient(vakter: Rad[], register: Rad[]) {
  const sett: { tabeller: string[]; felt: string[]; stasjoner: string[] } = {
    tabeller: [], felt: [], stasjoner: [],
  }
  const klient = {
    spurte: () => sett,
    from(tabell: string) {
      sett.tabeller.push(tabell)
      const kilde = tabell === 'basisvakt' ? vakter : register
      let stasjon: string | null = null
      const q = {
        order: () => q,
        select: (f: string) => { sett.felt.push(f); return q },
        eq: (kol: string, v: string) => {
          if (kol === 'stasjon_id') { stasjon = v; sett.stasjoner.push(v) }
          return q
        },
        // ALT naar filteret mangler, ikke ingenting. En ekte spoerring
        // uten `where` returnerer hele tabellen - og det er nettopp den
        // feilen injeksjonen «kryssregister gjoer en maaned lokal» skal
        // avsloere. Foerste utgave returnerte tom liste, og gjorde
        // injeksjonen til en no-op.
        range: (fra: number, til: number) => Promise.resolve({
          data: (stasjon === null
            ? kilde
            : kilde.filter((r) => r.stasjon_id === stasjon)).slice(fra, til + 1),
          error: null,
        }),
      }
      return q
    },
  }
  return klient as unknown as SupabaseClient & { spurte: () => typeof sett }
}

describe('hentA1Maaneder — oppdager, avgjør ingenting', () => {
  it('finner måneder fra BEGGE kildene', async () => {
    // Bønes: basisvakt august OG register august.
    expect(await hentA1Maaneder(fakeKlient(
      [{ stasjon_id: BONES, kilde_maaned: '2026-08' }],
      [{ stasjon_id: BONES, kilde_maaned: '2026-08' }],
    ), BONES)).toEqual(['2026-08'])
  })

  it('bare arbeidstid er nok — Laguneparken', async () => {
    // hentKilder gir deretter mangler_register. Det er IKKE denne filas
    // jobb å vite det.
    expect(await hentA1Maaneder(fakeKlient(
      [{ stasjon_id: BONES, kilde_maaned: '2026-08' }], [],
    ), BONES)).toEqual(['2026-08'])
  })

  it('bare register er nok — Lone', async () => {
    expect(await hentA1Maaneder(fakeKlient(
      [], [{ stasjon_id: BONES, kilde_maaned: '2026-07' }],
    ), BONES)).toEqual(['2026-07'])
  })

  it('KRYSSREGISTER teller ikke som en lokal måned', async () => {
    // Carmens registerrad ligger på LONE. Den skal ikke gjøre september
    // til en Bønes-måned — da ville oppdagelsen smittet mellom
    // stasjoner, og en stasjon uten en eneste egen kilde kunne dukket
    // opp med en måned den ikke har.
    const k = fakeKlient(
      [{ stasjon_id: BONES, kilde_maaned: '2026-08' }],
      [{ stasjon_id: LONE, kilde_maaned: '2026-09' }],
    )
    expect(await hentA1Maaneder(k, BONES)).toEqual(['2026-08'])
  })

  it('en stasjon uten kilder gir tom liste, ikke en gjettet måned', async () => {
    expect(await hentA1Maaneder(fakeKlient([], []), 'sss-dale')).toEqual([])
  })
})

describe('formen på svaret', () => {
  it('unik og sortert, nyeste først', async () => {
    const k = fakeKlient(
      [
        { stasjon_id: BONES, kilde_maaned: '2026-07' },
        { stasjon_id: BONES, kilde_maaned: '2026-08' },
        { stasjon_id: BONES, kilde_maaned: '2026-07' },
      ],
      [{ stasjon_id: BONES, kilde_maaned: '2026-08' }],
    )
    expect(await hentA1Maaneder(k, BONES)).toEqual(['2026-08', '2026-07'])
  })

  it('en måned med ugyldig form slipper ikke gjennom', async () => {
    const k = fakeKlient(
      [
        { stasjon_id: BONES, kilde_maaned: '2026-08' },
        { stasjon_id: BONES, kilde_maaned: '2026-13' },
        { stasjon_id: BONES, kilde_maaned: 'august' },
      ], [],
    )
    expect(await hentA1Maaneder(k, BONES)).toEqual(['2026-08'])
  })

  it('spør begge tabellene, og bare om måneden', async () => {
    const k = fakeKlient([{ stasjon_id: BONES, kilde_maaned: '2026-08' }], [])
    await hentA1Maaneder(k, BONES)
    expect(k.spurte().tabeller.sort()).toEqual(['basisvakt', 'lonnsregister'])
    expect(k.spurte().felt).toEqual(['kilde_maaned', 'kilde_maaned'])
    expect(k.spurte().stasjoner).toEqual([BONES, BONES])
  })

  it('filtrerer stasjonen i basen, ikke etterpå', async () => {
    const k = fakeKlient(
      [
        { stasjon_id: BONES, kilde_maaned: '2026-08' },
        { stasjon_id: LONE, kilde_maaned: '2026-01' },
      ], [],
    )
    expect(await hentA1Maaneder(k, BONES)).toEqual(['2026-08'])
    expect(k.spurte().stasjoner).toContain(BONES)
  })
})
