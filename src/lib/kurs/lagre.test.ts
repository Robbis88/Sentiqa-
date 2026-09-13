import { describe, expect, it, vi } from 'vitest'
import {
  LAAST_VED_IMPORT, LAAST_VED_REGENERERING, lagreUtkast, lagringsnotat,
} from './lagre'
import type { Maanedsplan } from './plan'

function plan(navn: string, maaned = '2026-07-01'): Maanedsplan {
  return {
    stasjonNavn: navn, maaned, dom: 'motvind',
    ingress: 'x', punkter: [], merknad: null,
    matkast: { dom: null, blokkering: null },
    usynlig: { naaKr: null, kurs: null, blokkering: null, usikker: false, aarsakUsikker: null, vindu: 0 },
    rangering: { mulig: true, kandidater: [] },
  }
}

type Eksisterende = {
  stasjon_id: string; maaned: string; status: string; kilde_jobb_id?: string | null
}

/** Minste Supabase-etterligning som svarer paa det `lagreUtkast` spoer om. */
function klient(eksisterende: Eksisterende[], lesefeil: string | null = null) {
  const upsert = vi.fn().mockResolvedValue({ error: null })
  const kjede = {
    select: () => kjede,
    eq: () => kjede,
    in: () => kjede,
    limit: () => kjede,
    then: (r: (v: unknown) => unknown) => r({
      data: lesefeil ? null : eksisterende,
      error: lesefeil ? { message: lesefeil } : null,
    }),
  }
  return {
    klient: {
      from: (t: string) => (t === 'maanedsplan' ? { ...kjede, upsert } : kjede),
    } as never,
    upsert,
  }
}

describe('lagreUtkast', () => {
  it('skriver utkast for stasjoner uten sluppet plan', async () => {
    const { klient: k, upsert } = klient([])
    const res = await lagreUtkast(k, 'r1', 'j1', [
      { stasjonId: 's1', plan: plan('Dale') },
      { stasjonId: 's2', plan: plan('Lone') },
    ])
    expect(res.skrevet).toBe(2)
    expect(res.laast).toEqual([])
    expect(upsert).toHaveBeenCalledOnce()
    expect(upsert.mock.calls[0][0]).toHaveLength(2)
    expect(upsert.mock.calls[0][0][0].status).toBe('utkast')
    expect(upsert.mock.calls[0][1]).toEqual({ onConflict: 'stasjon_id,maaned' })
  })

  it('KANARI: roerer ALDRI en plan som er sluppet', async () => {
    // Et brev butikksjefen har lest skal ikke endre seg under henne.
    // Triggeren i 0200 holder ogsaa - men en import som stopper med
    // check_violation midt i en batch er en daarligere beskjed enn en
    // som hopper over det som er laast og sier hvor mange.
    const { klient: k, upsert } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'sluppet' },
    ])
    const res = await lagreUtkast(k, 'r1', 'j1', [
      { stasjonId: 's1', plan: plan('Dale') },
      { stasjonId: 's2', plan: plan('Lone') },
    ])
    expect(res.skrevet).toBe(1)
    expect(res.laast).toEqual(['Dale'])
    expect(upsert.mock.calls[0][0].map((r: { stasjon_id: string }) => r.stasjon_id))
      .toEqual(['s2'])
  })

  it('sendt teller som laast, ikke bare sluppet', async () => {
    const { klient: k } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'sendt' },
    ])
    const res = await lagreUtkast(k, 'r1', null, [{ stasjonId: 's1', plan: plan('Dale') }])
    expect(res.skrevet).toBe(0)
    expect(res.laast).toEqual(['Dale'])
  })

  it('et tidligere UTKAST skrives om — det er hele poenget med upsert', async () => {
    const { klient: k } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'utkast' },
    ])
    const res = await lagreUtkast(k, 'r1', null, [{ stasjonId: 's1', plan: plan('Dale') }])
    expect(res.skrevet).toBe(1)
    expect(res.laast).toEqual([])
  })

  it('laasen gjelder per MAANED, ikke per stasjon', async () => {
    // Juli er sluppet; august er en ny plan og skal skrives.
    const { klient: k } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'sluppet' },
    ])
    const res = await lagreUtkast(k, 'r1', null, [
      { stasjonId: 's1', plan: plan('Dale', '2026-08-01') },
    ])
    expect(res.skrevet).toBe(1)
  })

  it('gjoer ingenting paa tom liste', async () => {
    const { klient: k, upsert } = klient([])
    expect(await lagreUtkast(k, 'r1', null, [])).toEqual({ skrevet: 0, laast: [] })
    expect(upsert).not.toHaveBeenCalled()
  })
})

