import { describe, expect, it } from 'vitest'
import { varegrunn } from './egnethet'
import { forventetSalg, MODELLER, type Salgsrad } from './motor'
import type { Varekandidat } from './varesok'

const vare = (o: Partial<Varekandidat> = {}): Varekandidat => ({ ean: '4001', navn: 'SORT KAFFE STOR',
  navnHistorikk: [], varegruppeKode: '1', varegruppeNavn: 'KAFFE', avdelingNavn: 'MAT', volum: 20, stasjoner: ['dale'], ...o })
const salg: Salgsrad[] = Array.from({ length: 80 }, (_, i) => ({
  stasjonId: 'dale', ean: '4001', dato: new Date(Date.UTC(2026, 8, 16 - i)).toISOString().slice(0, 10),
  antall: 10, varegruppeKode: '1', varegruppeNavn: 'KAFFE',
}))
const inn = { enhet: { stasjonId: 'dale', ean: '4001' }, maalDato: '2026-09-17', modell: MODELLER[0], minstDagerMedSalg: 60 }
describe('prognosen gjetter ikke varetype eller måleenhet fra koden', () => {
  it('interne kaffekoder er varer; pant er en kassepost uansett kode', () => {
    expect(varegrunn(vare())).toBeNull()
    expect(varegrunn(vare({ ean: '5000112636833', avdelingNavn: ' PANT ' }))).toBe('ikke_vare')
    expect(varegrunn(vare({ varegruppeNavn: 'RABATT' }))).toBe('ikke_vare')
  })
  it('skiller per-kilo fra en pakke merket kilo', () => {
    expect(varegrunn(vare({ navn: 'GODTERI PR KG' }))).toBe('ukjent_enhet')
    expect(varegrunn(vare({ navn: 'KAFFE 1 KG' }))).toBeNull()
  })
  it('desimaler må ikke rundes opp til stykker', () => {
    expect(forventetSalg({ ...inn, salg: salg.map((r) => ({ ...r, antall: 1.25 })) })).toMatchObject({ slag: 'ikke_dekning', grunn: 'ukjent_enhet' })
    expect(forventetSalg({ ...inn, salg })).toMatchObject({ slag: 'beregnet', antall: 10 })
  })
  it('ukjent antall stopper prognosen; måldagens ugyldige antall lekker ikke tilbake', () => {
    expect(forventetSalg({ ...inn, salg: [...salg, { ...salg[0], antall: NaN }] })).toMatchObject({ slag: 'ikke_dekning', grunn: 'ugyldig_antall' })
    expect(forventetSalg({ ...inn, salg: [...salg, { ...salg[0], dato: inn.maalDato, antall: NaN }] })).toMatchObject({ slag: 'beregnet' })
  })
})
