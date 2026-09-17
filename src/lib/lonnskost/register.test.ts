import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentRegister } from './register'
import { beregnArbeidssted } from './arbeidssted'
import { minutterMellom, type Basisstempling } from '@/lib/parsere/basiseksport'

// =====================================================================
// REGISTERET LEST UT AV BASEN
//
// Den unike nøkkelen er (stasjon, måned, nummer). To rader på samme
// nummer i samme måned betyr derfor alltid TO STASJONER — og da er det
// ett av to:
//
//   samme person, to arbeidssteder   fenomen D, helt legitimt
//   to personer, samme nummer        fenomen A, målt i produksjon
//
// 1018 er den andre: Andre Fjørstad (Varden) og Marietta Iacovou
// (Bønes), begge aktive i juli 2026, med sytten måneders overlapp.
// Velges en sats på måfå, blir Andres timer priset til Mariettas pris —
// og resultatet melder seg selv som `datagrunnlag: komplett`. Det er den
// farlige formen: et galt tall som ser helt normalt ut.
//
// Derfor holdes tvetydige numre UTE av det motoren får. Uprisbar er
// synlig; feilpriset er det ikke.
// =====================================================================

type Rad = {
  stasjon_id: string
  ansatt_nr: string
  navn: string
  timesats: number | null
  kilde_maaned: string
  betalingsfrekvens: string | null
}

const VARDEN = 'sss-0000-0000-0000-000000000001'
const BONES = 'sss-0000-0000-0000-000000000002'

/**
 * En falsk klient som svarer på nøyaktig de spørringene `hentRegister`
 * stiller — og som HUSKER dem, så testene kan bevise at måneden faktisk
 * ble filtrert på i basen og ikke etterpå.
 */
function fakeKlient(rader: Rad[]) {
  const sett: { maaned?: string; stasjoner?: readonly string[]; felt?: string[] } = {}
  const sider: number[][] = []
  const klient = {
    spurte: () => sett,
    sider: () => sider,
    from() {
      const q = {
        order: () => q,
        // `select` ER IKKE PYNT. Foerste utgave ignorerte lista og
        // returnerte hele raden uansett - da kunne leseren slutte aa be
        // om en kolonne uten at noe ble roedt. Injeksjonen som fjernet
        // `betalingsfrekvens` fra select-en kom tilbake groenn.
        select: (felt: string) => {
          sett.felt = felt.split(',').map((f) => f.trim())
          return q
        },
        eq: (kol: string, v: string) => {
          if (kol === 'kilde_maaned') sett.maaned = v
          return q
        },
        in: (kol: string, v: readonly string[]) => {
          if (kol === 'stasjon_id') sett.stasjoner = v
          return q
        },
        // `range` ER IKKE PYNT. `hentRegister` sider med `hentAlle`, og
        // en fake uten `range` ville sett ut som om pagineringen virket
        // mens den i praksis aldri ble brukt.
        range: (fra: number, til: number) => {
          sider.push([fra, til])
          const treff = rader
            .filter((x) => x.kilde_maaned === sett.maaned)
            .filter((x) => !sett.stasjoner || sett.stasjoner.includes(x.stasjon_id))
            // Bare de kolonnene spoerringen faktisk bad om.
            .map((x) => Object.fromEntries(
              (sett.felt ?? []).map((f) => [f, (x as Record<string, unknown>)[f]]),
            ))
          return Promise.resolve({ data: treff.slice(fra, til + 1), error: null })
        },
      }
      return q
    },
  }
  return {
    klient: klient as unknown as SupabaseClient,
    spurte: klient.spurte,
    sider: klient.sider,
  }
}

const rad = (p: Partial<Rad> & { stasjon_id: string; ansatt_nr: string }): Rad => ({
  navn: 'A B', timesats: 180, kilde_maaned: '2026-07', betalingsfrekvens: 'time', ...p,
})

