import { describe, it, expect } from 'vitest'
import { produksjonsfaktor, lagProduksjonsplan, type SalgsPunkt } from './produksjonsplan'

describe('produksjonsfaktor', () => {
  it('utfart + solrik helg løfter kald drikke', () => {
    expect(produksjonsfaktor('utfart', { temp_maks: 22, nedbor_mm: 0 }, 6, 'Kald drikke')).toBeGreaterThan(1.2)
  })
  it('pendler i helg demper', () => {
    expect(produksjonsfaktor('pendler', null, 0, 'Baguett')).toBeLessThan(1)
  })
  it('nøytral hverdag på bydel uten vær = 1', () => {
    expect(produksjonsfaktor('bydel', null, 3, 'Baguett')).toBe(1)
  })
})

const G = { varegruppeKode: '1201', varegruppeNavn: 'Baguett' as string | null }

// Fjor-salg på de 5 match-datoene (mål − 364 dager ± 0/7/14).
function fjorSalg(maalDato: string, navn: string, verdier: number[]): SalgsPunkt[] {
  const base = new Date(`${maalDato}T12:00:00Z`); base.setUTCDate(base.getUTCDate() - 364)
  const baseIso = base.toISOString().slice(0, 10)
  return [-14, -7, 0, 7, 14].map((d, i) => {
    const dt = new Date(`${baseIso}T12:00:00Z`); dt.setUTCDate(dt.getUTCDate() + d)
    return { dato: dt.toISOString().slice(0, 10), varenavn: navn, ...G, antall: verdier[i] }
  })
}
// Nylig salg på to søndager i 28-dagers-vinduet.
function nyligSalg(navn: string, antall: number): SalgsPunkt[] {
  return ['2026-05-31', '2026-06-07'].map((dato) => ({ dato, varenavn: navn, ...G, antall }))
}

describe('lagProduksjonsplan', () => {
  const maalDato = '2026-06-14' // søndag
  const sisteSalgsdato = '2026-06-10'

  it('foreslår rundt fjor-median når trend/vær er nøytralt', () => {
    const salg = [...fjorSalg(maalDato, 'Baguette skinke', [10, 12, 11, 9, 13]), ...nyligSalg('Baguette skinke', 11)]
    const r = lagProduksjonsplan({ maalDato, sisteSalgsdato, salg, vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5 })
    const p = r.forslag.find((f) => f.varenavn === 'Baguette skinke')!
    expect(p.fjorMedian).toBe(11)
    expect(p.foreslatt).toBeGreaterThanOrEqual(8)
    expect(p.foreslatt).toBeLessThanOrEqual(15)
  })

  it('flagger fjor-kampanje og bruker nabo-median', () => {
    const salg = [...fjorSalg(maalDato, 'Pølse', [8, 9, 30, 10, 8]), ...nyligSalg('Pølse', 9)]
    const r = lagProduksjonsplan({ maalDato, sisteSalgsdato, salg, vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5 })
    const p = r.forslag.find((f) => f.varenavn === 'Pølse')!
    expect(p.flagg).toContain('fjor_kampanje')
    expect(p.foreslatt).toBeLessThan(15) // ikke blåst opp av kampanjedagen
  })

  it('markerer nytt produkt (kun nylig salg)', () => {
    const r = lagProduksjonsplan({ maalDato, sisteSalgsdato, salg: nyligSalg('Ny wrap', 6), vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5 })
    const p = r.forslag.find((f) => f.varenavn === 'Ny wrap')!
    expect(p.flagg).toContain('ny')
    expect(p.fjorMedian).toBeNull()
    expect(p.foreslatt).toBe(6)
  })

  it('ekskluderte produkter utelates', () => {
    const salg = [...fjorSalg(maalDato, 'Baguette ost', [5, 5, 5, 5, 5]), ...nyligSalg('Baguette ost', 5)]
    const r = lagProduksjonsplan({ maalDato, sisteSalgsdato, salg, vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5, ekskluderte: new Set(['Baguette ost']) })
    expect(r.forslag.find((f) => f.varenavn === 'Baguette ost')).toBeUndefined()
  })
})

describe('helligdager treffer fjorårets samme helligdag', () => {
  // FEILEN SIDA LOVET BORT. «Forslaget bygger på fjorårets samme
  // helligdag» sto på skjermen, mens koden brukte −364 og traff
  // nabodagen. Verst i påsken, som flytter seg med opptil fem uker.
  const p = (dato: string, antall: number): SalgsPunkt => ({
    dato, varenavn: 'Bolle', varegruppeKode: null, varegruppeNavn: null, antall,
  })

  it('bruker helligdagsdatoen som blir gitt, ikke −364', () => {
    // Skjærtorsdag 2026 er 2. april; i 2025 var den 17. april. −364
    // ville truffet 3. april 2025 — en helt vanlig torsdag.
    const plan = lagProduksjonsplan({
      maalDato: '2026-04-02',
      sisteSalgsdato: '2026-03-30',
      // Nylig salg maa vaere med: et produkt uten det regnes som
      // utgaatt og hoppes over.
      salg: [p('2025-04-17', 40), p('2025-04-03', 5), p('2026-03-26', 10)],
      vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5,
      helligdag: true,
      fjorHelligdag: '2025-04-17',
    })
    const bolle = plan.forslag.find((f) => f.varenavn === 'Bolle')
    expect(bolle, 'skal foreslå noe i det hele tatt').toBeDefined()
    // 40 fra selve helligdagen, ikke 5 fra den vanlige torsdagen.
    expect(bolle!.fjorMedian, '17. april, ikke 3.').toBe(40)
  })

  it('en vanlig dag bruker fortsatt −364', () => {
    // Helligdagsregelen skal ikke gripe inn ellers.
    const plan = lagProduksjonsplan({
      maalDato: '2026-08-22',
      sisteSalgsdato: '2026-08-21',
      salg: [p('2025-08-23', 30), p('2026-08-15', 10)],
      vaerMaal: null, vaerFjor: null, vaerfolsomhet: 0.5,
    })
    expect(plan.forslag.find((f) => f.varenavn === 'Bolle')?.fjorMedian).toBe(30)
  })
})