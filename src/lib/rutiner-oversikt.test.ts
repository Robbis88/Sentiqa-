import { describe, expect, it } from 'vitest'
import { byggOversikt, fristFor, klassifiser, type Forventning } from './rutiner-oversikt'

const base: Forventning = { id: 'f1', retailer_id: 'r', stasjon_id: 's', rutine_id: 'x', skjema_id: 'q', dato: '2026-09-18', vakttype: 'kveld', skjema_navn: null, rutine_tittel: 'Steng kasse', forventet_start: '22:00', forventet_slutt: '06:00', paakrevd_bilde: false }
const ansatte = new Map([['a1', 'Ada']])

describe('rutineoversikt', () => {
  it('beregner frist for vakt over midnatt med toleranse', () => {
    expect(fristFor(base).toISOString()).toBe('2026-09-19T05:00:00.000Z')
  })
  it('bruker samme grunnlag for total og topputførere', () => {
    const o = byggOversikt([base, { ...base, id: 'f2', rutine_id: 'y', rutine_tittel: 'Lås dør' }], [
      { rutine_id: 'x', stasjon_id: 's', dato: base.dato, utfort_tid: '2026-09-19T04:00:00+02:00', ansatt_id: 'a1' },
    ], new Map(), ansatte, new Date('2026-09-19T07:00:00Z'))
    expect(o.forventet).toBe(2); expect(o.utfort).toBe(1); expect(o.prosent).toBe(50); expect(o.topputforere).toEqual([{ id: 'a1', navn: 'Ada', antall: 1 }])
  })
  it('viser gjennomført oppgave og ukjent medarbeider separat', () => {
    const r = klassifiser(base, { rutine_id: 'x', stasjon_id: 's', dato: base.dato, utfort_tid: '2026-09-19T04:00:00Z', ansatt_id: null }, new Date('2026-09-19T07:00:00Z'), ansatte)
    expect(r.status).toBe('Gjennomført'); expect(r.ansatt_navn).toBe('Ikke identifisert')
  })
  it('skiller manglende og for sen utførelse', () => {
    const sen = klassifiser(base, { rutine_id: 'x', stasjon_id: 's', dato: base.dato, utfort_tid: '2026-09-19T06:01:00Z', ansatt_id: 'a1' }, new Date('2026-09-20T07:00:00Z'), ansatte)
    const mangler = klassifiser(base, null, new Date('2026-09-20T07:00:00Z'), ansatte)
    expect(sen.status).toBe('For sent'); expect(mangler.status).toBe('Mangler')
  })
})
