import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentA1Maaneder } from './a1-maaneder'
import { hentKilder } from './kilder'
import { hentAvtaler } from './avtale'
import { a1ForStasjonsmaaned } from './a1'
import { tilA1Kort } from './a1-kort'

// =====================================================================
// MAALEHARNESS FOR B2e.1 - IKKE EN VAKT
//
// Den teller KALL og maaler REGNETID. Den beviser ingen forretningsregel,
// og den skal ikke leses som et produksjonsbevis: dataene er syntetiske,
// formet som Boenes august 2026 (107 rader, 13 personer, 41 926 betalte
// minutter), men de ER IKKE fasiten. Fasiten bevises mot produksjon.
//
// Klienten er en teller, ikke en database. I/O er dermed ~0, og tiden
// som maales er REGNETID - ikke responstid.
// =====================================================================

const BONES = 'sss-bones'
const LONE = 'sss-lone'
const MAANED = '2026-08'

const PERSONER = 13
const RADER = 107
const BETALTE_MINUTTER = 41926

type Kall = { slag: 'from' | 'rpc'; navn: string }

function bonesformet() {
  // 107 rader fordelt paa 13 personer, alle paa hver sin dato slik at
  // ingen av dem utloeser dublettregelen.
  const vakter: Record<string, unknown>[] = []
  let igjen = BETALTE_MINUTTER
  for (let i = 0; i < RADER; i++) {
    const p = i % PERSONER
    const dag = String(Math.floor(i / PERSONER) + 1).padStart(2, '0')
    const min = i === RADER - 1 ? igjen : 392
    igjen -= min
    vakter.push({
      stasjon_id: BONES, kilde_maaned: MAANED, lokasjon: 'St1 - Bønes',
      ansatt_nr: String(1000 + p), ansatt_navn: `Person ${p}`,
      dato: `2026-08-${dag}`, fra_dato: `2026-08-${dag}`,
      fra_tid: '07:00', til_tid: '15:00',
      minutter: min, lengde_timer: min / 60,
      betalt: true, avvik_grunn: null, import_jobb_id: null,
    })
  }
  // Ti lokale i registeret, to paa Lone (kryss), en helt uten.
  const egne = Array.from({ length: 10 }, (_, p) => ({
    stasjon_id: BONES, kilde_maaned: MAANED, ansatt_nr: String(1000 + p),
    navn: `Person ${p}`, timesats: 210, betalingsfrekvens: 'time',
  }))
  const kryss = [10, 11].map((p) => ({
    stasjon_id: LONE, kilde_maaned: MAANED, ansatt_nr: String(1000 + p),
    navn: `Person ${p}`, timesats: 138, betalingsfrekvens: 'time',
  }))
  return { vakter, egne, kryss }
}

function tellendeKlient(v: ReturnType<typeof bonesformet>) {
  const kall: Kall[] = []
  const klient = {
    kall: () => kall,
    rpc(navn: string) {
      kall.push({ slag: 'rpc', navn })
      return Promise.resolve({ data: v.kryss, error: null })
    },
    from(tabell: string) {
      kall.push({ slag: 'from', navn: tabell })
      let rader: Record<string, unknown>[] =
        tabell === 'basisvakt' ? v.vakter
          : tabell === 'lonnsregister' ? v.egne
            : []
      const q = {
        select: () => q,
        eq: (kol: string, val: string) => {
          rader = rader.filter((r) => r[kol] === val)
          return q
        },
        in: (kol: string, verdier: string[]) => {
          rader = rader.filter((r) => verdier.includes(r[kol] as string))
          return q
        },
        range: (fra: number, til: number) =>
          Promise.resolve({ data: rader.slice(fra, til + 1), error: null }),
      }
      return q
    },
  }
  return klient as unknown as SupabaseClient & { kall: () => Kall[] }
}

describe('B2e.1 — hva blokka faktisk koster', () => {
  it('teller kall og maaler regnetid for EN stasjonsmaaned', async () => {
    const v = bonesformet()
    const k = tellendeKlient(v)

    const t0 = performance.now()
    const maaneder = await hentA1Maaneder(k, BONES)
    const avtale = await hentAvtaler(k, [BONES])
    const kortene = []
    let motortid = 0
    for (const m of maaneder) {
      const kilder = await hentKilder(k, BONES, m)
      const t = performance.now()
      const res = a1ForStasjonsmaaned(kilder, avtale)
      motortid += performance.now() - t
      kortene.push(tilA1Kort(res))
    }
    const total = performance.now() - t0

    // KALLENE TELLES FOER oppvarmingsmaalingen under, som selv gjoer
    // flere kall og ellers ville forurenset tellingen.
    const kall = [...k.kall()]

    // KALD MOT VARM. Det foerste kallet betaler JIT og oppbyggingen av
    // helligdagstabellen. En stasjon med tolv maaneder betaler den EN
    // gang, ikke tolv - saa et kaldt tall alene ville overdrevet
    // kostnaden ved en lang serie.
    const kilder = await hentKilder(k, BONES, MAANED)
    const varme: number[] = []
    for (let i = 0; i < 5; i++) {
      const t = performance.now()
      a1ForStasjonsmaaned(kilder, avtale)
      varme.push(performance.now() - t)
    }
    const varm = varme.reduce((a, b) => a + b, 0) / varme.length
    const tabeller = kall.filter((c) => c.slag === 'from').map((c) => c.navn)
    const rpcer = kall.filter((c) => c.slag === 'rpc').map((c) => c.navn)

    console.log([
      '',
      '  B2e.1 MAALING (syntetisk, Boenes-formet - IKKE fasiten)',
      `  A1-maaneder funnet .......... ${maaneder.length}  ${JSON.stringify(maaneder)}`,
      `  rader inn ................... ${v.vakter.length}`,
      `  betalte minutter ............ ${BETALTE_MINUTTER}`,
      `  DB-kall (from) .............. ${tabeller.length}  ${JSON.stringify(tabeller)}`,
      `  RPC-kall .................... ${rpcer.length}  ${JSON.stringify(rpcer)}`,
      `  regnetid, motor (kald) ...... ${motortid.toFixed(2)} ms`,
      `  regnetid, motor (varm, n=5) . ${varm.toFixed(2)} ms`,
      `  regnetid, hele blokka ....... ${total.toFixed(2)} ms  (I/O ~0)`,
      '',
    ].join('\n'))

    expect(maaneder).toEqual([MAANED])
    // 2 oppdagelseskall + 1 avtalekall + 2 kildekall per maaned.
    expect(tabeller).toEqual([
      'basisvakt', 'lonnsregister', 'ansatt_avtale', 'basisvakt', 'lonnsregister',
    ])
    expect(rpcer).toEqual(['a1_registeroppslag'])

    const kort = kortene[0]
    if (kort.status === 'kildemangel') throw new Error('feil')
    expect(kort.betalteTimer).toBe(Math.round(BETALTE_MINUTTER / 60 * 100) / 100)
  })
})
