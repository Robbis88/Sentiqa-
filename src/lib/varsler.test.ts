import { describe, expect, it, vi, beforeEach } from 'vitest'

// `varsler.ts` er `server-only` og sender web-push. Begge maa staa
// utenfor testen: den ene kaster i node, den andre snakker med nettet.
vi.mock('server-only', () => ({}))
const push = vi.fn().mockResolvedValue(undefined)
vi.mock('@/lib/push', () => ({ sendPushForVarsel: (v: unknown) => push(v) }))

const { opprettVarsel, varselnoekkel } = await import('./varsler')

/** Minste Supabase-etterligning: `upsert(...).select()` og `insert(...)`. */
function klient(opprettede: { id: string }[]) {
  // Etterligner `upsert(rad, opts).select().limit()`. Argumentene leses
  // gjennom `upsert.mock.calls`, ikke i kroppen.
  // Typeparameteren gir `upsert.mock.calls[0][1]` en type uten at
  // kroppen maa ta imot argumenter den ikke bruker.
  const upsert = vi.fn<(rad: unknown, opts?: unknown) => {
    select: () => { limit: () => Promise<{ data: { id: string }[] }> }
  }>(() => ({ select: () => ({ limit: () => Promise.resolve({ data: opprettede }) }) }))
  const insert = vi.fn().mockResolvedValue({ error: null })
  return { k: { from: () => ({ upsert, insert }) } as never, upsert, insert }
}

beforeEach(() => push.mockClear())

describe('opprettVarsel', () => {
  it('uten noekkel: vanlig insert, og push', async () => {
    const { k, insert, upsert } = klient([])
    await opprettVarsel(k, { retailer_id: 'r', type: 't', tittel: 'Hei' })
    expect(insert).toHaveBeenCalledOnce()
    expect(upsert).not.toHaveBeenCalled()
    expect(push).toHaveBeenCalledOnce()
  })

  it('med noekkel: upsert som hopper over dubletter', async () => {
    const { k, upsert, insert } = klient([{ id: '1' }])
    await opprettVarsel(k, { retailer_id: 'r', type: 't', tittel: 'Hei', noekkel: 'a:b:c' })
    expect(insert).not.toHaveBeenCalled()
    expect(upsert).toHaveBeenCalledOnce()
    expect(upsert.mock.calls[0][1]).toEqual({
      onConflict: 'retailer_id,noekkel', ignoreDuplicates: true,
    })
    expect(push).toHaveBeenCalledOnce()
  })

  // ---- KANARIFUGLENE ------------------------------------------------
  it('KANARI: ingen ny rad gir INGEN ny push', async () => {
    // Den verste utgangen er at sperren stopper varselet i appen og
    // slipper pushen gjennom: da sier telefonen fra om noe som ikke
    // staar noe sted. Tom liste fra upsert betyr «noekkelen fantes».
    const { k } = klient([])
    await opprettVarsel(k, { retailer_id: 'r', type: 't', tittel: 'Hei', noekkel: 'a:b:c' })
    expect(push).not.toHaveBeenCalled()
  })

  it('KANARI: sju like opprettelser gir EN rad og EN push', async () => {
    // Dette er selve saken. Aatte re-importer x fem stasjoner ville gitt
    // femti-hundre varsler, og de ekte ville druknet i dem.
    const rader: { id: string }[] = []
    const upsert = vi.fn(() => {
      const nytt = rader.length === 0 ? [{ id: '1' }] : []
      if (nytt.length) rader.push(nytt[0])
      return { select: () => ({ limit: () => Promise.resolve({ data: nytt }) }) }
    })
    const k = { from: () => ({ upsert, insert: vi.fn() }) } as never
    for (let i = 0; i < 7; i++) {
      await opprettVarsel(k, { retailer_id: 'r', type: 't', tittel: 'Hei', noekkel: 'fast' })
    }
    expect(rader).toHaveLength(1)
    expect(push).toHaveBeenCalledOnce()
  })

  it('en feil velter aldri den utloesende handlingen', async () => {
    const k = { from: () => { throw new Error('basen er nede') } } as never
    await expect(opprettVarsel(k, { retailer_id: 'r', type: 't', tittel: 'Hei' }))
      .resolves.toBeUndefined()
  })
})

describe('varselnoekkel', () => {
  it('samler slag, stasjon og periode', () => {
    expect(varselnoekkel({ slag: 'bemanning', stasjonId: 's1', periode: '2026-07' }))
      .toBe('bemanning:s1:2026-07')
  })

  it('KANARI: ulik maaned gir ulik noekkel', () => {
    // Ellers ville en ny situasjon neste maaned blitt stille.
    const a = varselnoekkel({ slag: 'b', stasjonId: 's1', periode: '2026-07' })
    const b = varselnoekkel({ slag: 'b', stasjonId: 's1', periode: '2026-08' })
    expect(a).not.toBe(b)
  })

  it('KANARI: ulik stasjon gir ulik noekkel', () => {
    // Ellers ville bare den foerste stasjonen faatt varselet sitt.
    const a = varselnoekkel({ slag: 'b', stasjonId: 's1', periode: '2026-07' })
    const b = varselnoekkel({ slag: 'b', stasjonId: 's2', periode: '2026-07' })
    expect(a).not.toBe(b)
  })

  it('taaler varsler uten stasjon eller periode', () => {
    expect(varselnoekkel({ slag: 'kjede' })).toBe('kjede:kjede:na')
  })

  it('detaljen skiller to varsler om samme stasjon og maaned', () => {
    const a = varselnoekkel({ slag: 'b', stasjonId: 's1', periode: '2026-07', detalj: 'timer' })
    const b = varselnoekkel({ slag: 'b', stasjonId: 's1', periode: '2026-07', detalj: 'sats' })
    expect(a).not.toBe(b)
  })
})
