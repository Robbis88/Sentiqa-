import { describe, it, expect } from 'vitest'
import { hentAarstall, fellesStasjoner } from './hent'
import { bpLinjer } from './rader'
import { summer, analyser, type Aarstall } from './analyse'
import type { BpResultat } from '@/lib/parsere/typer'

// =====================================================================
// DE TO VEIENE INN I ANALYSEN MAA GI SAMME SVAR
//
//   fila -> parseBp -> summer()                     ved import
//   fila -> bpLinjer -> basen -> hentAarstall()     ved lesing
//
// Skiller de lag, viser sida andre tall enn importen meldte - og ingen
// av dem sier fra. Derfor kjoeres den SAMME `BpResultat` gjennom begge
// her, og resultatene stilles mot hverandre felt for felt.
//
// Basen etterlignes med en liten klient som svarer paa de spoerringene
// `hentAarstall` faktisk stiller. Det er ikke en ekte database, men det
// er den eneste delen som ikke er ekte: radene kommer fra `bpLinjer`,
// som er nettopp den funksjonen importoeren bruker.
// =====================================================================

const AARGANG_ID = 'aaaa-0000-0000-0000-000000000001'

/**
 * En falsk Supabase-klient som kjenner `bp_aar` og `bp_linje`.
 *
 * `range()` er ikke pynt: `hentAarstall` paginerer med `hentAlle`, og en
 * fake uten `range` ville sett ut som om pagineringen virket mens den i
 * praksis aldri ble brukt.
 */
function fakeKlient(
  aarRader: Record<string, unknown>[],
  linjeRader: Record<string, unknown>[],
) {
  let sidestorrelser: number[] = []
  const klient = {
    sider: () => sidestorrelser,
    from(tabell: string) {
      if (tabell === 'bp_aar') {
        const q = {
          select: () => q,
          eq: () => q,
          in: () => q,
          then: (r: (v: { data: unknown; error: null }) => void) =>
            r({ data: aarRader, error: null }),
        }
        return q
      }
      const q = {
        select: () => q,
        in: () => q,
        order: () => q,
        range: (fra: number, til: number) => {
          const bit = linjeRader.slice(fra, til + 1)
          sidestorrelser.push(bit.length)
          return Promise.resolve({ data: bit, error: null })
        },
      }
      return q
    },
    nullstill() { sidestorrelser = [] },
  }
  return klient
}

/** Den samme BP-en gjennom begge veier. */
async function beggeVeier(bp: BpResultat, format: 'st1_bp25' | 'st1_bp26') {
  const fraFila = summer(bp)
  const aarRader = bp.stasjoner.map((s) => ({
    id: AARGANG_ID, stasjon_id: `st-${s.butikknummer}`,
    timer_aar: s.timerAar, format,
  }))
  const linjeRader = bp.stasjoner.flatMap((s) =>
    bpLinjer(s).map((l) => ({ bp_aar_id: AARGANG_ID, ...l })),
  )
  const k = fakeKlient(aarRader, linjeRader)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const fraBasen = await hentAarstall(k as any, bp.ar!)
  return { fraFila, fraBasen: fraBasen!, linjeRader, klient: k }
}

function maaned(o: {
  maned: number
  kategorier?: { kode: string; post: string; salgKr: number; varekostKr: number }[]
  konti?: { kode: string; post: string; belopKr: number }[]
  timelonnKr?: number
  fastlonnKr?: number
}) {
  const kat = o.kategorier ?? []
  const salgKr = kat.reduce((a, k) => a + k.salgKr, 0)
  const varekostKr = kat.reduce((a, k) => a + k.varekostKr, 0)
  return {
    maned: o.maned, salgKr, varekostKr, bruttoKr: salgKr - varekostKr,
    timelonnKr: o.timelonnKr ?? 0, fastlonnKr: o.fastlonnKr ?? 0,
    kategorier: kat, konti: o.konti ?? [],
  }
}

