import { describe, it, expect } from 'vitest'
import { opplaeringSynlig, forklaring, minutter, NAADETID_MIN, type Synlighet } from './synlig'

const ANNA = 'a1', PER = 'p1'
const kl = (t: string) => minutter(t)

const se = (over: Partial<Parameters<typeof opplaeringSynlig>[0]> = {}) =>
  opplaeringSynlig({
    periodeAnsattId: ANNA, aktivAnsattId: ANNA,
    startTid: '16:00', sluttTid: '23:00', naaMinutter: kl('18:00'), ...over,
  })

describe('hvem', () => {
  it('viser lista til den som har opplæring', () => {
    expect(se().synlig).toBe(true)
  })

  // SELVE SAKEN. Nettbrettet har én delt pålogging; uten dette ser hele
  // vaktlaget sjekklista til den nyansatte.
  it('skjuler lista for alle andre', () => {
    const s = se({ aktivAnsattId: PER })
    expect(s).toEqual({ synlig: false, grunn: 'annen_ansatt' })
  })

  it('skjuler lista når ingen har identifisert seg', () => {
    expect(se({ aktivAnsattId: null })).toEqual({ synlig: false, grunn: 'ikke_identifisert' })
  })

  // Perioder fra før `0171` har ingen `ansatt_id`. De skal virke som før
  // — å skjule dem ville vært en stille endring i noe som fungerte.
  it('lar gamle perioder uten ansatt stå uendret', () => {
    expect(se({ periodeAnsattId: null, aktivAnsattId: null, naaMinutter: kl('03:00') }))
      .toEqual({ synlig: true })
  })
})

describe('når', () => {
  it('viser lista i vakttiden', () => {
    for (const t of ['16:00', '19:30', '23:00']) {
      expect(se({ naaMinutter: kl(t) }).synlig, t).toBe(true)
    }
  })

  it('skjuler den før vakten begynner', () => {
    expect(se({ naaMinutter: kl('15:59') })).toEqual({ synlig: false, grunn: 'for_tidlig' })
  })

  // Nådetiden: man haker av ETTER at noe er lært bort, og den siste
  // oppgaven tok som regel lengst tid. Fjernes den, forsvinner lista
  // midt i den siste haken.
  it('lar lista stå nådetiden ut etter vakten', () => {
    expect(se({ naaMinutter: kl('23:00') + NAADETID_MIN }).synlig).toBe(true)
    expect(se({ naaMinutter: kl('23:00') + NAADETID_MIN + 1 }))
      .toEqual({ synlig: false, grunn: 'vakten_er_over' })
  })

  it('setter ingen grense når skiftet mangler klokkeslett', () => {
    // Butikksjefen har ikke lagt inn tider. Da skal vi ikke finne på noen.
    expect(se({ startTid: null, sluttTid: null, naaMinutter: kl('04:00') }).synlig).toBe(true)
  })

  // Rekkefølgen betyr noe: er feil person på vakt, er klokka uinteressant.
  // Uten dette kunne en «for_tidlig» skjult at det var feil person.
  it('svarer på hvem før den svarer på når', () => {
    expect(se({ aktivAnsattId: PER, naaMinutter: kl('03:00') }))
      .toEqual({ synlig: false, grunn: 'annen_ansatt' })
  })
})

describe('forklaringen', () => {
  // En tom skjerm uten forklaring ser ut som en ødelagt tablet.
  it('har en setning for hver grunn til å skjule', () => {
    const grunner: Synlighet[] = [
      { synlig: false, grunn: 'ikke_identifisert' },
      { synlig: false, grunn: 'annen_ansatt' },
      { synlig: false, grunn: 'for_tidlig' },
      { synlig: false, grunn: 'vakten_er_over' },
    ]
    for (const g of grunner) {
      const t = forklaring(g, 'Anna', '16:00–23:00')
      expect(t, JSON.stringify(g)).toBeTruthy()
      expect(t!.length).toBeGreaterThan(10)
    }
  })

  it('sier ingenting når lista faktisk vises', () => {
    expect(forklaring({ synlig: true }, 'Anna', '16:00–23:00')).toBeNull()
  })

  it('nevner tidsrommet når det finnes, og klarer seg uten', () => {
    expect(forklaring({ synlig: false, grunn: 'for_tidlig' }, 'Anna', '16:00–23:00')).toContain('16:00')
    expect(forklaring({ synlig: false, grunn: 'for_tidlig' }, 'Anna', null)).toContain('Anna')
  })
})

describe('minutter', () => {
  it('leser både HH:MM og HH:MM:SS', () => {
    expect(minutter('16:00')).toBe(960)
    expect(minutter('16:00:00')).toBe(960)
    expect(minutter('00:30')).toBe(30)
  })
})
