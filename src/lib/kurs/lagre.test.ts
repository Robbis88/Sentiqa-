import { describe, expect, it, vi } from 'vitest'
import { lagreUtkast, lagringsnotat } from './lagre'
import type { Maanedsplan } from './plan'

function plan(navn: string, maaned = '2026-07-01'): Maanedsplan {
  return {
    stasjonNavn: navn, maaned, dom: 'motvind',
    ingress: 'x', punkter: [], merknad: null,
  }
}

/** Minste Supabase-etterligning som svarer paa det `lagreUtkast` spoer om. */
function klient(eksisterende: { stasjon_id: string; maaned: string; status: string }[]) {
  const upsert = vi.fn().mockResolvedValue({ error: null })
  const kjede = {
    select: () => kjede,
    eq: () => kjede,
    in: () => kjede,
    limit: () => kjede,
    then: (r: (v: unknown) => unknown) => r({ data: eksisterende }),
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
    expect(n).toContain('allerede sluppet')
  })

  it('sier ingenting naar det ikke er noe aa si', () => {
    expect(lagringsnotat({ skrevet: 0, laast: [] })).toBeNull()
  })

  it('boeyer entall riktig', () => {
    expect(lagringsnotat({ skrevet: 1, laast: [] })).toContain('1 månedsplan som')
    expect(lagringsnotat({ skrevet: 2, laast: [] })).toContain('2 månedsplaner som')
  })
})
