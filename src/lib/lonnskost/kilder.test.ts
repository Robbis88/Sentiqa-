import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentKilder } from './kilder'

// =====================================================================
// PRODUKSJONSTILSTANDEN 2026-09-16, MÅLT
//
//   Bønes        2026-08    698,8 t    0 eget register
//   Laguneparken 2026-08   1290,5 t    0 eget register
//   Lone         2026-07        0 t   18 register
//   Lone         2026-08        0 t   20 register
//
// Hver annen (stasjon, måned) er `mangler_begge`.
//
// ---------------------------------------------------------------------
// CARMEN ER KANARIFUGLEN FOR PORTEN
//
// Bønes august har arbeidstid og null eget register, mens Lones
// augustregister finnes og inneholder henne. Lot kryss åpne porten,
// ville måneden blitt godkjent med 24,7 av 698,6 timer dekket — 3,5 %,
// to personer av tretten — og et 503-tall som så helt normalt ut.
// =====================================================================

type Vakt = {
  stasjon_id: string; kilde_maaned: string; lokasjon: string
  ansatt_nr: string; ansatt_navn: string; dato: string
  fra_dato: string; fra_tid: string; til_tid: string
  minutter: number; lengde_timer: number | null
  betalt: boolean; avvik_grunn: string | null; import_jobb_id: string | null
}
type Reg = {
  stasjon_id: string; kilde_maaned: string; ansatt_nr: string
  navn: string; timesats: number | null; betalingsfrekvens: string | null
}

const BONES = 'sss-0000-0000-0000-000000000002'
const LONE = 'sss-0000-0000-0000-000000000003'

/** Fake som betjener BEGGE tabellene og holder filtrene fra hverandre. */
function fakeKlient(vakter: Vakt[], register: Reg[]) {
  const klient = {
    from(tabell: string) {
      const rader: Record<string, unknown>[] = tabell === 'basisvakt' ? vakter : register
      const filtre: { kol: string; verdi: string | readonly string[]; inn: boolean }[] = []
      let felt: string[] = []
      const q = {
        select: (f: string) => { felt = f.split(',').map((x) => x.trim()); return q },
        eq: (kol: string, v: string) => { filtre.push({ kol, verdi: v, inn: false }); return q },
        in: (kol: string, v: readonly string[]) => { filtre.push({ kol, verdi: v, inn: true }); return q },
        range: (fra: number, til: number) => {
          const treff = rader
            .filter((r) => filtre.every((f) => (f.inn
              ? (f.verdi as readonly string[]).includes(r[f.kol] as string)
              : r[f.kol] === f.verdi)))
            .map((r) => Object.fromEntries(felt.map((f) => [f, r[f]])))
          return Promise.resolve({ data: treff.slice(fra, til + 1), error: null })
        },
      }
      return q
    },
  }
  return klient as unknown as SupabaseClient
}

const vakt = (o: Partial<Vakt> = {}): Vakt => ({
  stasjon_id: BONES, kilde_maaned: '2026-08', lokasjon: 'St1 - Bønes',
  ansatt_nr: '1009', ansatt_navn: 'Ola Nordmann', dato: '2026-08-03',
  fra_dato: '2026-08-03', fra_tid: '07:00:00', til_tid: '15:00:00',
  minutter: 480, lengde_timer: 8, betalt: true, avvik_grunn: null,
  import_jobb_id: 'jobb-1', ...o,
})
const reg = (o: Partial<Reg> = {}): Reg => ({
  stasjon_id: BONES, kilde_maaned: '2026-08', ansatt_nr: '1009',
  navn: 'Ola Nordmann', timesats: 210, betalingsfrekvens: 'time', ...o,
})

const CARMEN_VAKT = vakt({ ansatt_nr: '1104265', ansatt_navn: 'Carmen Valentina Toro' })
const CARMEN_REG = reg({
  stasjon_id: LONE, ansatt_nr: '1104265',
  navn: 'Carmen Valentina Toro', timesats: 138,
})

describe('porten: kryssregister åpner den ALDRI', () => {
  it('Bønes august blir mangler_register selv om Lone har Carmen', async () => {
    const ut = await hentKilder(
      fakeKlient([CARMEN_VAKT], [CARMEN_REG]), BONES, '2026-08',
    )
    expect(ut.status).toBe('mangler_register')
  })

  it('mangler_register bærer timene og personene, og tier ikke', async () => {
    // Bønes august skal kunne si «698,8 kjente timer, ingen sats».
    const ut = await hentKilder(
      fakeKlient(
        // 41 448 + Carmens 480 = 41 928 minutter = 698,8 timer.
        [vakt({ minutter: 41_448 }), CARMEN_VAKT],
        [CARMEN_REG],
      ), BONES, '2026-08',
    )
    if (ut.status !== 'mangler_register') throw new Error('feil status')
    expect(ut.timer).toBe(698.8)
    expect(ut.personer).toBe(2)
  })

  it('mangler_register viser kryssradene som IKKE fikk åpne porten', async () => {
    const ut = await hentKilder(
      fakeKlient([CARMEN_VAKT], [CARMEN_REG]), BONES, '2026-08',
    )
    if (ut.status !== 'mangler_register') throw new Error('feil status')
    expect(ut.kryss).toHaveLength(1)
    expect(ut.kryss[0].stasjonId).toBe(LONE)
  })

  it('mangler_register har ikke noe kostnadsfelt i det hele tatt', async () => {
    const ut = await hentKilder(
      fakeKlient([CARMEN_VAKT], [CARMEN_REG]), BONES, '2026-08',
    )
    expect(Object.keys(ut)).not.toContain('konto503Kr')
  })
})

