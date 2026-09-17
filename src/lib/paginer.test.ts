import { describe, expect, it } from 'vitest'
import { hentAlt } from './paginer'

describe('hentAlt gir hele datasettet eller feil', () => {
  it('henter også raden etter sidegrensen', async () => {
    const rader = Array.from({ length: 1001 }, (_, i) => i)
    expect(await hentAlt((f, t) => Promise.resolve({ data: rader.slice(f, t + 1), error: null }))).toEqual(rader)
  })
  it('returnerer aldri første side hvis neste side feiler', async () => {
    await expect(hentAlt((f) => Promise.resolve(f === 0
      ? { data: Array(1000).fill(1), error: null }
      : { data: null, error: { message: 'timeout' } }))).rejects.toThrow('timeout')
  })
  it('skiller tom tabell fra manglende svar', async () => {
    expect(await hentAlt(() => Promise.resolve({ data: [], error: null }))).toEqual([])
    await expect(hentAlt(() => Promise.resolve({ data: null, error: null }))).rejects.toThrow('mangler data')
  })
  it('avviser et datasett som treffer sikkerhetstaket', async () => {
    await expect(hentAlt(() => Promise.resolve({ data: Array(1000).fill(1), error: null }))).rejects.toThrow('200 000')
  })
})
