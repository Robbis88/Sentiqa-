import { describe, expect, it, vi, beforeEach } from 'vitest'
import type { InnloggetBruker } from '@/lib/auth/typer'

const mock = vi.hoisted(() => ({ modell: vi.fn(), verktoy: vi.fn() }))
vi.mock('@anthropic-ai/sdk', () => ({ default: class { messages = { create: mock.modell } } }))
vi.mock('@/lib/env', () => ({ env: { ANTHROPIC_API_KEY: 'test-noekkel' } }))
vi.mock('@/lib/supabase/server', () => ({ lagSupabaseServerKlient: async () => ({ from: () => ({ insert: async () => ({ error: null }) }) }) }))
vi.mock('./verktoy', () => ({
  VERKTOY: { forventet_salg: { kjor: mock.verktoy } },
  VERKTOY_ETIKETT: { forventet_salg: 'forventet salg' },
  verktoyForRolle: () => [],
}))

import { kjorAssistent } from './assistent'

const bruker = { id: 'bruker-dale', rolle: 'butikksjef', retailerId: 'retailer-1' } as InnloggetBruker
const prognose = {
  status: 'ok', scope: { besvart: ['4185'] },
  data: [{ ean: '5000112636833', dato: '2026-09-18', forventetAntall: 50 }],
}
const ferdig = (tekst: string) => ({ stop_reason: 'end_turn', content: [{ type: 'text', text: tekst }] })
const kall = (vare: string) => ({ stop_reason: 'tool_use', content: [{ type: 'tool_use', id: 'verktoy-1', name: 'forventet_salg', input: { vare, stasjoner: ['4185'] } }] })

beforeEach(() => { vi.resetAllMocks() })

describe('AI-2 samtalekontekst mot den faktiske assistentløkken', () => {
  it('bruker Opus med seks runder og rollebevisst kontekst', async () => {
    mock.modell.mockResolvedValueOnce(ferdig('Jeg trenger et verktøyoppslag for å svare sikkert.'))
    await kjorAssistent(bruker, [], 'Hva bør jeg prioritere?')
    const kall = mock.modell.mock.calls[0]![0]
    expect(kall.model).toBe('claude-opus-4-7')
    expect(kall.max_tokens).toBe(16000)
    expect(kall.system).toContain('KONTEKST SOM GJELDER I DENNE MELDINGEN')
    expect(kall.system).toContain('Tall, perioder og årsaker er ikke forhåndslastet')
  })

  it('uavklart Zero erstatter ikke den siste prognosen som faktisk ga et tall', async () => {
    mock.modell.mockResolvedValueOnce(kall('5000112636833')).mockResolvedValueOnce(ferdig('Dale: omtrent 50.'))
    mock.verktoy.mockResolvedValueOnce(prognose)
    const foerst = await kjorAssistent(bruker, [], 'Prognose for 5000112636833')
    expect(foerst.prognoseRef).toBeTruthy()

    mock.modell.mockResolvedValueOnce(kall('Zero')).mockResolvedValueOnce(ferdig('Hvilken Zero mener du?'))
    mock.verktoy.mockResolvedValueOnce({ status: 'ok', data: [{ ean: 'zero-1' }, { ean: 'zero-2' }] })
    const historikk = [{ rolle: 'assistent' as const, tekst: foerst.svar, prognoseRef: foerst.prognoseRef }]
    const uavklart = await kjorAssistent(bruker, historikk, 'Hva med Zero?')
    expect(uavklart.prognoseRef).toBe(foerst.prognoseRef)

    mock.verktoy.mockResolvedValueOnce(prognose)
    mock.modell.mockResolvedValueOnce(ferdig('Prognosen for vanlig Cola på Dale pleier å treffe godt.'))
    await kjorAssistent(bruker, [...historikk, { rolle: 'assistent', tekst: uavklart.svar, prognoseRef: uavklart.prognoseRef }], 'hvor sikker er du på tallet?')
    expect(mock.verktoy).toHaveBeenLastCalledWith({ vare: '5000112636833', stasjoner: ['4185'], fra: '2026-09-18', til: '2026-09-18' }, expect.objectContaining({ bruker }))
    const melding = mock.modell.mock.calls.at(-1)![0].messages.at(-1)
    expect(JSON.parse(melding.content[0].content)).toMatchObject(prognose)
    expect(JSON.parse(melding.content[0].content).samtalereferanse).toContain('siste leverte prognose')
  })

  it('henter på nytt med nåværende bruker, og godtar ikke en annen brukers referanse', async () => {
    mock.modell.mockResolvedValueOnce(kall('5000112636833')).mockResolvedValueOnce(ferdig('50.'))
    mock.verktoy.mockResolvedValueOnce(prognose)
    const foerst = await kjorAssistent(bruker, [], 'Prognose')
    mock.verktoy.mockClear()
    mock.modell.mockResolvedValueOnce(ferdig('Hvilket tall mener du?'))
    const annen = { ...bruker, id: 'annen-bruker' }
    await kjorAssistent(annen, [{ rolle: 'assistent', tekst: '50', prognoseRef: foerst.prognoseRef }], 'hvor sikker er du på tallet?')
    expect(mock.verktoy).not.toHaveBeenCalled()
  })
})