describe('hentRegister', () => {
  it('to stasjoner, samme nummer, ULIKE navn → tvetydig og ikke priset', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: VARDEN, ansatt_nr: '1018', navn: 'Andre Fjørstad', timesats: 201.5 }),
      rad({ stasjon_id: BONES, ansatt_nr: '1018', navn: 'Marietta Iacovou', timesats: 168.25 }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.register?.ansatte).toEqual([])
    expect(r.tvetydige).toHaveLength(1)
    expect(r.tvetydige[0].ansattNr).toBe('1018')
    expect(r.tvetydige[0].kandidater.map((k) => k.navn).sort())
      .toEqual(['Andre Fjørstad', 'Marietta Iacovou'])
  })

  it('to stasjoner, samme nummer, ULIK sats → tvetydig selv med samme navn', async () => {
    // Et navn som stemmer beviser ikke at satsen gjør det. Velges én av
    // dem, er halvparten av timene priset feil.
    const { klient } = fakeKlient([
      rad({ stasjon_id: VARDEN, ansatt_nr: '77', navn: 'Trond Vik', timesats: 190 }),
      rad({ stasjon_id: BONES, ansatt_nr: '77', navn: 'Trond Vik', timesats: 205 }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.tvetydige.map((t) => t.ansattNr)).toEqual(['77'])
    expect(r.register?.ansatte).toEqual([])
  })

  it('samme person på to stasjoner er IKKE tvetydig', async () => {
    // Fenomen D: Carmen, Julian og Trond jobber faktisk to steder. Sier
    // begge stasjonene det samme, er det én person — og å kalle det et
    // funn ville lært folk å se bort fra lista.
    const { klient } = fakeKlient([
      rad({ stasjon_id: VARDEN, ansatt_nr: '55', navn: 'Carmen Ruiz', timesats: 138 }),
      rad({ stasjon_id: BONES, ansatt_nr: '55', navn: 'carmen ruiz', timesats: 138 }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.tvetydige).toEqual([])
    expect(r.register?.ansatte).toHaveLength(1)
    expect(r.register?.ansatte[0].timesats).toBe(138)
  })

  it('en rad uten sats er kjent person, ukjent pris', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', navn: 'Ida Nord', timesats: 180 }),
      rad({ stasjon_id: BONES, ansatt_nr: '12', navn: 'Uten Sats', timesats: null }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.register?.ansatte.map((a) => a.ansattNr)).toEqual(['11'])
    expect(r.register?.utenSats.map((u) => u.ansattNr)).toEqual(['12'])
  })

  it('måneden filtreres i BASEN, ikke etterpå', async () => {
    // En avkortet spørring ser ut som en liten stasjon (0090, 0166,
    // 0175). Filtreres måneden i minnet, leses hele tabellen først — og
    // PostgREST kutter uten å feile.
    const { klient, spurte } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', kilde_maaned: '2026-07' }),
    ])
    await hentRegister(klient, '2026-07')
    expect(spurte().maaned).toBe('2026-07')
  })

  it('KANARI: spørringen sider, den henter ikke alt i ett kall', async () => {
    // PostgREST kutter ved tusen rader uten feil. Et avkortet register
    // ser ut som en stasjon med færre ansatte (0090, 0166, 0175).
    const { klient, sider } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11' }),
    ])
    await hentRegister(klient, '2026-07')
    expect(sider()).toEqual([[0, 999]])
  })

  it('en måned uten register gir NULL, ikke et tomt register', async () => {
    // JULIS SNAPSHOT ER IKKE APRILS REGISTER. Et tomt register ville
    // prist ingenting og meldt hver time som ukoblet — altså sett ut som
    // en stasjon uten ansatte. `null` lar motoren kaste sin egen feil.
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', kilde_maaned: '2026-07' }),
    ])
    const r = await hentRegister(klient, '2026-04')
    expect(r.register).toBeNull()
    expect(r.tvetydige).toEqual([])
  })

  it('stasjonsvalget snevrer inn', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: VARDEN, ansatt_nr: '11' }),
      rad({ stasjon_id: BONES, ansatt_nr: '22' }),
    ])
    const r = await hentRegister(klient, '2026-07', [BONES])
    expect(r.register?.ansatte.map((a) => a.ansattNr)).toEqual(['22'])
  })

  it('avviser en måned som ikke er yyyy-mm', async () => {
    const { klient } = fakeKlient([])
    await expect(hentRegister(klient, '2026-7')).rejects.toThrow(/Ugyldig måned/)
  })

  it('perioden omslutter måneden, også i februar', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', kilde_maaned: '2026-02' }),
    ])
    const r = await hentRegister(klient, '2026-02')
    expect(r.register?.fraDato).toBe('2026-02-01')
    expect(r.register?.tilDato).toBe('2026-02-28')
  })
})

