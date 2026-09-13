// REGENERERINGEN, KJØRT MOT EN FALSK BASE.
//
// =====================================================================
// HVA DENNE MÅLER SOM KILDEVAKTEN IKKE KAN
// =====================================================================
//
// `regenerer.test.ts` leser kildefilene og feller en skriving mot feil
// tabell. Den kan ikke se HVA som skrives — om det bare er juli, om en
// avvist plan står urørt, om to kjøringer gir samme svar.
//
// Her kjøres `regenererMaaned` mot en falsk PostgREST-klient som svarer
// fra fikstur og fanger opp hver upsert. Da måles atferden, ikke formen.
//
// ---------------------------------------------------------------------
// FIRE PÅSTANDER
//
//   1  BARE MÅNEDEN. En stasjon som mangler juli får ikke juni-raden
//      sin skrevet om — og den navngis.
//   2  LÅSEN. Sluppet, sendt og avvist står urørt. Navngitt.
//   3  IDEMPOTENS. To kjøringer gir samme dom, samme tall, samme
//      forklaring, samme kandidater. Bare `beregnetTid` flytter seg.
//   4  PROVENIENSEN. `kilde_jobb_id` på en rad som finnes fra før blir
//      stående — regenereringen har ingen jobb å vise til, og `null`
//      ville slettet pekeren til fila tallene kom fra.
// =====================================================================

import { describe, expect, it } from 'vitest'
import { regenererMaaned } from './regenerer'

// ---------------------------------------------------------------------
// FIKSTUR
// ---------------------------------------------------------------------

const RETAILER = 'r1'
const JULI = '2026-07-01'

const STASJONER = [
  { id: 's-dale', navn: 'St1 Dale', butikknummer: '4185' },
  { id: 's-bones', navn: 'St1 Bønes', butikknummer: '9467' },
  { id: 's-lone', navn: 'St1 Lone', butikknummer: '4177' },
]

/** Sju måneder med tall. Lone mangler juli med vilje. */
function maanedstall() {
  const rader: Record<string, unknown>[] = []
  for (const st of STASJONER) {
    const tom = st.id === 's-lone' ? 6 : 7
    for (let m = 1; m <= tom; m++) {
      rader.push({
        stasjon_id: st.id,
        maaned: `2026-0${m}-01`,
        omsetning_kr: 1_000_000, omsetning_budsjett_kr: 1_000_000,
        brutto_kr: 500_000, matsalg_kr: 400_000,
        matkast_kr: 24_000 + m * 1_000,
        usynlig_rest_kr: 5_000, usynlig_mat_kr: 4_000 + m * 500,
        personal_kr: 300_000 + m * 4_000, personal_budsjett_kr: 300_000,
        paavirkbar_drift_kr: 40_000 + m * 1_500, paavirkbar_drift_budsjett_kr: 40_000,
        resultat_kr: 200_000 - m * 20_000,
        har_svinndata: true, datastatus: 'gruppe',
        avvik_antall: 0, mat_rader: 9,
      })
    }
  }
  return rader
}

const KASTBUDSJETT = STASJONER.map((s) => ({
  stasjon_id: s.id, ar: 2026, kast_pst_av_salg: 0.06, nivaa: 'avdeling',
}))

type Planrad = {
  stasjon_id: string; maaned: string; status: string; kilde_jobb_id: string | null
}

/**
 * En falsk PostgREST-klient.
 *
 * Hvert ledd returnerer seg selv, og objektet er `thenable` — slik den
 * ekte builderen oppfører seg. Svaret velges av TABELLEN, ikke av
 * filtrene: testen skal måle `regenererMaaned`, ikke bygge en
 * spørreplanlegger.
 */
