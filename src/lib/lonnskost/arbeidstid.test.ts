import { describe, expect, it } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentArbeidstid } from './arbeidstid'

// =====================================================================
// LESEREN ER IKKE STEDET DER ARBEID FORSVINNER
//
// Tallene er målt mot de ekte Basis Export-filene 2026-09-16:
//
//   Bønes 2025-12-13, nr 1009, 09:10–11:00
//     intervallet   1,83 t     fila sier  25,82 t     -> avvik_grunn
//   Laguneparken august: 13 av 193 rader krysser døgnet = 6,7 %
//   Bønes august i produksjon: 107 rader, 698,8 betalte timer
// =====================================================================

type Rad = {
  stasjon_id: string; kilde_maaned: string; lokasjon: string
  ansatt_nr: string; ansatt_navn: string; dato: string
  fra_dato: string; fra_tid: string; til_tid: string
  minutter: number; lengde_timer: number | null
  betalt: boolean; avvik_grunn: string | null; import_jobb_id: string | null
}

const BONES = 'sss-0000-0000-0000-000000000002'
const LONE = 'sss-0000-0000-0000-000000000003'

/**
 * En falsk klient som svarer på nøyaktig det `hentArbeidstid` spør om.
 *
 * Den HONORERER `select`-lista og HUSKER `range`-kallene. Uten det ville
 * en leser som sluttet å be om en kolonne — eller som droppet
 * pagineringen — bestått testen.
 */