describe('lagringsnotat', () => {
  it('sier fra om planer som sto urørt', () => {
    // En stille utelatelse er verre enn en synlig merknad: uten dette
    // ville en eier som hadde sluppet planen lurt paa hvorfor den ikke
    // oppdaterte seg.
    const n = lagringsnotat({ skrevet: 3, laast: ['Dale', 'Lone'] })!
    expect(n).toContain('Skrev 3')
    expect(n).toContain('Dale, Lone')
    // «Avgjort», ikke «sluppet»: lista kan naa ogsaa inneholde en
    // AVVIST plan, og det er ikke det samme som en sluppet.
    expect(n).toContain('allerede avgjort')
  })

  it('sier ingenting naar det ikke er noe aa si', () => {
    expect(lagringsnotat({ skrevet: 0, laast: [] })).toBeNull()
  })

  it('boeyer entall riktig', () => {
    expect(lagringsnotat({ skrevet: 1, laast: [] })).toContain('1 månedsplan som')
    expect(lagringsnotat({ skrevet: 2, laast: [] })).toContain('2 månedsplaner som')
  })
})


// =====================================================================
// TO KALLERE, TO LAASER
// =====================================================================
//
// Importen er ny informasjon: et nytt utkast paa en AVVIST maaned er
// riktig svar. En manuell regenerering er noe annet - eieren har tatt
// stilling, og et knappetrykk skal ikke gjoere om paa den avgjoerelsen
// i stillhet.
//
// MERK: triggeren `maanedsplan_laas_sluppet` (0200) feller BARE
// `sluppet` og `sendt`. For `avvist` er denne lista den eneste laasen,
// og det er derfor den maales her og ikke bare i basen.
// =====================================================================
describe('laaselistene', () => {
  const avvist = [{ stasjon_id: 's1', maaned: '2026-07-01', status: 'avvist' }]
  const to = [
    { stasjonId: 's1', plan: plan('Dale') },
    { stasjonId: 's2', plan: plan('Lone') },
  ]

  it('importen SKRIVER OM en avvist plan', async () => {
    const { klient: k, upsert } = klient(avvist)
    const res = await lagreUtkast(k, 'r1', 'j1', to)
    expect(res.skrevet).toBe(2)
    expect(res.laast).toEqual([])
    expect(upsert.mock.calls[0][0].map((x: { stasjon_id: string }) => x.stasjon_id))
      .toContain('s1')
  })

  it('regenereringen LAR DEN STAA, og navngir stasjonen', async () => {
    const { klient: k, upsert } = klient(avvist)
    const res = await lagreUtkast(k, 'r1', null, to, { laaste: LAAST_VED_REGENERERING })
    expect(res.skrevet).toBe(1)
    expect(res.laast).toEqual(['Dale'])
    expect(upsert.mock.calls[0][0].map((x: { stasjon_id: string }) => x.stasjon_id))
      .not.toContain('s1')
  })

  it('begge laaser sluppet og sendt', async () => {
    for (const status of ['sluppet', 'sendt']) {
      for (const laaste of [LAAST_VED_IMPORT, LAAST_VED_REGENERERING]) {
        const { klient: k } = klient([{ stasjon_id: 's1', maaned: '2026-07-01', status }])
        const res = await lagreUtkast(k, 'r1', 'j1', to, { laaste })
        expect(res.laast, `${status} / ${laaste.join('+')}`).toEqual(['Dale'])
      }
    }
  })

  it('listene er de vi tror', () => {
    expect([...LAAST_VED_IMPORT]).toEqual(['sluppet', 'sendt'])
    expect([...LAAST_VED_REGENERERING]).toEqual(['sluppet', 'sendt', 'avvist'])
  })
})

// =====================================================================
describe('proveniensen', () => {
  const ett = [{ stasjonId: 's1', plan: plan('Dale') }]

  it('beholdKilde tar vare paa pekeren til fila tallene kom fra', async () => {
    const { klient: k, upsert } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'utkast', kilde_jobb_id: 'jobb-7' },
    ])
    await lagreUtkast(k, 'r1', null, ett, { beholdKilde: true })
    expect(upsert.mock.calls[0][0][0].kilde_jobb_id).toBe('jobb-7')
  })

  it('uten beholdKilde skriver importen sin egen jobb', async () => {
    const { klient: k, upsert } = klient([
      { stasjon_id: 's1', maaned: '2026-07-01', status: 'utkast', kilde_jobb_id: 'jobb-7' },
    ])
    await lagreUtkast(k, 'r1', 'jobb-8', ett)
    expect(upsert.mock.calls[0][0][0].kilde_jobb_id).toBe('jobb-8')
  })

  it('en ny rad faar null, ikke en oppdiktet jobb', async () => {
    const { klient: k, upsert } = klient([])
    await lagreUtkast(k, 'r1', null, ett, { beholdKilde: true })
    expect(upsert.mock.calls[0][0][0].kilde_jobb_id).toBeNull()
  })
})

// =====================================================================
describe('en lesefeil er ikke «ingen er sluppet»', () => {
  it('kaster i stedet for aa skrive over et sluppet brev', async () => {
    // `data ?? []` alene ville gjort en feilet spoerring til en tom
    // laaseliste, og da hadde vi skrevet over et brev butikksjefen har
    // lest. Feiler lesingen, skriver vi ingenting.
    const { klient: k, upsert } = klient([], 'statement timeout')
    await expect(lagreUtkast(k, 'r1', 'j1', [{ stasjonId: 's1', plan: plan('Dale') }]))
      .rejects.toThrow(/statement timeout/)
    expect(upsert).not.toHaveBeenCalled()
  })
})
