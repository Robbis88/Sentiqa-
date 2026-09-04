import { describe, it, expect } from 'vitest'
import { klarTilSending, FRIST_MIN } from './klar'

const SONDAG = '2026-08-30'
const kl = (t: number) => t * 60

const se = (over: Partial<Parameters<typeof klarTilSending>[0]> = {}) =>
  klarTilSending({ sisteDagMedSalg: SONDAG, sisteDagIUken: SONDAG, naaMinutter: kl(7), ...over })

describe('klarTilSending', () => {
  it('sender naar soendagen er inne', () => {
    expect(se()).toEqual({ send: true, ufullstendig: false })
  })

  // SELVE SAKEN. Uten dette gikk brevet kl. 07.00 med seks dager, og
  // duplikatsperren sørget for at den riktige versjonen aldri kom.
  it('venter naar soendagen mangler', () => {
    expect(se({ sisteDagMedSalg: '2026-08-29' }))
      .toEqual({ send: false, grunn: 'venter_paa_salgstall' })
  })

  it('venter ogsaa naar uken er helt tom', () => {
    expect(se({ sisteDagMedSalg: null }))
      .toEqual({ send: false, grunn: 'venter_paa_salgstall' })
  })

  // Men ikke evig. Et brev som aldri kommer er verre enn ett med
  // forbehold: forbeholdet kan hun lese, stillheten kan hun ikke.
  it('sender likevel naar fristen er naadd, og vet at det er ufullstendig', () => {
    expect(se({ sisteDagMedSalg: '2026-08-29', naaMinutter: FRIST_MIN }))
      .toEqual({ send: true, ufullstendig: true })
  })

  it('venter helt fram til fristen, ikke ett minutt kortere', () => {
    expect(se({ sisteDagMedSalg: '2026-08-29', naaMinutter: FRIST_MIN - 1 }).send).toBe(false)
  })

  // Et hull MIDT i uken er noe helt annet enn en fil som ikke har kommet:
  // det er en dag som aldri kom. Ventet vi paa den, gikk brevet aldri.
  it('venter ikke paa et hull midt i uken naar soendagen er inne', () => {
    expect(se({ sisteDagMedSalg: SONDAG, naaMinutter: kl(7) }))
      .toEqual({ send: true, ufullstendig: false })
  })

  it('fristen ligger paa en tid brevet fortsatt leses samme dag', () => {
    // En frist etter arbeidsdagen ville gjort ventingen meningsloes.
    expect(FRIST_MIN).toBeGreaterThan(10 * 60)
    expect(FRIST_MIN).toBeLessThanOrEqual(15 * 60)
  })
})
