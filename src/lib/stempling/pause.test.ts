import { describe, it, expect } from 'vitest'
import { pausevindu, PAUSE_MINUTTER } from './pause'

const t = (hhmm: string) => new Date(`2026-08-28T${hhmm}:00+02:00`)

describe('pausevindu', () => {
  it('er tretti minutter fra trykket', () => {
    const v = pausevindu(t('07:00'), t('15:00'), t('11:00'))
    expect(v?.minutter).toBe(30)
    expect(v?.fra.toISOString()).toBe(t('11:00').toISOString())
    expect(v?.til.toISOString()).toBe(t('11:30').toISOString())
  })

  it('KLEMMES MOT SLUTTIDEN — aldri forbi det som faktisk ble jobbet', () => {
    // Trykker pause 14:50, stempler ut 15:00. Ti minutter, ikke tretti.
    // Uten klemmen ville vakta blitt tjue minutter kortere enn den var.
    const v = pausevindu(t('07:00'), t('15:00'), t('14:50'))
    expect(v?.minutter).toBe(10)
    expect(v?.til.toISOString()).toBe(t('15:00').toISOString())
  })

  it('gir null naar pausen trykkes i samme oeyeblikk som utstemplingen', () => {
    expect(pausevindu(t('07:00'), t('15:00'), t('15:00'))).toBeNull()
  })

  it('gir null utenfor vakta, i begge retninger', () => {
    expect(pausevindu(t('07:00'), t('15:00'), t('06:59'))).toBeNull()
    expect(pausevindu(t('07:00'), t('15:00'), t('15:01'))).toBeNull()
  })

  it('virker paa en vakt over midnatt', () => {
    const inn = new Date('2026-08-28T22:00:00+02:00')
    const ut = new Date('2026-08-29T06:00:00+02:00')
    const trykk = new Date('2026-08-29T01:00:00+02:00')
    const v = pausevindu(inn, ut, trykk)
    expect(v?.minutter).toBe(30)
    expect(v?.til.toISOString()).toBe(new Date('2026-08-29T01:30:00+02:00').toISOString())
  })

  it('KANARIFUGL: lengden er én fast konstant, ikke et valg', () => {
    // Endres denne, endres hver eneste registrerte pause i systemet.
    // Ingen flate skal kunne sende inn en annen lengde — funksjonen tar
    // ikke imot en.
    expect(PAUSE_MINUTTER).toBe(30)
    expect(pausevindu.length).toBe(3) // vaktStart, vaktSlutt, trykket
  })
})