// BP26-form: loennen splittet i 5012 og 5010, timebudsjett per stasjon.
const BP26: BpResultat = {
  rapporttype: 'st1_bp', ar: 2026,
  stasjoner: [{
    butikknummer: '9038', timerAar: 13877.65,
    maaneder: [
      maaned({
        maned: 1,
        kategorier: [
          { kode: '120', post: '120 Mat', salgKr: 352897.52, varekostKr: 181761.21 },
          { kode: '210', post: '210 Bilvask', salgKr: 100000, varekostKr: 25000 },
        ],
        konti: [
          { kode: '5012', post: '5012 Kostnader', belopKr: 624119 },
          { kode: '5010', post: '5010 Kostnader', belopKr: 155123 },
          { kode: '6420', post: '6420 Kostnader', belopKr: 64651 },
          { kode: '6312', post: '6312 Royalty', belopKr: 95290 },
          { kode: '6315', post: '6315 FSA', belopKr: -205038 },
        ],
        timelonnKr: 624119, fastlonnKr: 155123,
      }),
      maaned({
        maned: 2,
        kategorier: [
          { kode: '120', post: '120 Mat', salgKr: 324980.60, varekostKr: 167382.49 },
        ],
        konti: [{ kode: '5012', post: '5012 Kostnader', belopKr: 600000 }],
        timelonnKr: 600000,
      }),
      ...Array.from({ length: 10 }, (_, i) => maaned({ maned: i + 3 })),
    ],
  }],
}

// BP25-form: HELE loennen paa 5010, ingen timebudsjett.
const BP25: BpResultat = {
  rapporttype: 'st1_bp', ar: 2025,
  stasjoner: [{
    butikknummer: '9038', timerAar: null,
    maaneder: [
      maaned({
        maned: 1,
        kategorier: [
          { kode: '120', post: '120 Mat', salgKr: 330000, varekostKr: 170000 },
          { kode: '210', post: '210 Bilvask', salgKr: 95000, varekostKr: 24000 },
        ],
        konti: [
          { kode: '5010', post: '5010 Site Salary costs', belopKr: 700000 },
          { kode: '6613', post: '6613 Rep & vedlikehold', belopKr: 40204 },
          { kode: '6312', post: '6312 Royalty', belopKr: 82000 },
        ],
      }),
      ...Array.from({ length: 11 }, (_, i) => maaned({ maned: i + 2 })),
    ],
  }],
}

const likt = (a: Aarstall, b: Aarstall) => {
  expect(b.salg).toBeCloseTo(a.salg, 6)
  expect(b.varekost).toBeCloseTo(a.varekost, 6)
  expect(b.brutto).toBeCloseTo(a.brutto, 6)
  expect(b.personal).toBeCloseTo(a.personal, 6)
  expect(b.timelonn).toBeCloseTo(a.timelonn, 6)
  expect(b.fastlonn).toBeCloseTo(a.fastlonn, 6)
  expect(b.andreKostnader).toBeCloseTo(a.andreKostnader, 6)
  expect(b.royalty).toBeCloseTo(a.royalty, 6)
  expect(b.timer).toBeCloseTo(a.timer, 6)
  expect([...b.kategorier].sort()).toEqual([...a.kategorier].sort())
  expect([...b.konti].sort()).toEqual([...a.konti].sort())
}