function fakeKlient(rader: Rad[]) {
  const sett: { maaned?: string; stasjoner?: readonly string[]; felt?: string[] } = {}
  const sider: number[][] = []
  const klient = {
    spurte: () => sett,
    sider: () => sider,
    from() {
      const q = {
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
        range: (fra: number, til: number) => {
          sider.push([fra, til])
          const treff = rader
            .filter((x) => x.kilde_maaned === sett.maaned)
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

const rad = (o: Partial<Rad> = {}): Rad => ({
  stasjon_id: BONES, kilde_maaned: '2026-08', lokasjon: 'St1 - Bønes',
  ansatt_nr: '1009', ansatt_navn: 'Ola Nordmann', dato: '2026-08-03',
  fra_dato: '2026-08-03', fra_tid: '07:00:00', til_tid: '15:00:00',
  minutter: 480, lengde_timer: 8, betalt: true, avvik_grunn: null,
  import_jobb_id: 'jobb-1', ...o,
})

describe('hentArbeidstid — ingenting forsvinner', () => {
  it('returnerer rader med avvik_grunn', async () => {
    // Bønes 2025-12-13: fila sier 25,82 t, intervallet er 1,83 t.
    // Filtrerte leseren den bort, ville B2d aldri fått gjort måneden
    // til `minimum` — og en ukjent kostnad ville sett ut som fravær.
    const ut = await hentArbeidstid(fakeKlient([
      rad(),
      rad({
        dato: '2026-08-13', fra_dato: '2026-08-13', fra_tid: '09:10:00',
        til_tid: '11:00:00', minutter: 110, lengde_timer: 25.82,
        avvik_grunn: 'lengde',
      }),
    ]), '2026-08')
    expect(ut?.rader).toHaveLength(2)
    expect(ut?.rader.filter((r) => r.avvikGrunn === 'lengde')).toHaveLength(1)
  })

  it('skiller prisbare, avviste og betalte minutter', async () => {
    const ut = await hentArbeidstid(fakeKlient([
      rad({ minutter: 480 }),
      rad({ minutter: 110, avvik_grunn: 'lengde' }),
      rad({ minutter: 30, betalt: false }),
    ]), '2026-08')
    expect(ut?.prisbareMinutter).toBe(480)
    expect(ut?.avvisteMinutter).toBe(110)
    expect(ut?.betalteMinutter).toBe(590)
  })

  it('returnerer ubetalte rader med betalt intakt', async () => {
    // Pause er ikke kostnad og skal ikke prises. Men totalene for
    // måneden skal kunne vises, så filtreringen hører hjemme der
    // beslutningen tas — ikke i leseren.
    const ut = await hentArbeidstid(fakeKlient([
      rad(), rad({ minutter: 30, betalt: false }),
    ]), '2026-08')
    expect(ut?.rader).toHaveLength(2)
    expect(ut?.rader.some((r) => r.betalt === false)).toBe(true)
  })

  it('teller bare betalte rader som personer', async () => {
    const ut = await hentArbeidstid(fakeKlient([
      rad({ ansatt_nr: '1009' }),
      rad({ ansatt_nr: '1020', betalt: false }),
    ]), '2026-08')
    expect(ut?.personer).toEqual(['1009'])
  })
})

describe('hentArbeidstid — de to datoene og de to lengdene', () => {
  it('beholder BÅDE forretningsdato og fra_dato ved døgnkryss', async () => {
    // `dato` grupperer som kronefila gjør. `fraDato` avgjør hvilke
    // tilleggssatser vakten får. Målt: 13 av 193 rader på Laguneparken
    // august krysser døgnet.
    const ut = await hentArbeidstid(fakeKlient([rad({
      dato: '2026-08-31', fra_dato: '2026-09-01', fra_tid: '23:00:00',
      til_tid: '07:00:00', minutter: 480,
    })]), '2026-08')
    expect(ut?.rader[0].dato).toBe('2026-08-31')
    expect(ut?.rader[0].fraDato).toBe('2026-09-01')
  })

  it('beholder lengde_timer ved siden av minutter, ikke i stedet for', async () => {
    // Minutter er grunnlaget, lengde_timer er observasjonen. Den ene
    // skal kunne motsi den andre — det er slik avviket blir synlig.
    const ut = await hentArbeidstid(fakeKlient([rad({
      minutter: 110, lengde_timer: 25.82, avvik_grunn: 'lengde',
    })]), '2026-08')
    expect(ut?.rader[0].minutter).toBe(110)
    expect(ut?.rader[0].lengdeTimer).toBe(25.82)
  })

  it('lengde_timer kan være null uten å bli 0', async () => {
    const ut = await hentArbeidstid(fakeKlient([rad({ lengde_timer: null })]), '2026-08')
    expect(ut?.rader[0].lengdeTimer).toBeNull()
  })

  it('kutter klokkeslett til hh:mm og dato til yyyy-mm-dd', async () => {
    const ut = await hentArbeidstid(fakeKlient([rad()]), '2026-08')
    expect(ut?.rader[0].fraTid).toBe('07:00')
    expect(ut?.rader[0].tilTid).toBe('15:00')
    expect(ut?.rader[0].dato).toBe('2026-08-03')
  })
})

describe('hentArbeidstid — arbeidsstedet er ikke stasjonen', () => {
  it('beholder lokasjon separat fra stasjonId', async () => {
    // Hele grunnen til at `basisvakt` finnes: Carmen står i Lones fil og
    // arbeidet på Bønes.
    const ut = await hentArbeidstid(fakeKlient([rad({
      stasjon_id: LONE, lokasjon: 'St1 - Bønes', ansatt_nr: '1104265',
    })]), '2026-08')
    expect(ut?.rader[0].stasjonId).toBe(LONE)
    expect(ut?.rader[0].lokasjon).toBe('St1 - Bønes')
  })
})

describe('hentArbeidstid — spørringen', () => {
  it('ber om hvert felt motoren trenger', async () => {
    // `select` er ikke pynt. Slutter leseren å be om en kolonne, blir
    // den `undefined` og forsvinner i stillhet.
    const k = fakeKlient([rad()])
    await hentArbeidstid(k, '2026-08')
    for (const felt of [
      'stasjon_id', 'kilde_maaned', 'lokasjon', 'ansatt_nr', 'ansatt_navn',
      'dato', 'fra_dato', 'fra_tid', 'til_tid', 'minutter', 'lengde_timer',
      'betalt', 'avvik_grunn', 'import_jobb_id',
    ]) expect(k.spurte().felt).toContain(felt)
  })

  it('filtrerer måneden i basen, ikke etterpå', async () => {
    const k = fakeKlient([rad(), rad({ kilde_maaned: '2026-07' })])
    const ut = await hentArbeidstid(k, '2026-08')
    expect(k.spurte().maaned).toBe('2026-08')
    expect(ut?.rader).toHaveLength(1)
  })

  it('snevrer inn på stasjon når kalleren ber om det', async () => {
    const k = fakeKlient([rad({ stasjon_id: BONES }), rad({ stasjon_id: LONE })])
    const ut = await hentArbeidstid(k, '2026-08', [BONES])
    expect(k.spurte().stasjoner).toEqual([BONES])
    expect(ut?.rader).toHaveLength(1)
  })

  it('SIDER — over tusen rader kommer HELE ut', async () => {
    // PostgREST kutter ved tusen uten å feile. Et avkortet grunnlag ser
    // ut som en rolig måned.
    const mange = Array.from({ length: 1500 }, (_, i) =>
      rad({ ansatt_nr: `nr${i}`, minutter: 60 }))
    const k = fakeKlient(mange)
    const ut = await hentArbeidstid(k, '2026-08')
    expect(ut?.rader).toHaveLength(1500)
    expect(ut?.betalteMinutter).toBe(90_000)
    expect(k.sider().length).toBeGreaterThan(1)
    expect(k.sider()[0]).toEqual([0, 999])
  })
})

describe('hentArbeidstid — tomt er ikke null timer', () => {
  it('gir null når måneden ikke har én eneste rad', async () => {
    // Et TOMT objekt ville sett ut som en stasjon der ingen jobbet.
    expect(await hentArbeidstid(fakeKlient([]), '2026-08')).toBeNull()
  })

  it('kaster på ugyldig måned', async () => {
    await expect(hentArbeidstid(fakeKlient([]), 'august'))
      .rejects.toThrow(/Ugyldig måned/)
  })
})
