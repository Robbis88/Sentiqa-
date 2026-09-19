import { describe, expect, it } from 'vitest'
import { beregnProduksjonsresultat } from './produksjonsberegning'

const plan = {
  advarsler: [],
  forslag: [{
    varenavn: 'Ost og skinke', varegruppeKode: '1220', varegruppeNavn: 'Påsmurt',
    fjorMedian: 10, nyligSnitt: 12, basis: 10, vaerfaktor: 1, trendfaktor: 1,
    samletfaktor: 1, foreslatt: 10, flagg: [],
    forklaring: {
      fjorDatoer: [], nyligeDatoer: [], historiskMedian: 10, nyligGjennomsnitt: 12,
      vaerfaktor: 1, trendfaktor: 1, trendProsent: 0, arrangementFaktor: 1,
      vaerBrukt: false, observasjoner: 10, raattForslag: 10, avrundetForslag: 10, sikkerhet: 'hoy' as const,
    },
  }],
} as const

describe('felles produksjonsberegning', () => {
  it('holder forventning, produksjon og startantall adskilt', () => {
    const r = beregnProduksjonsresultat(plan, { standardMargin: 20, standardStart: 50 })
    expect(r.summer).toMatchObject({ forventetSalg: 10, anbefaltProduksjon: 12, anbefaltStartantall: 6, publisertAntall: null })
    expect(r.produkter[0]).toMatchObject({ forventetSalg: 10, foreslattProduksjon: 10, anbefaltProduksjon: 12, planlagtAntall: 12 })
  })

  it('bevarer manuell plan separat fra modell og anbefaling', () => {
    const r = beregnProduksjonsresultat(plan, {
      standardMargin: 20, standardStart: 50,
      lagrede: new Map([['Ost og skinke', { varenavn: 'Ost og skinke', planlagt: 20, start_antall: 8 }]]),
    })
    expect(r.produkter[0]).toMatchObject({ foreslattProduksjon: 10, anbefaltProduksjon: 12, planlagtAntall: 20, anbefaltStartantall: 8, manuellPlan: true, publisertAntall: 20 })
    expect(r.summer.publisertAntall).toBe(20)
  })
})