describe('de fire tilstandene', () => {
  it('begge — eget register og arbeidstid', async () => {
    const ut = await hentKilder(fakeKlient([vakt()], [reg()]), BONES, '2026-08')
    expect(ut.status).toBe('begge')
  })

  it('mangler_arbeidstid — Lone juli har 18 registerrader og null vakter', async () => {
    const ut = await hentKilder(
      fakeKlient([], [reg({ stasjon_id: LONE, kilde_maaned: '2026-07' })]),
      LONE, '2026-07',
    )
    expect(ut.status).toBe('mangler_arbeidstid')
  })

  it('mangler_begge — Dale, hvilken som helst måned', async () => {
    const ut = await hentKilder(fakeKlient([], []), 'sss-dale', '2026-08')
    expect(ut.status).toBe('mangler_begge')
  })

  it('mangler_begge klassifiseres ALDRI som én av de to', async () => {
    // Sjekkes ikke dette først, blir halve mangelen borte.
    const ut = await hentKilder(fakeKlient([], []), 'sss-dale', '2026-08')
    expect(ut.status).not.toBe('mangler_register')
    expect(ut.status).not.toBe('mangler_arbeidstid')
  })
})

describe('kryss er dekning inne i en måned som har bestått porten', () => {
  it('Carmen havner i kryss når Bønes HAR sitt eget register', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt(), CARMEN_VAKT], [reg(), CARMEN_REG]), BONES, '2026-08',
    )
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.egne.map((r) => r.ansattNr)).toEqual(['1009'])
    expect(ut.register.kryss.map((r) => r.ansattNr)).toEqual(['1104265'])
  })

  it('kryss hentes bare for numre som FAKTISK arbeidet her', async () => {
    // Vi henter aldri en annen stasjons register i sin helhet.
    const ut = await hentKilder(
      fakeKlient(
        [vakt()],
        [reg(), CARMEN_REG, reg({ stasjon_id: LONE, ansatt_nr: '118', navn: 'Sandra' })],
      ), BONES, '2026-08',
    )
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.kryss).toHaveLength(0)
  })

  it('en registerrad fra samme stasjon er aldri kryss', async () => {
    const ut = await hentKilder(fakeKlient([vakt()], [reg()]), BONES, '2026-08')
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.kryss).toHaveLength(0)
    expect(ut.register.egne).toHaveLength(1)
  })
})

describe('uslaatteNumre — RLS-skjevheten skal være målbar', () => {
  it('numre som arbeidet her og ikke finnes noe sted rapporteres', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt(), vakt({ ansatt_nr: '9999', ansatt_navn: 'Ukjent' })], [reg()]),
      BONES, '2026-08',
    )
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.uslaatteNumre).toEqual(['9999'])
  })

  it('en butikksjef som ikke ser Lone får Carmen i uslaatteNumre', async () => {
    // Samme data, to svar: `lonnsregister_les` krever
    // `stasjon_id in (select mine_stasjoner())`. Her simulert ved at
    // Lones rad ikke finnes i det klienten kan lese. Forskjellen skal
    // være SYNLIG til B2c2 fjerner den.
    const ut = await hentKilder(
      fakeKlient([vakt(), CARMEN_VAKT], [reg()]), BONES, '2026-08',
    )
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.uslaatteNumre).toEqual(['1104265'])
    expect(ut.register.kryss).toHaveLength(0)
  })

  it('en som ER slått opp står ikke som uslått', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt(), CARMEN_VAKT], [reg(), CARMEN_REG]), BONES, '2026-08',
    )
    if (ut.status !== 'begge') throw new Error('feil status')
    expect(ut.register.uslaatteNumre).toEqual([])
  })
})

describe('kilder — formen', () => {
  it('kaster på ugyldig måned', async () => {
    await expect(hentKilder(fakeKlient([], []), BONES, 'august'))
      .rejects.toThrow(/Ugyldig måned/)
  })

  it('bare stasjonens egen måned teller', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt()], [reg({ kilde_maaned: '2026-07' })]), BONES, '2026-08',
    )
    expect(ut.status).toBe('mangler_register')
  })

  it('bare stasjonens egen arbeidstid teller', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt({ stasjon_id: LONE })], [reg()]), BONES, '2026-08',
    )
    expect(ut.status).toBe('mangler_arbeidstid')
  })

  it('ubetalte rader alene gir ingen personer, men er fortsatt arbeidstid', async () => {
    const ut = await hentKilder(
      fakeKlient([vakt({ betalt: false })], []), BONES, '2026-08',
    )
    if (ut.status !== 'mangler_register') throw new Error('feil status')
    expect(ut.timer).toBe(0)
    expect(ut.personer).toBe(0)
    expect(ut.arbeidstid.rader).toHaveLength(1)
  })
})
