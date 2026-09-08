import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { skjemaAktiv, rutineGjelder, rutinerForDato, osloNaa, type OsloNaa, type Rutinerad } from './rutineskjema'

const naa = (dato: string, ukedag: number, minutter: number): OsloNaa => ({ dato, ukedag, minutter })

describe('skjemaAktiv — samme dag', () => {
  const s = { tid_start: '06:00', tid_slutt: '14:00', ukedager: [] }
  it('midt i vinduet', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 8 * 60)).aktiv).toBe(true)
  })
  it('innenfor ±1t overlapp før', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 5 * 60 + 30)).aktiv).toBe(true) // 05:30
  })
  it('utenfor overlapp', () => {
    expect(skjemaAktiv(s, naa('2026-06-09', 2, 4 * 60 + 30)).aktiv).toBe(false) // 04:30
  })
  it('respekterer ukedager', () => {
    expect(skjemaAktiv({ ...s, ukedager: [1] }, naa('2026-06-09', 2, 8 * 60)).aktiv).toBe(false)
  })
})

describe('skjemaAktiv — krysser midnatt 22:00–06:00', () => {
  const n = { tid_start: '22:00', tid_slutt: '06:00', ukedager: [] }
  it('kveldsdel: vakten hører til i dag', () => {
    const v = skjemaAktiv(n, naa('2026-06-08', 1, 23 * 60)) // man 23:00
    expect(v.aktiv).toBe(true)
    expect(v.vaktdag).toBe(1)
    expect(v.vaktdato).toBe('2026-06-08')
  })
  it('morgendel: vakten hører til i går', () => {
    const v = skjemaAktiv(n, naa('2026-06-09', 2, 2 * 60)) // tir 02:00
    expect(v.aktiv).toBe(true)
    expect(v.vaktdag).toBe(1) // mandag
    expect(v.vaktdato).toBe('2026-06-08')
  })
  it('midt på dagen er inaktiv', () => {
    expect(skjemaAktiv(n, naa('2026-06-09', 2, 12 * 60)).aktiv).toBe(false)
  })
  it('ukedag-filter gjelder startdagen (man-natt → tirsdag morgen)', () => {
    const manNatt = { ...n, ukedager: [1] } // kun mandag
    expect(skjemaAktiv(manNatt, naa('2026-06-09', 2, 2 * 60)).aktiv).toBe(true) // tir 02:00 = mandagsvakten
    expect(skjemaAktiv(manNatt, naa('2026-06-10', 3, 2 * 60)).aktiv).toBe(false) // ons 02:00 = tirsdagsvakt → nei
  })
})

describe('rutineGjelder — to-nivå ukedag + opprettet-dato', () => {
  const vindu = { aktiv: true, vaktdag: 1, vaktdato: '2026-06-08' }
  it('arver (tom) → gjelder', () => {
    expect(rutineGjelder({ ukedager: [], opprettet_dato: '2026-01-01' }, vindu)).toBe(true)
  })
  it('egne dager uten vaktdagen → gjelder ikke', () => {
    expect(rutineGjelder({ ukedager: [5], opprettet_dato: '2026-01-01' }, vindu)).toBe(false)
  })
  it('opprettet etter vaktdatoen → hoppes over', () => {
    expect(rutineGjelder({ ukedager: [], opprettet_dato: '2026-06-09' }, vindu)).toBe(false)
  })
})

describe('osloNaa', () => {
  it('returnerer gyldig form', () => {
    const o = osloNaa(new Date('2026-06-09T10:00:00Z'))
    expect(o.dato).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    expect(o.ukedag).toBeGreaterThanOrEqual(0)
    expect(o.ukedag).toBeLessThanOrEqual(6)
    expect(o.minutter).toBeGreaterThanOrEqual(0)
  })
})

// =====================================================================
// RUTINENE SOM GJELDER EN DATO — den ene regelen.
//
// Den sto inne i `rutinestat.ts`, og ukebriefen fikk en egen kopi som
// var blind for ukedager: hver rutine ble krevd hver dag. En rutine som
// bare gaar mandag/onsdag/fredag fikk 0 % de fire andre dagene, og uken
// saa langt verre ut enn den var.
//
// Ingen test fanget det, fordi alle fiksturene hadde tomme `ukedager`.
// Derfor er nesten hver test her en med UTFYLTE ukedager.
// =====================================================================

describe('rutinerForDato', () => {
  // 2026-08-24 er en mandag (ukedag 1), 25. tirsdag, 26. onsdag.
  const MAN = '2026-08-24', TIR = '2026-08-25', ONS = '2026-08-26'
  const skjema = new Map<string, number[]>([['s1', []]])
  const rutine = (over: Partial<Rutinerad> = {}): Rutinerad =>
    ({ id: 'r1', skjema_id: 's1', ukedager: [], opprettet_dato: '2020-01-01', ...over })

  it('krever hver dag naar ingen ukedager er valgt', () => {
    for (const d of [MAN, TIR, ONS]) {
      expect(rutinerForDato([rutine()], skjema, d)).toEqual(['r1'])
    }
  })

  // SELVE FEILEN. Uten denne var briefen blind.
  it('krever bare de ukedagene rutinen faktisk har', () => {
    const r = rutine({ ukedager: [1, 3, 5] })  // man, ons, fre
    expect(rutinerForDato([r], skjema, MAN)).toEqual(['r1'])
    expect(rutinerForDato([r], skjema, TIR)).toEqual([])
    expect(rutinerForDato([r], skjema, ONS)).toEqual(['r1'])
  })

  it('lar skjemaets ukedager snevre inn, ogsaa naar rutinen er aapen', () => {
    const bareMandag = new Map<string, number[]>([['s1', [1]]])
    expect(rutinerForDato([rutine()], bareMandag, MAN)).toEqual(['r1'])
    expect(rutinerForDato([rutine()], bareMandag, TIR)).toEqual([])
  })

  it('krever begge nivaaer samtidig', () => {
    const manOns = new Map<string, number[]>([['s1', [1, 3]]])
    const bareOns = rutine({ ukedager: [3] })
    expect(rutinerForDato([bareOns], manOns, MAN)).toEqual([])
    expect(rutinerForDato([bareOns], manOns, ONS)).toEqual(['r1'])
  })

  it('krever ingenting foer rutinen ble laget', () => {
    const r = rutine({ opprettet_dato: TIR })
    expect(rutinerForDato([r], skjema, MAN)).toEqual([])
    expect(rutinerForDato([r], skjema, TIR)).toEqual(['r1'])
  })

  it('teller ikke en rutine uten skjema - det finnes ingen vakt aa gjoere den paa', () => {
    expect(rutinerForDato([rutine({ skjema_id: null })], skjema, MAN)).toEqual([])
    expect(rutinerForDato([rutine({ skjema_id: 'borte' })], skjema, MAN)).toEqual([])
  })
})

