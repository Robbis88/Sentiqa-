import { describe, expect, it } from 'vitest'
import { hentDatadekning } from './datadekning'

function klient(datoer: unknown = [{ dato: '2026-09-16' }], hull: unknown = [], feilTabell = '') {
  return { from(tabell: string) {
    const svar = { data: tabell === 'v_datodekning' ? datoer : hull, error: tabell === feilTabell ? { message: 'timeout' } : null }
    const q: unknown = new Proxy({}, { get(_t, felt) {
      if (felt === 'then') return Promise.resolve(svar).then.bind(Promise.resolve(svar))
      return () => q
    } })
    return q
  } } as unknown as Parameters<typeof hentDatadekning>[0]
}
describe('datadekning krever en bekreftet komplett måling', () => {
  it('skiller bekreftet null hull fra manglende måling', async () => {
    const maaling = await hentDatadekning(klient(), '2026-08-01', ['timesalg'])
    expect(maaling.hull).toEqual([])
    expect(maaling.settPer.get('timesalg')?.has('2026-09-16')).toBe(true)
    await expect(hentDatadekning(klient(undefined, null), '2026-08-01', ['timesalg'])).rejects.toThrow('Mangler måling')
  })
  it.each(['v_datodekning', 'v_datohull'])('avviser feil i %s før en dom gis', async (tabell) => {
    await expect(hentDatadekning(klient([], [], tabell), '2026-08-01', ['timesalg'])).rejects.toThrow('timeout')
  })
  it.each(['datoer', 'hull'])('avviser avkorting av %s', async (tabell) => {
    const mange = Array.from({ length: 1000 }, () => ({ dato: '2026-09-16' }))
    await expect(hentDatadekning(klient(tabell === 'datoer' ? mange : [], tabell === 'hull' ? mange : []), '2026-08-01', ['timesalg'])).rejects.toThrow('taket')
  })
})
