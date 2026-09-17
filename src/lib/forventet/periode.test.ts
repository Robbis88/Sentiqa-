import { describe, expect, it } from 'vitest'
import { forventetPeriode, maalPeriodetreff } from './periode'
import { leggTilDager } from '@/lib/produksjonsplan'
import { MODELLER, type Salgsrad } from './motor'
import { maalTreff, tillit } from './treffsikkerhet'
import { prognosePeriode } from '@/lib/ai/prognoseperiode'

const idag = '2026-09-17'
const salg: Salgsrad[] = Array.from({ length: 120 }, (_, i) => ({
  stasjonId: 'dale', ean: 'cola', dato: leggTilDager(idag, -i), antall: 10,
  varegruppeKode: '1402', varegruppeNavn: 'BRUS',
}))
const inn = { enhet: { stasjonId: 'dale', ean: 'cola' }, salg, modell: MODELLER[0], minstDagerMedSalg: 60 }
const uke = Array.from({ length: 7 }, (_, i) => leggTilDager(idag, i + 1))
describe('flerdagsprognose holder kunnskapstidspunkt og kvalitet på samme nivå', () => {
  it('en komplett uke summerer samme motors dagsprognoser', () => {
    const resultat = forventetPeriode({ ...inn, prognoseDato: idag, maaldatoer: uke })
    expect(resultat.antall).toBe(70)
    expect(resultat.dager).toHaveLength(7)
  })
  it('KANARI: data mellom spørredagen og måldagen må ikke påvirke senere dagsprognoser', () => {
    const foerst = forventetPeriode({ ...inn, prognoseDato: idag, maaldatoer: uke })
    const manipulert = forventetPeriode({ ...inn, prognoseDato: idag, maaldatoer: uke,
      salg: [...salg, ...uke.map((dato) => ({ ...salg[0], dato, antall: 99999 }))] })
    expect(manipulert).toEqual(foerst)
  })
  it('gir ingen periodesum når én av dagene mangler grunnlag', () => {
    // Bare første ukedag har en fjorårsmatch, og ingen nylig basis.
    const bareFredag = [{ ...salg[0], dato: leggTilDager(uke[0], -364) }]
    const resultat = forventetPeriode({ ...inn, salg: bareFredag, minstDagerMedSalg: 1, prognoseDato: idag, maaldatoer: uke })
    expect(resultat.dager.some((d) => d.forventning.slag === 'ikke_dekning')).toBe(true)
    expect(resultat.antall).toBeNull()
  })
  it('måler en uke mot komplette uker, ikke mot feil på enkeltdager', () => {
    const maaldatoer = ['2026-09-16', '2026-09-09', '2026-09-02', '2026-08-26']
    const resultat = maalPeriodetreff({ ...inn, maaldatoer, antallDager: 7, horisontDager: 1 })!
    expect(resultat).toMatchObject({ dager: 4, snittFaktisk: 70, mae: 0 })
    expect(tillit(resultat)).toBe('ukjent')
  })
  it('skiller dokumentert null salg fra manglende import', () => {
    const hull = '2026-09-10'
    const utenVare = salg.filter((r) => r.dato !== hull)
    expect(maalTreff({ ...inn, salg: utenVare, maaldatoer: [hull] })).toBeNull()
    expect(maalTreff({ ...inn, salg: utenVare, maaldatoer: [hull], salgsdager: new Set([hull]) })).toMatchObject({ dager: 1, snittFaktisk: 0, mae: 10 })
    expect(maalPeriodetreff({ ...inn, salg: utenVare, maaldatoer: ['2026-09-16'], antallDager: 7, horisontDager: 1 })).toBeNull()
  })
  it('h7-treff bruker bare kunnskapen sju dager før fasit', () => {
    const senere = salg.map((r) => ({ ...r, antall: r.dato > '2026-09-09' && r.dato < '2026-09-16' ? 1000 : r.antall }))
    const baseline = maalTreff({ ...inn, maaldatoer: ['2026-09-16'], horisontDager: 7 })
    expect(maalTreff({ ...inn, salg: senere, maaldatoer: ['2026-09-16'], horisontDager: 7 })).toEqual(baseline)
  })
})

describe('prognoseperioden er avgrenset server-side', () => {
  it('morgen er standard, neste uke er kommende mandag–søndag', () => {
    expect(prognosePeriode({}, idag)).toMatchObject({ fra: '2026-09-18', til: '2026-09-18' })
    expect(prognosePeriode({ periode: 'neste uke' }, idag)).toMatchObject({ fra: '2026-09-21', til: '2026-09-27', horisontDager: 4 })
    expect(prognosePeriode({ periode: 'neste uke' }, '2026-09-21')).toMatchObject({ fra: '2026-09-28', til: '2026-10-04', horisontDager: 7 })
  })
  it('avviser måned, fortid, h14, for lange spenn og motstridende input', () => {
    for (const input of [{ maaned: '2026-10' }, { periode: 'neste måned' }, { fra: idag },
      { fra: '2026-10-01' }, { fra: '2026-09-18', til: '2026-09-25' }, { fra: '2026-02-30' },
      { fra: 18 }, { dato: '2026-09-19', fra: '2026-09-18' },
      { periode: 'neste uke', fra: '2026-09-21' }]) expect(prognosePeriode(input, idag)).toHaveProperty('feil')
    expect(() => forventetPeriode({ ...inn, prognoseDato: idag, maaldatoer: [leggTilDager(idag, 14)] })).toThrow()
  })
})