// ---------------------------------------------------------------------
// HELE VEIEN: basen → motoren
//
// De to over beviser hver sin halvdel. Denne beviser at de passer
// sammen — at det `hentRegister` returnerer faktisk er noe
// `beregnArbeidssted` godtar, og at et register fra feil måned blir
// avvist av motorens egen vakt i stedet for å prise i det stille.
// ---------------------------------------------------------------------
describe('registeret mater motoren', () => {
  const st = (p: Partial<Basisstempling> & { dato: string }): Basisstempling => {
    const q = {
        order: () => q,
      ansattNr: '11', ansattNavn: 'Ida Nord', lokasjon: 'St1 - Bønes',
      fraTid: '10:00', tilTid: '16:00', betalt: true, fraDato: p.dato, ...p,
    } as Basisstempling
    return { ...q, minutter: minutterMellom(q.fraDato ?? q.dato, q.fraTid, q.tilTid) }
  }

  it('julis register priser julis timer', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', navn: 'Ida Nord', timesats: 200 }),
    ])
    const r = await hentRegister(klient, '2026-07')
    const [b] = beregnArbeidssted({
      maaned: '2026-07',
      avvik: [],
      stemplinger: [st({ dato: '2026-07-01' })],
      registre: r.register ? [r.register] : [],
    })
    expect(b.konto503Kr).toBe(1200)
  })

  it('julis register kan ikke prise april', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', navn: 'Ida Nord', timesats: 200 }),
    ])
    const juli = await hentRegister(klient, '2026-07')
    expect(() => beregnArbeidssted({
      maaned: '2026-04',
      avvik: [],
      stemplinger: [st({ dato: '2026-04-01' })],
      registre: juli.register ? [juli.register] : [],
    })).toThrow(/kan ikke prise 2026-04/)
  })
})

// =====================================================================
// ROUNDTRIP: enheten overlever basen
//
// `timesats` uten `betalingsfrekvens` er et tall uten enhet. Mister
// leseren feltet, er 48 736 og 138 samme slags verdi igjen — og bare
// den ene av dem er en timesats.
// =====================================================================

describe('betalingsfrekvens overlever lesingen', () => {
  it('baerer maaned og time ut av basen', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '118', navn: 'Sandra S',
        timesats: 48736, betalingsfrekvens: 'maaned' }),
      rad({ stasjon_id: BONES, ansatt_nr: '1104265', navn: 'Carmen R',
        timesats: 138, betalingsfrekvens: 'time' }),
    ])
    const r = await hentRegister(klient, '2026-07')
    const sandra = r.register?.ansatte.find((a) => a.ansattNr === '118')
    const carmen = r.register?.ansatte.find((a) => a.ansattNr === '1104265')
    expect(sandra?.betalingsfrekvens).toBe('maaned')
    expect(sandra?.timesats).toBe(48736)
    expect(carmen?.betalingsfrekvens).toBe('time')
  })

  it('en ukjent verdi fra basen blir null, ALDRI time', async () => {
    // Skranken i 0220 tillater bare de to verdiene, men en senere
    // migrasjon kan utvide kolonnen. Da skal leseren si «ukjent», ikke
    // gjette paa timer.
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', betalingsfrekvens: 'uke' }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.register?.ansatte[0].betalingsfrekvens).toBeNull()
  })

  it('null i basen forblir null', async () => {
    // Rader skrevet FOER 0220 har ingen enhet. De skal ikke bli «time».
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', betalingsfrekvens: null }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.register?.ansatte[0].betalingsfrekvens).toBeNull()
  })

  it('ogsaa en rad uten sats baerer enheten', async () => {
    const { klient } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '12', timesats: null,
        betalingsfrekvens: 'maaned' }),
    ])
    const r = await hentRegister(klient, '2026-07')
    expect(r.register?.utenSats[0].betalingsfrekvens).toBe('maaned')
  })
})

describe('den falske klienten maaler select-lista', () => {
  it('KANARI: en kolonne som ikke bes om, finnes ikke i svaret', async () => {
    // Uten dette kunne leseren slutte aa hente `betalingsfrekvens` uten
    // at en eneste test ble roed - faken ville levert feltet likevel.
    const { klient, spurte } = fakeKlient([
      rad({ stasjon_id: BONES, ansatt_nr: '11', betalingsfrekvens: 'maaned' }),
    ])
    await hentRegister(klient, '2026-07')
    expect(spurte().felt, 'leseren maa be om enheten').toContain('betalingsfrekvens')
  })
})
