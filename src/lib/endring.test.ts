import { describe, expect, it } from 'vitest'
import { endring } from './endring'

// =====================================================================
// Den ekte raden fra 2026-09-09: «9145 St1 Varden  −0.0 %  ▼ rød».
//
// Verdien var en vekst så nær null at fortegnet var tilfeldig. Sida
// tegnet den som en nedgang — rød, pil ned, minus — fordi retningen ble
// avgjort av det uavrundede tallet mens teksten kom fra det avrundede.
// =====================================================================

describe('endring', () => {
  it('en verdi som avrundes til null er FLAT, ikke ned', () => {
    // Raden fra skjermbildet.
    const e = endring(-0.04)
    expect(e.retning).toBe('flat')
    expect(e.tall).toBe('0.0')
    expect(e.pil, 'en pil uten retning er en loegn').toBe('')
    expect(e.fortegn).toBe('')
    expect(e.farge, 'flat skal ikke vaere roed').toBe('')
  })

  it('gjelder begge veier — også en bitte liten oppgang', () => {
    const e = endring(0.02)
    expect(e.retning).toBe('flat')
    expect(e.farge, 'flat skal heller ikke vaere groenn').toBe('')
  })

  it('nøyaktig null er flat', () => {
    expect(endring(0).retning).toBe('flat')
  })

  it('en ekte oppgang er grønn og opp', () => {
    const e = endring(22.34)
    expect(e).toEqual({ retning: 'opp', pil: '▲', fortegn: '+', tall: '22.3', farge: 'gronn' })
  })

  it('en ekte nedgang er rød og ned', () => {
    const e = endring(-5.81)
    expect(e).toEqual({ retning: 'ned', pil: '▼', fortegn: '−', tall: '5.8', farge: 'rod' })
  })

  it('minustegnet er U+2212, ikke bindestrek', () => {
    // Typografisk minus. Bindestreken er kortere og leses som orddeling
    // i en tallkolonne.
    expect(endring(-5).fortegn).toBe('−')
  })

  it('grensa ligger der avrundingen ligger', () => {
    // 0,05 avrundes til 0,1 - altsaa synlig, altsaa en retning.
    expect(endring(0.05).retning).toBe('opp')
    expect(endring(0.049).retning).toBe('flat')
  })

  it('følger antall desimaler flaten faktisk viser', () => {
    // Viser flaten null desimaler, er 0,4 % ogsaa flatt DER. Uenighet
    // mellom retning og tekst oppstaar ellers et hakk lenger ned.
    expect(endring(0.4, 0).retning).toBe('flat')
    expect(endring(0.4, 0).tall).toBe('0')
    expect(endring(0.4, 1).retning).toBe('opp')
  })

  it('KANARIFUGL: den gamle regelen ville felt Varden', () => {
    // Slik sto det: retningen fra den raa verdien, teksten fra den
    // avrundede. Slutter denne aa vaere ulik `endring()`, maaler testen
    // over ingenting.
    const raa = -0.04
    const gammelRetning = raa >= 0 ? 'opp' : 'ned'
    expect(gammelRetning).toBe('ned')
    expect(endring(raa).retning).not.toBe(gammelRetning)
  })
})
