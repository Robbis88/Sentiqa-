import { describe, expect, test } from 'vitest'
import { aktivtMenypunkt, SEKSJONER, sokepunkter } from '@/app/(beskyttet)/navigasjon'
import type { Brukerrolle } from '@/lib/auth/typer'

function seksjonerFor(rolle: Brukerrolle) {
  return SEKSJONER.map((s) => ({
    tittel: s.tittel,
    punkter: s.punkter.filter((p) => p.roller.includes(rolle)),
  })).filter((s) => s.punkter.length > 0)
}

describe('søk finner fanesider uten å utvide rollemodell', () => {
  test('butikksjef finner salg, kontrakter og anerkjennelse', () => {
    const treff = sokepunkter('butikksjef', seksjonerFor('butikksjef'))
    expect(treff.map((p) => p.sti)).toEqual(expect.arrayContaining([
      '/timesalg', '/salgsprognose', '/kontrakt', '/konkurranser', '/premier', '/min-plan',
    ]))
    expect(treff.find((p) => p.sti === '/timesalg')?.gruppe).toBe('Salg')
    expect(treff.filter((p) => p.sti === '/oversikt')).toHaveLength(1)
    expect(treff.find((p) => p.sti === '/oversikt')?.tekst).toBe('Butikken min')
    expect(treff.map((p) => p.sti)).not.toContain('/rommet')
    expect(treff.map((p) => p.sti)).not.toContain('/businessplan/sammenlign')
  })

  test('eier får ikke butikksjefens rutineoppsett, redaktør får ikke butikkfaner', () => {
    const eier = sokepunkter('retailer_admin', seksjonerFor('retailer_admin'))
    expect(eier.map((p) => p.sti)).not.toContain('/rutiner/oppsett')
    const redaktor = sokepunkter('plattform_redaktor', seksjonerFor('plattform_redaktor'))
    expect(redaktor.map((p) => p.sti)).toEqual(seksjonerFor('plattform_redaktor').flatMap((s) => s.punkter.map((p) => p.sti)))
  })
})

describe('hovedmeny kjenner forelderen til fanesiden', () => {
  test.each([
    ['/timesalg', '/salg'],
    ['/salgsprognose', '/salg'],
    ['/rutiner/oversikt', '/rutiner/min'],
    ['/rutiner/oppsett/eksempel', '/rutiner/min'],
    ['/min-plan', '/oversikt'],
    ['/min-maaned', '/oversikt'],
    ['/kontrakt', '/ansatte'],
    ['/premier', '/skills'],
    ['/produksjonsplan/treffsikkerhet', '/produksjonsplan'],
  ])('%s velger %s', (sti, forventet) => {
    expect(aktivtMenypunkt(sti, seksjonerFor('butikksjef'))).toBe(forventet)
  })

  test('lengste direkte menypunkt vinner og ukjent sti velger ingenting', () => {
    const meny = seksjonerFor('retailer_admin')
    expect(aktivtMenypunkt('/businessplan/sammenlign', meny)).toBe('/businessplan/sammenlign')
    expect(aktivtMenypunkt('/salgsprognose-ekstra', meny)).toBeNull()
    expect(aktivtMenypunkt('/helt-ukjent', meny)).toBeNull()
  })
})
