import { describe, expect, it } from 'vitest'
import { beregnSvinnRapport } from './svinn-rapport'

describe('svinnrapport', () => {
  it('summerer registrert svinn, manko og overskudd uten dobbelttelling', () => {
    const r = beregnSvinnRapport([
      { stasjon_id: 's', kode: '120', navn: 'Mat', salg: 10000, kast: 100, usynlig_kr: 250 },
      { stasjon_id: 's', kode: '120', navn: 'Mat', salg: 5000, kast: 50, usynlig_kr: -80 },
    ])
    expect(r.registrert.kr).toBe(150)
    expect(r.manko.kr).toBe(250)
    expect(r.overskudd.kr).toBe(80)
    expect(r.avdelinger[0].samlet).toBe(320)
  })

  it('viser ikke prosent ved null eller svært lavt salg', () => {
    expect(beregnSvinnRapport([{ stasjon_id: 's', kode: '120', navn: 'Mat', salg: 0, kast: 10, usynlig_kr: 20 }]).manko.prosent).toBeNull()
    expect(beregnSvinnRapport([{ stasjon_id: 's', kode: '120', navn: 'Mat', salg: 999, kast: 10, usynlig_kr: 20 }]).manko.prosent).toBeNull()
  })

  it('merker sammenligning som ugyldig når perioden mangler grunnlag', () => {
    expect(beregnSvinnRapport([], false).manko.sammenligning).toBe('Ikke sammenlignbart')
  })
})
