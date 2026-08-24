import { describe, it, expect } from 'vitest'
import { byggSvar, borLeteVidere, DATASTATUS, STATUS_FORKLARING } from './svar'

const BASIS = { domene: 'test', kilder: ['tabell'] }
const PERIODE = { fra: '2026-07-01', til: '2026-07-31', opplosning: 'maaned' as const, komplett: true }

describe('byggSvar — statusen svaret får', () => {
  it('gir ok når data finnes og perioden er komplett', () => {
    const s = byggSvar({ ...BASIS, data: [{ a: 1 }], periode: PERIODE, scope: { forespurt: ['0142'], besvart: ['0142'] } })
    expect(s.status).toBe('ok')
    expect(s.komplett).toBe(true)
  })

  // T7 — den viktigste testen i fila.
  it('gir ingen_registrering, IKKE malt_null, når det ikke finnes rader', () => {
    const s = byggSvar({ ...BASIS, data: [], periode: PERIODE, scope: { forespurt: ['0142'] } })
    expect(s.status).toBe('ingen_registrering')
    expect(s.betyr).toContain('IKKE at verdien er null')
  })

  it('skiller malt_null fra ingen_registrering', () => {
    const målt = byggSvar({ ...BASIS, data: [{ kr: 0 }], maltNull: true, periode: PERIODE, scope: { forespurt: ['0142'], besvart: ['0142'] } })
    const tomt = byggSvar({ ...BASIS, data: [], periode: PERIODE, scope: { forespurt: ['0142'] } })
    expect(målt.status).toBe('malt_null')
    expect(tomt.status).toBe('ingen_registrering')
    expect(målt.status).not.toBe(tomt.status)
  })

  // T8
  it('gir mangler_kilde, ikke ingen_registrering, når kilden ikke finnes', () => {
    const s = byggSvar({ ...BASIS, data: [], manglerKilde: true, scope: { forespurt: ['0142'] } })
    expect(s.status).toBe('mangler_kilde')
    expect(s.betyr).toContain('ikke dataene som kreves')
  })

  it('gir feil for en vanlig databasefeil — et ukjent svar er ikke et tomt svar', () => {
    const s = byggSvar({ ...BASIS, data: [], feil: 'timeout', scope: { forespurt: ['0142'] } })
    expect(s.status).toBe('feil')
    expect(s.feil).toBe('timeout')
    expect(s.betyr).toContain('VET IKKE')
  })

  it('lar mangler_kilde slå feil — «viewet finnes ikke» er den presise diagnosen', () => {
    const s = byggSvar({
      ...BASIS,
      data: [],
      feil: 'relation does not exist',
      manglerKilde: true,
      scope: { forespurt: ['0142'] },
    })
    expect(s.status).toBe('mangler_kilde')
    // Feilteksten følger fortsatt med — diagnosen erstatter den ikke.
    expect(s.feil).toBe('relation does not exist')
  })

  it('lar feil og mangler_kilde slå alt som ligner et tomt svar', () => {
    for (const inn of [{ feil: 'x' }, { manglerKilde: true }]) {
      const s = byggSvar({ ...BASIS, data: [], scope: { forespurt: [], utenfor_tilgang: ['Lone'] }, ...inn })
      expect(s.status).not.toBe('ingen_registrering')
      expect(s.status).not.toBe('utenfor_scope')
    }
  })

  it('gir ingen_tilgang når rollen ikke får lese domenet', () => {
    const s = byggSvar({ ...BASIS, ingenTilgang: true })
    expect(s.status).toBe('ingen_tilgang')
  })

  // T2/T3 — den delen av tilgangskontrollen som handler om hva vi SIER.
  it('gir utenfor_scope når alt det ble spurt om ligger utenfor tilgangen', () => {
    const s = byggSvar({ ...BASIS, data: [], scope: { forespurt: [], utenfor_tilgang: ['Lone'] } })
    expect(s.status).toBe('utenfor_scope')
    expect(s.data).toHaveLength(0)
  })

  it('lekker ingen tall for stasjoner utenfor tilgangen', () => {
    const s = byggSvar({ ...BASIS, data: [], scope: { forespurt: [], utenfor_tilgang: ['Lone'] } })
    const tekst = JSON.stringify(s)
    expect(tekst).toContain('Lone')
    expect(s.merknad.join(' ')).toContain('ingen rangering')
    expect(s.merknad.join(' ')).toContain('ingen relativ plassering')
  })

  // T11
  it('merker ufullstendig periode selv når det finnes data', () => {
    const s = byggSvar({
      ...BASIS,
      data: [{ a: 1 }],
      periode: { ...PERIODE, komplett: false },
      scope: { forespurt: ['0142'], besvart: ['0142'] },
    })
    expect(s.status).toBe('ufullstendig_periode')
    expect(s.komplett).toBe(false)
    expect(s.merknad.join(' ')).toContain('ikke ferdig')
  })
})