describe('regelen finnes bare ett sted', () => {
  // «Én sannhet, ikke to». Ukebriefen HADDE en egen kopi, og den var feil.
  // Skriver noen en ny, skal denne si fra.
  const les = (...p: string[]) => readFileSync(join(process.cwd(), 'src', 'lib', ...p), 'utf8')

  it('ukebriefen bruker rutinerForDato, ikke sin egen utregning', () => {
    const hent = les('ukebrief', 'hent.ts')
    expect(hent).toContain('rutinerForDato')
    expect(hent, 'et eget ukedagsfilter her ville vaert regelen paa nytt')
      .not.toMatch(/ukedager\.includes/)
  })

  it('rutinestatistikken bruker den samme', () => {
    expect(les('rutinestat.ts')).toContain('rutinerForDato')
  })
})


// =====================================================================
// KJERNE MOT NAADE
//
// Overlappen paa +/- 60 minutter finnes for at den som avslutter
// dagvakta skal rekke aa hake av. Men den gjoer ogsaa at to vakter er
// aktive samtidig rundt skiftet - paa Boenes var morgen (04-15) og
// kveld (15-24) begge aktive klokka 15:20, og flata summerte dem til
// ett tall: 36 + 19 rutiner i én haug.
//
// `kjerne` skiller den vakta man faktisk staar i fra den man holder paa
// aa forlate. Uten den kan ikke flata velge riktig vakt som forvalgt.
// =====================================================================
describe('skjemaAktiv — kjerne mot naade', () => {
  const morgen = { tid_start: '04:00', tid_slutt: '15:00', ukedager: [] as number[] }
  const kveld = { tid_start: '15:00', tid_slutt: '00:00', ukedager: [] as number[] }

  it('klokka 15:20 er kveld kjernen og morgen bare naade', () => {
    const n = naa('2026-06-09', 2, 15 * 60 + 20)
    const m = skjemaAktiv(morgen, n)
    const k = skjemaAktiv(kveld, n)
    // Begge er aktive - det er nettopp derfor tallet ble 55.
    expect(m.aktiv).toBe(true)
    expect(k.aktiv).toBe(true)
    // Men bare én av dem er vakta man staar i.
    expect(m.kjerne).toBe(false)
    expect(k.kjerne).toBe(true)
  })

  it('klokka 08:00 er morgen kjernen, og kveld er ikke aktiv i det hele tatt', () => {
    const n = naa('2026-06-09', 2, 8 * 60)
    expect(skjemaAktiv(morgen, n)).toMatchObject({ aktiv: true, kjerne: true })
    expect(skjemaAktiv(kveld, n).aktiv).toBe(false)
  })

  it('en time foer start er aktiv, men ikke kjerne', () => {
    const n = naa('2026-06-09', 2, 14 * 60 + 30) // 30 min foer kveld
    expect(skjemaAktiv(kveld, n)).toMatchObject({ aktiv: true, kjerne: false })
  })

  // MIDNATTSVAKTA HAR SAMME SKILLE. Morgendelen av en 22-06-vakt er
  // kjerne fram til 06:00 og naade i timen etter - ellers ville en
  // nattevakt som gaar av 06:30 sett vakta si som «den man staar i»
  // samtidig som morgenvakta.
  it('skiller kjerne fra naade ogsaa over midnatt', () => {
    const natt = { tid_start: '22:00', tid_slutt: '06:00', ukedager: [] as number[] }
    expect(skjemaAktiv(natt, naa('2026-06-09', 2, 5 * 60))).toMatchObject({ aktiv: true, kjerne: true })
    expect(skjemaAktiv(natt, naa('2026-06-09', 2, 6 * 60 + 30))).toMatchObject({ aktiv: true, kjerne: false })
    expect(skjemaAktiv(natt, naa('2026-06-09', 2, 23 * 60))).toMatchObject({ aktiv: true, kjerne: true })
    expect(skjemaAktiv(natt, naa('2026-06-09', 2, 21 * 60 + 30))).toMatchObject({ aktiv: true, kjerne: false })
  })

  // KANARIFUGL: en `kjerne` som alltid er lik `aktiv` maaler ingenting,
  // og da ville forvalget vaert tilfeldig igjen.
  it('kjerne er ikke bare en kopi av aktiv', () => {
    const n = naa('2026-06-09', 2, 15 * 60 + 20)
    const m = skjemaAktiv(morgen, n)
    expect(m.aktiv).not.toBe(m.kjerne)
  })
})