function base(planer: Planrad[]) {
  const upserts: Record<string, unknown>[][] = []

  const svar: Record<string, { data: unknown; error: null }> = {
    stasjoner: { data: STASJONER, error: null },
    v_kurs_maanedstall: { data: maanedstall(), error: null },
    bilagssum: { data: [], error: null },
    royaltysats: { data: { lav_sats: 0.1, hoy_sats_vask: 0.6, pant_sats: 0 }, error: null },
    kastbudsjett: { data: KASTBUDSJETT, error: null },
    maanedsplan: { data: planer, error: null },
  }

  const klient = {
    from(tabell: string) {
      const b: Record<string, unknown> = {}
      for (const ledd of ['select', 'eq', 'in', 'is', 'gte', 'lte', 'order', 'limit']) {
        b[ledd] = () => b
      }
      b.maybeSingle = () => ({
        then: (ok: (v: unknown) => void) => ok(svar[tabell]),
      })
      b.upsert = (rader: Record<string, unknown>[]) => {
        upserts.push(rader)
        return { then: (ok: (v: unknown) => void) => ok({ data: null, error: null }) }
      }
      b.then = (ok: (v: unknown) => void) => ok(svar[tabell])
      return b
    },
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return { klient: klient as any, upserts }
}

const kjor = (planer: Planrad[] = []) => {
  const { klient, upserts } = base(planer)
  return regenererMaaned({ supabase: klient, retailerId: RETAILER, maaned: JULI })
    .then((r) => ({ r, skrevet: upserts.flat() }))
}

// =====================================================================
describe('1  bare måneden det ble spurt om', () => {
  it('skriver juli for de to stasjonene som har juli', async () => {
    const { r, skrevet } = await kjor()
    expect(r.skrevet).toBe(2)
    expect(skrevet).toHaveLength(2)
    expect(new Set(skrevet.map((x) => x.maaned))).toEqual(new Set([JULI]))
  })

  it('og NAVNGIR stasjonen som mangler juli', async () => {
    const { r } = await kjor()
    expect(r.hoppet).toHaveLength(1)
    expect(r.hoppet[0].stasjon).toBe('St1 Lone')
    expect(r.hoppet[0].grunn).toContain('2026-06')
  })

  it('juni-raden til den stasjonen blir IKKE skrevet om', async () => {
    // Dette er den stille feilen veien var åpen for: `byggMaanedsplan`
    // setter `maaned` til siste måned med tall, ikke til den vi spurte
    // om. Uten filteret hadde Lone fått juni-planen sin overskrevet av
    // en handling som lovet «bare juli».
    const { skrevet } = await kjor()
    expect(skrevet.some((x) => x.stasjon_id === 's-lone')).toBe(false)
    expect(skrevet.some((x) => x.maaned === '2026-06-01')).toBe(false)
  })
})

// =====================================================================
describe('2  låsen', () => {
  const laast = (status: string): Planrad[] => [
    { stasjon_id: 's-dale', maaned: JULI, status, kilde_jobb_id: 'jobb-1' },
  ]

  for (const status of ['sluppet', 'sendt', 'avvist']) {
    it(`${status} står urørt, og stasjonen navngis`, async () => {
      const { r, skrevet } = await kjor(laast(status))
      expect(skrevet.some((x) => x.stasjon_id === 's-dale')).toBe(false)
      expect(r.laast).toContain('St1 Dale')
      expect(r.skrevet).toBe(1)
    })
  }

  it('KANARIFUGL: et utkast SKRIVES', async () => {
    // Uten denne ville testene over bestått i en vei som aldri skriver
    // noe i det hele tatt.
    const { r, skrevet } = await kjor([
      { stasjon_id: 's-dale', maaned: JULI, status: 'utkast', kilde_jobb_id: 'jobb-1' },
    ])
    expect(skrevet.some((x) => x.stasjon_id === 's-dale')).toBe(true)
    expect(r.laast).toHaveLength(0)
    expect(r.skrevet).toBe(2)
  })
})

// =====================================================================
describe('3  idempotens', () => {
  it('to kjøringer gir samme plan — bare beregnetTid flytter seg', async () => {
    const a = (await kjor()).skrevet
    const b = (await kjor()).skrevet

    expect(a).toHaveLength(2)
    expect(b).toHaveLength(2)

    const uten = (rad: Record<string, unknown>) => {
      const k = JSON.parse(JSON.stringify(rad)) as Record<string, Record<string, unknown>>
      delete k.matkast.beregnetTid
      delete k.usynlig.beregnetTid
      delete (k as unknown as Record<string, unknown>).oppdatert_tid
      return k
    }

    for (let i = 0; i < a.length; i++) {
      expect(uten(b[i])).toEqual(uten(a[i]))
    }
  })

  it('dom, tall, forklaring og kandidater er de samme', async () => {
    const a = (await kjor()).skrevet
    const b = (await kjor()).skrevet
    for (let i = 0; i < a.length; i++) {
      expect(b[i].dom).toEqual(a[i].dom)
      expect(b[i].ingress).toEqual(a[i].ingress)
      expect(b[i].punkter).toEqual(a[i].punkter)
      expect(b[i].rangering).toEqual(a[i].rangering)
      expect((b[i].matkast as Record<string, unknown>).dom)
        .toEqual((a[i].matkast as Record<string, unknown>).dom)
    }
  })

  it('ingen duplikater: én rad per stasjon og måned', async () => {
    const { skrevet } = await kjor()
    const noekler = skrevet.map((x) => `${x.stasjon_id}|${x.maaned}`)
    expect(new Set(noekler).size).toBe(noekler.length)
  })

  it('upserten kolliderer på (stasjon_id, maaned)', async () => {
    // Uten riktig konfliktnøkkel ville andre kjøring lagt til nye rader
    // i stedet for å oppdatere, og «fem juliplaner» blitt ti.
    const { klient, upserts } = base([])
    const kall: unknown[] = []
    const ekte = klient.from
    klient.from = (t: string) => {
      const b = ekte.call(klient, t)
      const u = b.upsert
      b.upsert = (rader: unknown, opts: unknown) => { kall.push(opts); return u(rader) }
      return b
    }
    await regenererMaaned({ supabase: klient, retailerId: RETAILER, maaned: JULI })
    expect(upserts.flat()).toHaveLength(2)
    expect(kall).toContainEqual({ onConflict: 'stasjon_id,maaned' })
  })
})

// =====================================================================
describe('4  proveniensen står urørt', () => {
  it('kilde_jobb_id beholdes på en rad som finnes fra før', async () => {
    const { skrevet } = await kjor([
      { stasjon_id: 's-dale', maaned: JULI, status: 'utkast', kilde_jobb_id: 'jobb-fra-juli' },
    ])
    const dale = skrevet.find((x) => x.stasjon_id === 's-dale')
    expect(dale?.kilde_jobb_id).toBe('jobb-fra-juli')
  })

  it('en helt ny rad får null, ikke en oppdiktet jobb', async () => {
    const { skrevet } = await kjor()
    for (const rad of skrevet) expect(rad.kilde_jobb_id).toBeNull()
  })

  it('status settes til utkast, aldri til noe annet', async () => {
    const { skrevet } = await kjor()
    for (const rad of skrevet) expect(rad.status).toBe('utkast')
  })
})

// =====================================================================
describe('snapshotet er med', () => {
  it('hver skrevet rad bærer alle tre feltene', async () => {
    const { skrevet } = await kjor()
    for (const rad of skrevet) {
      const m = rad.matkast as Record<string, unknown>
      const u = rad.usynlig as Record<string, unknown>
      expect(m.analyseversjon).toBe('p2-kastbudsjett-1')
      expect(m.beregnetForMaaned).toBe(JULI)
      expect(typeof m.beregnetTid).toBe('string')
      expect(u.analyseversjon).toBe('p2-kastbudsjett-1')
      expect(rad.rangering).toBeTruthy()
      expect(typeof (rad.rangering as Record<string, unknown>).mulig).toBe('boolean')
    }
  })
})

// =====================================================================
describe('måneden valideres før noe skrives', () => {
  it('en ugyldig måned kaster, og ingen upsert skjer', async () => {
    const { klient, upserts } = base([])
    await expect(regenererMaaned({
      supabase: klient, retailerId: RETAILER, maaned: '2026-07-15',
    })).rejects.toThrow(/Ugyldig m/)
    expect(upserts).toHaveLength(0)
  })
})
