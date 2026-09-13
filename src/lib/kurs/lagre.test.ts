import { describe, expect, it, vi } from 'vitest'
import { byggRader, LAAST, lagreUtkast, lagringsnotat } from './lagre'
import type { Maanedsplan } from './plan'

// =====================================================================
// SKRIVEREN LIGGER I BASEN NÅ
// =====================================================================
//
// Her sto SELECT status → filtrer i TypeScript → UPSERT. Tre steg og to
// vinduer: avviste eieren planen ETTER lesingen men FØR skrivingen, ble
// avvisningen skrevet tilbake til utkast — og triggeren fanget det ikke,
// fordi den bare voktet `sluppet` og `sendt`.
//
// Låsen ligger nå i `skriv_maanedsplan_utkast` (0217), inne i
// `on conflict … do update … where`. Disse testene måler at
// TypeScript-siden TROR PÅ BASEN i stedet for på sin egen tidligere
// lesing — selve atomisiteten måles i `supabase/tests/`, med to økter.
// =====================================================================

function plan(navn: string, maaned = '2026-07-01'): Maanedsplan {
  return {
    stasjonNavn: navn, maaned, dom: 'motvind',
    ingress: 'x', punkter: [], merknad: null,
    matkast: { dom: null, blokkering: null },
    usynlig: {
      naaKr: null, kurs: null, blokkering: null,
      usikker: false, aarsakUsikker: null, vindu: 0,
    },
    rangering: { mulig: true, kandidater: [] },
  }
}

type Svarrad = {
  stasjon_id: string; maaned: string; skrevet: boolean
  status_ved_start: string | null; tilhorer_kjeden: boolean
}

/** Etterligner `skriv_maanedsplan_utkast`: én svarrad per innsendt rad. */
function klient(svar: (rader: Svarrad[]) => Svarrad[] = (r) => r, feil?: string) {
  const rpc = vi.fn(async (_navn: string, arg: { p_rader: { stasjon_id: string; maaned: string }[] }) => {
    if (feil) return { data: null, error: { message: feil } }
    const grunn: Svarrad[] = arg.p_rader.map((r) => ({
      stasjon_id: r.stasjon_id, maaned: r.maaned,
      skrevet: true, status_ved_start: 'utkast', tilhorer_kjeden: true,
    }))
    return { data: svar(grunn), error: null }
  })
  return { klient: { rpc } as never, rpc }
}

const TO = [
  { stasjonId: 's1', plan: plan('Dale') },
  { stasjonId: 's2', plan: plan('Lone') },
]

// =====================================================================
describe('lagreUtkast går gjennom den atomiske skriveren', () => {
  it('kaller funksjonen, ikke en upsert', async () => {
    const { klient: k, rpc } = klient()
    const res = await lagreUtkast(k, 'r1', 'j1', TO)
    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc.mock.calls[0][0]).toBe('skriv_maanedsplan_utkast')
    expect(res).toEqual({ skrevet: 2, laast: [], fremmede: [] })
  })

  it('sender kjede og jobb som egne argumenter, ikke i radene', async () => {
    const { klient: k, rpc } = klient()
    await lagreUtkast(k, 'r1', 'j1', TO)
    const arg = rpc.mock.calls[0][1] as Record<string, unknown>
    expect(arg.p_retailer_id).toBe('r1')
    expect(arg.p_kilde_jobb_id).toBe('j1')
    // `retailer_id` skal IKKE ligge i payloaden: basen tar kjeden fra
    // sesjonen naar det finnes en.
    for (const rad of arg.p_rader as Record<string, unknown>[]) {
      expect(rad).not.toHaveProperty('retailer_id')
      expect(rad).not.toHaveProperty('status')
    }
  })

  it('regenerering sender null jobb — da beholder basen pekeren', async () => {
    const { klient: k, rpc } = klient()
    await lagreUtkast(k, 'r1', null, TO)
    expect((rpc.mock.calls[0][1] as Record<string, unknown>).p_kilde_jobb_id).toBeNull()
  })

  it('gjør ingenting på tom liste', async () => {
    const { klient: k, rpc } = klient()
    expect(await lagreUtkast(k, 'r1', null, []))
      .toEqual({ skrevet: 0, laast: [], fremmede: [] })
    expect(rpc).not.toHaveBeenCalled()
  })
})