describe('byggSvar — stasjoner uten rad forsvinner ikke', () => {
  // Dette er kaffesaken. Dale falt ut av svaret fordi han ikke hadde rad,
  // og modellen leste fraværet som et funn.
  it('lister stasjoner i scope som ikke ga noen rad', () => {
    const s = byggSvar({
      ...BASIS,
      data: [{ stasjon: '0143 Lone' }],
      periode: PERIODE,
      scope: {
        forespurt: ['0142', '0143'],
        besvart: ['0143'],
        uten_registrering: ['0142 Dale'],
      },
    })
    expect(s.scope.uten_registrering).toContain('0142 Dale')
    expect(s.merknad.join(' ')).toContain('ikke det samme som null')
    expect(s.komplett).toBe(false)
  })

  it('er ikke komplett når noen stasjoner mangler', () => {
    const s = byggSvar({
      ...BASIS,
      data: [{ a: 1 }],
      periode: PERIODE,
      scope: { forespurt: ['0142', '0143'], besvart: ['0143'], uten_registrering: ['0142 Dale'] },
    })
    expect(s.komplett).toBe(false)
  })

  it('er ikke komplett når noe ble avkortet', () => {
    const s = byggSvar({
      ...BASIS,
      data: [{ a: 1 }],
      avkortet: true,
      periode: PERIODE,
      scope: { forespurt: ['0142'], besvart: ['0142'] },
    })
    expect(s.komplett).toBe(false)
  })
})

// T9 — første tomme verktøy skal ikke stoppe undersøkelsen.
describe('borLeteVidere', () => {
  it('er sann for tomt, manglende kilde og feil', () => {
    for (const inn of [{ data: [] }, { manglerKilde: true }, { feil: 'x' }]) {
      expect(borLeteVidere(byggSvar({ ...BASIS, scope: { forespurt: ['0142'] }, ...inn }))).toBe(true)
    }
  })

  it('er usann når vi faktisk har et svar', () => {
    const ok = byggSvar({ ...BASIS, data: [{ a: 1 }], periode: PERIODE, scope: { forespurt: ['0142'], besvart: ['0142'] } })
    const null_ = byggSvar({ ...BASIS, data: [{ kr: 0 }], maltNull: true, periode: PERIODE, scope: { forespurt: ['0142'], besvart: ['0142'] } })
    expect(borLeteVidere(ok)).toBe(false)
    expect(borLeteVidere(null_)).toBe(false)
  })

  it('bærer alltid en `neste`-liste videre til modellen', () => {
    const s = byggSvar({ ...BASIS, data: [], scope: { forespurt: ['0142'] }, neste: ['hent_datadekning'] })
    expect(s.neste).toContain('hent_datadekning')
  })
})

// KANARIFUGL: en status uten forklaring er en status modellen må gjette
// semantikken til, og da er hele konvolutten uten verdi.
describe('kanarifugl', () => {
  it('har en forklaring for hver eneste status', () => {
    for (const s of DATASTATUS) {
      expect(STATUS_FORKLARING[s], `mangler forklaring for ${s}`).toBeTruthy()
      expect(STATUS_FORKLARING[s].length).toBeGreaterThan(20)
    }
  })

  it('har nøyaktig de åtte tilstandene produktkontrakten krever', () => {
    expect([...DATASTATUS].sort()).toEqual([
      'feil', 'ingen_registrering', 'ingen_tilgang', 'malt_null',
      'mangler_kilde', 'ok', 'ufullstendig_periode', 'utenfor_scope',
    ])
  })
})
