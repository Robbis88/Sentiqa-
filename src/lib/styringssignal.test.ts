import { describe, it, expect } from 'vitest'
import { erStyringssignal, slippStyringssignal } from './styringssignal'

// Slik Next merker dem. Formen er `NEXT_REDIRECT;replace;/sti;307;`.
const redirect = (sti = '/logg-inn') =>
  Object.assign(new Error('NEXT_REDIRECT'), { digest: `NEXT_REDIRECT;replace;${sti};307;` })
const notFound = () => Object.assign(new Error('NEXT_NOT_FOUND'), { digest: 'NEXT_NOT_FOUND' })

describe('erStyringssignal', () => {
  it('kjenner igjen redirect', () => {
    expect(erStyringssignal(redirect())).toBe(true)
  })

  it('kjenner igjen notFound', () => {
    expect(erStyringssignal(notFound())).toBe(true)
  })

  it('kjenner igjen redirect uansett maal og statuskode', () => {
    expect(erStyringssignal(redirect('/ingen-tilgang'))).toBe(true)
    expect(erStyringssignal({ digest: 'NEXT_REDIRECT;push;/oversikt;303;' })).toBe(true)
  })
})

describe('erStyringssignal — og alt annet er en ekte feil', () => {
  it.each([
    ['vanlig feil', new Error('boom')],
    ['nettverksfeil', new TypeError('Failed to fetch')],
    ['null', null],
    ['undefined', undefined],
    ['streng', 'NEXT_REDIRECT'],
    ['tall', 42],
    ['objekt uten digest', { melding: 'nei' }],
    ['digest som ikke er streng', { digest: 12345 }],
    ['digest med feil verdi', { digest: 'NOE_ANNET' }],
  ])('%s er ikke et styringssignal', (_navn, e) => {
    expect(erStyringssignal(e)).toBe(false)
  })

  // KANARIFUGL: en for slapp sjekk - `digest.includes('NEXT')` eller
  // bare `'digest' in e` - ville gjort enhver feil med et digest-felt om
  // til en «redirect», og da blir ekte feil kastet videre i stillhet i
  // stedet for aa vises. Denne faller hvis noen loesner paa den.
  it('kanarifugl: slipper ikke gjennom paa delvis treff', () => {
    expect(erStyringssignal({ digest: 'MIN_NEXT_REDIRECT_KOPI' })).toBe(false)
    expect(erStyringssignal({ digest: 'NEXT_NOT_FOUND_ISH' })).toBe(false)
  })
})

describe('slippStyringssignal', () => {
  it('kaster videre paa redirect, saa navigeringen faktisk skjer', () => {
    const e = redirect()
    expect(() => slippStyringssignal(e)).toThrow(e)
  })

  it('gjoer ingenting for en ekte feil, saa kalleren kan vise den', () => {
    expect(() => slippStyringssignal(new Error('boom'))).not.toThrow()
  })
})