// =====================================================================
describe('basen er autoriteten, ikke vår egen lesing', () => {
  it('en rad basen IKKE skrev, navngis som låst', async () => {
    // Dette er racet: SELECT-en vår så `utkast`, men da setningen kjørte
    // var raden avvist. `skrevet: false` er svaret, og det skal vinne.
    const { klient: k } = klient((r) =>
      r.map((x) => x.stasjon_id === 's1'
        ? { ...x, skrevet: false, status_ved_start: 'utkast' } : x))
    const res = await lagreUtkast(k, 'r1', null, TO)
    expect(res.skrevet).toBe(1)
    expect(res.laast).toEqual(['Dale'])
  })

  it('status_ved_start er bare forklaring — den kan være foreldet', async () => {
    // Basen sier `utkast` OG `skrevet: false`. Det er ikke en
    // selvmotsigelse: statusen er lest i snapshotet ved setningens
    // start, og `on conflict` saa en nyere versjon etter radlaasen.
    const { klient: k } = klient((r) =>
      r.map((x) => ({ ...x, skrevet: false, status_ved_start: 'utkast' })))
    const res = await lagreUtkast(k, 'r1', null, TO)
    expect(res.skrevet).toBe(0)
    expect(res.laast).toEqual(['Dale', 'Lone'])
  })

  it('en fremmed stasjon skilles fra en låst', async () => {
    const { klient: k } = klient((r) =>
      r.map((x) => x.stasjon_id === 's2'
        ? { ...x, skrevet: false, tilhorer_kjeden: false } : x))
    const res = await lagreUtkast(k, 'r1', null, TO)
    expect(res.laast).toEqual([])
    expect(res.fremmede).toEqual(['Lone'])
  })

  it('KANARIFUGL: et fullt svar gir full skriving', async () => {
    // Uten denne ville testene over bestått i en klient som alltid
    // rapporterer at ingenting ble skrevet.
    const { klient: k } = klient()
    expect((await lagreUtkast(k, 'r1', null, TO)).skrevet).toBe(2)
  })
})

// =====================================================================
describe('et svar som ikke kan tolkes, tolkes ikke', () => {
  it('kaster når basen svarer for færre rader enn den fikk', async () => {
    // «0 skrevet, 0 låst» ville sett ut som en vellykket, tom kjøring.
    const { klient: k } = klient((r) => r.slice(0, 1))
    await expect(lagreUtkast(k, 'r1', null, TO)).rejects.toThrow(/1 av 2/)
  })

  it('kaster på feil fra basen — også den lukkede jobbvalideringen', async () => {
    const { klient: k } = klient(undefined, 'Ugyldig kildejobb abc')
    await expect(lagreUtkast(k, 'r1', 'abc', TO)).rejects.toThrow(/Ugyldig kildejobb/)
  })
})

// =====================================================================
describe('én låseliste', () => {
  it('sluppet, sendt OG avvist', () => {
    expect([...LAAST]).toEqual(['sluppet', 'sendt', 'avvist'])
  })
})

// =====================================================================
describe('radene bygges én gang', () => {
  it('begge kallerne sender nøyaktig samme form', () => {
    const rader = byggRader(TO)
    expect(rader).toHaveLength(2)
    // NØYAKTIG disse ni. Verken `retailer_id`, `status` eller
    // `kilde_jobb_id`: de bestemmes i basen, ikke av kalleren.
    expect(Object.keys(rader[0]).sort()).toEqual([
      'dom', 'ingress', 'maaned', 'matkast', 'merknad',
      'punkter', 'rangering', 'stasjon_id', 'usynlig',
    ])
  })

  it('snapshotet er med i hver rad', () => {
    const r = byggRader(TO)[0] as unknown as Record<string, Record<string, unknown>>
    expect(r.matkast.analyseversjon).toBe('p2-kastbudsjett-1')
    expect(r.usynlig.analyseversjon).toBe('p2-kastbudsjett-1')
  })
})

// =====================================================================
describe('lagringsnotat', () => {
  it('sier fra om planer som sto urørt', () => {
    const n = lagringsnotat({ skrevet: 3, laast: ['Dale', 'Lone'], fremmede: [] })!
    expect(n).toContain('Skrev 3')
    expect(n).toContain('Dale, Lone')
    expect(n).toContain('allerede avgjort')
  })

  it('skiller en fremmed stasjon fra en låst', () => {
    const n = lagringsnotat({ skrevet: 1, laast: [], fremmede: ['Ukjent'] })!
    expect(n).toContain('hører ikke til kjeden')
  })

  it('sier ingenting når det ikke er noe å si', () => {
    expect(lagringsnotat({ skrevet: 0, laast: [], fremmede: [] })).toBeNull()
  })
})