describe('basen gir samme svar som fila', () => {
  it('KANARIFUGL: BP26 gjennom begge veier', async () => {
    // Skiller de to lag, viser sida andre tall enn importen meldte -
    // og ingen av dem sier fra.
    const { fraFila, fraBasen } = await beggeVeier(BP26, 'st1_bp26')
    likt(fraFila, fraBasen)
    expect(Math.round(fraBasen.salg)).toBe(777878)
    expect(fraBasen.royalty).toBe(95290)
  })

  it('KANARIFUGL: BP25 gjennom begge veier — lønnssplitten oppfinnes ikke', async () => {
    // BP25-malen foerer HELE loennen paa 5010. Leses den som fastloenn,
    // staar 2025 med 700 000 mot BP26s 155 123 - et kutt paa 78 % som
    // aldri har funnet sted.
    const { fraFila, fraBasen } = await beggeVeier(BP25, 'st1_bp25')
    likt(fraFila, fraBasen)
    expect(fraBasen.timelonn).toBe(0)
    expect(fraBasen.fastlonn).toBe(0)
    expect(fraBasen.personal).toBe(700000)
  })

  it('KANARIFUGL: royalty og FSA holdes utenfor kostnadsramma', async () => {
    // FSA staar negativt. Tas den med, ser rammen mindre ut enn den er.
    const { fraBasen } = await beggeVeier(BP26, 'st1_bp26')
    expect(fraBasen.royalty).toBe(95290)
    expect(fraBasen.konti.has('6315')).toBe(false)
    expect(fraBasen.konti.has('6312')).toBe(false)
    expect(fraBasen.andreKostnader).toBe(64651)
  })

  it('KANARIFUGL: en aargang paa over 1000 linjer hentes HEL', async () => {
    // PostgREST kutter i stillhet ved 1000 rader, og en ekte aargang er
    // rundt 2 400 linjer. Uten `hentAlle` ville under halve budsjettet
    // blitt lest - og summen sagt med to desimaler likevel.
    //
    // Fixturen MAA sprenge en side. Med ti rader ville testen vaert
    // groenn enten pagineringen fantes eller ikke, og da maaler den
    // ingenting.
    const mange: BpResultat = {
      rapporttype: 'st1_bp', ar: 2026,
      stasjoner: [{
        butikknummer: '9038', timerAar: 100,
        maaneder: Array.from({ length: 12 }, (_, m) => maaned({
          maned: m + 1,
          kategorier: Array.from({ length: 90 }, (_, i) => ({
            kode: String(1000 + i), post: `Gruppe ${i}`, salgKr: 100, varekostKr: 0,
          })),
        })),
      }],
    }
    const { fraFila, fraBasen, linjeRader, klient } = await beggeVeier(mange, 'st1_bp26')
    expect(linjeRader.length).toBe(12 * 90)
    expect(linjeRader.length).toBeGreaterThan(1000)
    // Mer enn en side hentet, og til sammen alle radene.
    expect(klient.sider().length).toBeGreaterThan(1)
    expect(klient.sider().reduce((a, b) => a + b, 0)).toBe(linjeRader.length)
    // Og det som teller: summen stemmer med fila.
    expect(fraBasen.salg).toBe(12 * 90 * 100)
    likt(fraFila, fraBasen)
  })

  it('gir null når året ikke finnes — ikke en tom årgang', async () => {
    // «Vi har ingen BP for 2025» og «BP-en for 2025 er null kroner» er
    // to helt forskjellige svar, og sida skal kunne skille dem.
    const k = fakeKlient([], [])
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect(await hentAarstall(k as any, 2025)).toBeNull()
  })

  it('analysen leser basens tall like godt som filas', async () => {
    const a = (await beggeVeier(BP25, 'st1_bp25')).fraBasen
    const b = (await beggeVeier(BP26, 'st1_bp26')).fraBasen
    const funn = analyser(a, b)
    expect(funn.length).toBeGreaterThan(0)
    // Uten timer i 2025 skal kr/time ikke loves.
    const lonn = funn.find((f) => f.id === 'lonnsramme')!
    expect(lonn.maalt).toContain('Timerammen står ikke i begge årganger')
  })
})

describe('fellesStasjoner', () => {
  /** En klient som bare kan svare paa `bp_aar` med ar og stasjon. */
  const klientMed = (rader: { ar: number; stasjon_id: string }[]) => {
    const q = {
      select: () => q,
      in: () => q,
      then: (r: (v: { data: unknown; error: null }) => void) => r({ data: rader, error: null }),
    }
    return { from: () => q }
  }

  it('KANARIFUGL: stasjoner som bare finnes i det ene aaret holdes utenfor', async () => {
    // Robert overtok Lone 01.02.25 og Dale 01.04.25. Tas de med, maaler
    // sammenligningen oppkjoep som vekst: «+40 % omsetning» ville vaert
    // to nye stasjoner, ikke en krone mer per stasjon.
    const k = klientMed([
      { ar: 2025, stasjon_id: 'laguneparken' },
      { ar: 2025, stasjon_id: 'varden' },
      { ar: 2025, stasjon_id: 'bones' },
      { ar: 2026, stasjon_id: 'laguneparken' },
      { ar: 2026, stasjon_id: 'varden' },
      { ar: 2026, stasjon_id: 'bones' },
      { ar: 2026, stasjon_id: 'lone' },
      { ar: 2026, stasjon_id: 'dale' },
    ])
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect(await fellesStasjoner(k as any, 2025, 2026))
      .toEqual(['bones', 'laguneparken', 'varden'])
  })

  it('gir tom liste naar det ene aaret mangler helt', async () => {
    const k = klientMed([{ ar: 2026, stasjon_id: 'laguneparken' }])
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect(await fellesStasjoner(k as any, 2025, 2026)).toEqual([])
  })
})
