import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAvtaler } from './avtale'

// =====================================================================
// MÅLT I PRODUKSJON 2026-09-16
//
//   13 rader, på to av fem stasjoner
//   Bønes 10  —  1009, 1018, 1104290 = timelonn, resten null
//   Lone   3  —  118 = fastlonn, satt 2026-09-08
//   9 av 13 har lonnsform = null
//
// `(Lone, 118)` er den eneste raden i hele basen som ENDRER et utfall.
// Derfor er lekkasjevakten bygget på den.
// =====================================================================

type Rad = {
  stasjon_id: string; ansatt_nr: string
  lonnsform: string | null; oppdatert_tid: string | null
}

const LONE = 'sss-0000-0000-0000-000000000003'
const BONES = 'sss-0000-0000-0000-000000000002'

function fakeKlient(rader: Rad[]) {
  const sett: { stasjoner?: readonly string[]; felt?: string[] } = {}
  const sider: number[][] = []
  const klient = {
    spurte: () => sett,
    sider: () => sider,
    from() {
      const q = {
        order: () => q,
        select: (felt: string) => {
          sett.felt = felt.split(',').map((f) => f.trim())
          return q
        },
        in: (kol: string, v: readonly string[]) => {
          if (kol === 'stasjon_id') sett.stasjoner = v
          return q
        },
        range: (fra: number, til: number) => {
          sider.push([fra, til])
          const treff = rader
            .filter((x) => !sett.stasjoner || sett.stasjoner.includes(x.stasjon_id))
            .map((x) => Object.fromEntries(
              (sett.felt ?? []).map((f) => [f, (x as Record<string, unknown>)[f]]),
            ))
          return Promise.resolve({ data: treff.slice(fra, til + 1), error: null })
        },
      }
      return q
    },
  }
  return klient as unknown as SupabaseClient & {
    spurte: () => typeof sett; sider: () => number[][]
  }
}

const SANDRA: Rad = {
  stasjon_id: LONE, ansatt_nr: '118',
  lonnsform: 'fastlonn', oppdatert_tid: '2026-09-08T10:12:33.000Z',
}
const MARIETTA: Rad = {
  stasjon_id: BONES, ansatt_nr: '1018',
  lonnsform: 'timelonn', oppdatert_tid: '2026-09-14T08:00:00.000Z',
}

describe('hentAvtaler — nøkkelen er (stasjon, nummer)', () => {
  it('finner raden på riktig stasjon', async () => {
    const slaaOpp = await hentAvtaler(fakeKlient([SANDRA, MARIETTA]))
    expect(slaaOpp(LONE, '118')).toEqual({
      lonnsform: 'fastlonn', sistSatt: '2026-09-08',
    })
  })

  it('LEKKASJEVAKTEN: (Lone,118) når aldri en 118 på Bønes', async () => {
    // Lekket den på nummer alene, ville en hvilken som helst annen
    // stasjons 118 sluttet å bli timepriset — for lite lønn, altså for
    // stort grønt lønnsrom.
    const slaaOpp = await hentAvtaler(fakeKlient([SANDRA]))
    expect(slaaOpp(BONES, '118')).toBeNull()
  })

  it('Bønes-raden på 1018 når ikke Varden', async () => {
    const slaaOpp = await hentAvtaler(fakeKlient([MARIETTA]))
    expect(slaaOpp('sss-varden', '1018')).toBeNull()
  })

  it('samme nummer på to stasjoner holdes fra hverandre', async () => {
    const slaaOpp = await hentAvtaler(fakeKlient([
      { stasjon_id: LONE, ansatt_nr: '900', lonnsform: 'fastlonn', oppdatert_tid: '2026-01-01' },
      { stasjon_id: BONES, ansatt_nr: '900', lonnsform: 'timelonn', oppdatert_tid: '2026-01-02' },
    ]))
    expect(slaaOpp(LONE, '900')?.lonnsform).toBe('fastlonn')
    expect(slaaOpp(BONES, '900')?.lonnsform).toBe('timelonn')
  })
})

describe('hentAvtaler — ingen rad er ikke fastlønn', () => {
  it('gir null for en person uten rad', async () => {
    const slaaOpp = await hentAvtaler(fakeKlient([SANDRA]))
    expect(slaaOpp(LONE, '1104265')).toBeNull()
  })

  it('bevarer lonnsform null som null', async () => {
    // 9 av 13 rader i produksjon. Uavklart er et spørsmål, ikke en
    // verdi — telte det som fastlønn, ville lønnskosten falt for ni
    // personer i stillhet.
    const slaaOpp = await hentAvtaler(fakeKlient([
      { stasjon_id: BONES, ansatt_nr: '1020', lonnsform: null, oppdatert_tid: '2026-09-06' },
    ]))
    expect(slaaOpp(BONES, '1020')).toEqual({ lonnsform: null, sistSatt: '2026-09-06' })
  })

  it('en ukjent lonnsform blir null, ikke en klassifisering', async () => {
    // Samme innsats som `betalingsfrekvens` i 0220: en verdi vi ikke
    // kjenner igjen er UKJENT.
    const slaaOpp = await hentAvtaler(fakeKlient([
      { stasjon_id: BONES, ansatt_nr: '1020', lonnsform: 'prosentlonn', oppdatert_tid: '2026-09-06' },
    ]))
    expect(slaaOpp(BONES, '1020')?.lonnsform).toBeNull()
  })
})

describe('hentAvtaler — spørringen', () => {
  it('ber om de fire feltene', async () => {
    const k = fakeKlient([SANDRA])
    await hentAvtaler(k)
    expect(k.spurte().felt).toEqual(
      ['stasjon_id', 'ansatt_nr', 'lonnsform', 'oppdatert_tid'],
    )
  })

  it('kutter oppdatert_tid til dato, uten å gjøre den til gyldig-fra', async () => {
    // Tabellen har ingen «gyldig fra». Dette er sist gang raden ble
    // SKREVET, og typen sier ikke noe mer.
    const slaaOpp = await hentAvtaler(fakeKlient([SANDRA]))
    expect(slaaOpp(LONE, '118')?.sistSatt).toBe('2026-09-08')
  })

  it('snevrer inn på stasjon når kalleren ber om det', async () => {
    const k = fakeKlient([SANDRA, MARIETTA])
    const slaaOpp = await hentAvtaler(k, [BONES])
    expect(k.spurte().stasjoner).toEqual([BONES])
    expect(slaaOpp(LONE, '118')).toBeNull()
    expect(slaaOpp(BONES, '1018')?.lonnsform).toBe('timelonn')
  })

  it('SIDER — over tusen avtaler kommer HELE ut', async () => {
    const mange = Array.from({ length: 1200 }, (_, i) => ({
      stasjon_id: BONES, ansatt_nr: `nr${i}`,
      lonnsform: 'timelonn', oppdatert_tid: '2026-01-01',
    }))
    const k = fakeKlient(mange)
    const slaaOpp = await hentAvtaler(k)
    expect(slaaOpp(BONES, 'nr1199')?.lonnsform).toBe('timelonn')
    expect(k.sider().length).toBeGreaterThan(1)
  })
})
