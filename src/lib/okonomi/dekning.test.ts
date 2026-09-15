import { describe, expect, it } from 'vitest'
import {
  byggDekning, forventedeBilvaskUker, muligeSalgsdager, type Dekningsinput,
} from './dekning'

const NAA = new Date('2026-09-08T09:00:00Z')

const INN = (o: Partial<Dekningsinput> = {}): Dekningsinput => ({
  maaned: '2026-09',
  salgsdagerHar: 7,
  bilvaskUkerHar: 2,
  bilvaskUkerAv: 2,
  lonnsfil: false,
  regnskap: false,
  naa: NAA,
  ...o,
})

describe('nevneren er dagene som KUNNE vaert der', () => {
  it('en maaned som er over teller alle dagene', () => {
    expect(muligeSalgsdager('2026-08', NAA)).toBe(31)
    expect(muligeSalgsdager('2026-06', NAA)).toBe(30)
  })

  it('februar i et skuddaar er 29', () => {
    expect(muligeSalgsdager('2024-02', NAA)).toBe(29)
    expect(muligeSalgsdager('2026-02', NAA)).toBe(28)
  })

  it('den INNEVAERENDE maaneden teller til i gaar, ikke til i dag', () => {
    // DEN 8. SEPTEMBER HAR MAANEDEN 30 DAGER, men bare 7 kan ha tall -
    // dagens fil kommer i morgen. Telte vi 30, ville den inneveerende
    // maaneden staatt som 77 % mangelfull hver eneste dag, og det er
    // nettopp den maaneden loennsrommet er bygget for.
    expect(muligeSalgsdager('2026-09', NAA)).toBe(7)
  })

  it('KANARIFUGL: den teller ikke bare maanedslengden', () => {
    // Uten denne ville `dagerIMaaned` alene bestaatt de to foerste.
    expect(muligeSalgsdager('2026-09', NAA)).not.toBe(30)
  })

  it('den foerste i maaneden gir null mulige dager, ikke minus én', () => {
    expect(muligeSalgsdager('2026-09', new Date('2026-09-01T09:00:00Z'))).toBe(0)
  })

  it('en maaned fram i tid har ingenting aa mangle', () => {
    expect(muligeSalgsdager('2026-12', NAA)).toBe(0)
  })
})

describe('en bilvaskuke er ikke ventet foer den er over', () => {
  // August 2026 beroerer ISO-ukene 31-36, september 36-40.
  // NAA er 8. september, saa «i gaar» er 7. september.

  it('en avsluttet maaned har alle ukene sine', () => {
    // Uke 36 slutter soendag 6. september - foer i gaar. Alle seks
    // ukene august beroerer er dermed avsluttet.
    expect(forventedeBilvaskUker('2026-08', NAA)).toBe(6)
  })

  it('den INNEVAERENDE maaneden venter bare paa uker som er slutt', () => {
    // Uke 37 loeper 7.-13. september og er ikke over. Bare uke 36
    // teller - og det er den eneste september kan kreve rapport for.
    expect(forventedeBilvaskUker('2026-09', NAA)).toBe(1)
  })

  it('KANARIFUGL: den teller ikke bare ukene maaneden beroerer', () => {
    // Uten denne ville en funksjon som ignorerte «i gaar» bestaatt den
    // foerste testen, og september ville staatt med fire phantom-
    // mangler hver eneste dag fram til maanedsskiftet.
    expect(forventedeBilvaskUker('2026-09', NAA)).not.toBe(5)
  })

  it('en maaned fram i tid venter ingen uker', () => {
    expect(forventedeBilvaskUker('2026-12', NAA)).toBe(0)
  })
})

describe('mangler og retning', () => {
  it('full dekning gir ingen mangler og ukjent retning', () => {
    const d = byggDekning(INN())
    expect(d.mangler).toEqual([])
    expect(d.retningPaaFeil).toBe('ukjent')
  })

  it('manglende salgsdager navngis i entall og flertall', () => {
    expect(byggDekning(INN({ salgsdagerHar: 6 })).mangler).toEqual(['1 salgsdag'])
    expect(byggDekning(INN({ salgsdagerHar: 4 })).mangler).toEqual(['3 salgsdager'])
  })

  it('manglende bilvaskuker likesaa', () => {
    expect(byggDekning(INN({ bilvaskUkerHar: 1 })).mangler).toEqual(['1 bilvaskuke'])
  })

  it('begge manglene peker samme vei: anslaget blir for lavt', () => {
    const d = byggDekning(INN({ salgsdagerHar: 4, bilvaskUkerHar: 0 }))
    expect(d.mangler).toEqual(['3 salgsdager', '2 bilvaskuker'])
    expect(d.retningPaaFeil).toBe('for_lavt')
  })

  it('EN AVLAGT MAANED BAERER INGEN MANGLER', () => {
    // Regnskapet er fasit. At en salgsfil manglet i juli endrer ikke hva
    // juli ble - og uten denne regelen ville hver avlagt maaned baaret
    // en advarsel om et anslag som for lengst er erstattet.
    const d = byggDekning(INN({ maaned: '2026-07', salgsdagerHar: 0, bilvaskUkerHar: 0, regnskap: true }))
    expect(d.mangler).toEqual([])
    expect(d.retningPaaFeil).toBe('ukjent')
  })

  it('KANARIFUGL: samme maaned UTEN regnskap melder fra', () => {
    // Uten denne kunne regelen over vaert skrevet som «meld aldri fra»,
    // og dekningen ville vaert stum for hver maaned.
    const d = byggDekning(INN({ maaned: '2026-07', salgsdagerHar: 0, bilvaskUkerHar: 0, regnskap: false }))
    expect(d.mangler.length).toBeGreaterThan(0)
    expect(d.retningPaaFeil).toBe('for_lavt')
  })

  it('ukjent bilvaskforventning gir ingen bilvaskmangel', () => {
    // Vet vi ikke hvor mange uker maaneden burde hatt, kan vi heller
    // ikke si at noen mangler. En gjettet nevner ville gitt en gjettet
    // advarsel.
    const d = byggDekning(INN({ bilvaskUkerAv: null, bilvaskUkerHar: 0 }))
    expect(d.mangler).toEqual([])
  })

  it('flere registrerte enn forventet gir ikke negativ mangel', () => {
    const d = byggDekning(INN({ bilvaskUkerHar: 5, bilvaskUkerAv: 2 }))
    expect(d.mangler).toEqual([])
  })

  it('dekningstallene foelger med ut, ogsaa naar alt er i orden', () => {
    const d = byggDekning(INN())
    expect(d.salgsdager).toEqual({ har: 7, av: 7 })
    expect(d.lonnsfil).toBe(false)
  })
})
