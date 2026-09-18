import { describe, expect, it } from 'vitest'
import { finnGruppe } from './forventetverktoy'

const rader = [
  { ean: 'a', varenavn: 'Ost skinke', avdeling_kode: '120', avdeling_navn: 'Mat', vareomrade_kode: '15', vareomrade_navn: 'PÅSMURT', varegruppe_kode: '1501', varegruppe_navn: 'PÅSMURT', antall: 2, dato: '2026-09-17', stasjon_id: 'b' },
  { ean: 'b', varenavn: 'Egg bacon', avdeling_kode: '120', avdeling_navn: 'Mat', vareomrade_kode: '15', vareomrade_navn: 'PÅSMURT', varegruppe_kode: '1501', varegruppe_navn: 'PÅSMURT', antall: 3, dato: '2026-09-17', stasjon_id: 'b' },
  { ean: 'c', varenavn: 'Kanelbolle', avdeling_kode: '120', avdeling_navn: 'Mat', vareomrade_kode: '10', vareomrade_navn: 'BAKERI', varegruppe_kode: '1001', varegruppe_navn: 'BAKERI', antall: 1, dato: '2026-09-17', stasjon_id: 'b' },
]

describe('forventet salg — begrepsoppløsning', () => {
  it('finner Mat som avdeling og alle produktene', () => {
    expect(finnGruppe(rader, 'mat')).toMatchObject({ nivaa: 'avdeling', kode: '120', ean: ['a', 'b', 'c'] })
  })
  it('finner Påsmurt som det mest spesifikke registrerte nivået', () => {
    expect(finnGruppe(rader, 'påsmurt')).toMatchObject({ nivaa: 'varegruppe', ean: ['a', 'b'] })
  })
  it('finner Bakeri som registrert varegruppe', () => {
    expect(finnGruppe(rader, 'bakeri')).toMatchObject({ nivaa: 'varegruppe', ean: ['c'] })
  })
  it('returnerer null for ukjent område og flere ved reell tvetydighet', () => {
    expect(finnGruppe(rader, 'suppe')).toBeNull()
    expect(finnGruppe([...rader, { ...rader[0], varegruppe_kode: '1502', varegruppe_navn: 'PÅSMURT' }], 'påsmurt')).toBe('flere')
  })
})
