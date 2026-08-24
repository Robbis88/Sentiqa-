import { describe, it, expect } from 'vitest'
import {
  erSystemnummer, per100, nokGrunnlag, raten, byggKasserer, byggAlle,
  maanederI, totaltFor, MIN_BONGER,
  type Kassererrad,
} from './rate'

// =====================================================================
// Kontrakten: en rate, ikke en rangering.
//
// Den viktigste testen i denne fila er ikke et tall - det er at
// ingenting sorteres synkende på avvik. En slik liste er en
// mistenktliste uansett hva kolonnen heter.
// =====================================================================

const rad = (o: Partial<Kassererrad>): Kassererrad => ({
  stasjon_id: 'st-1',
  kasserer_nr: '101',
  maned: '2026-08-01',
  dager: 20,
  bonger: 1000,
  omsetning_kr: 300_000,
  retur_kr: 0,
  retur_antall: 0,
  makulert_kr: 0,
  makulert_antall: 0,
  slettet_kr: 0,
  slettet_antall: 0,
  ulike_navn: 1,
  navn: 'Kari',
  ...o,
})

// =====================================================================
// SYSTEMNUMMER ER IKKE EN MEDARBEIDER
// =====================================================================

describe('erSystemnummer', () => {
  it('kjenner igjen 999999 og bare-nuller', () => {
    expect(erSystemnummer('999999')).toBe(true)
    expect(erSystemnummer('9999')).toBe(true)
    expect(erSystemnummer('0')).toBe(true)
    expect(erSystemnummer('000000')).toBe(true)
  })

  // KANARIFUGL, OG EN EKTE RETTELSE. Foerste utgave sa `^9+$`. Sonden
  // fant `nr=9` paa Varden med 14 maaneder, 10 505 bonger og 178 288 kr
  // i avvik - nesten en tiendedel av stasjonens samlede avvik. Regelen
  // ville lagt alt det i «system» og fjernet det uten at noe sa fra.
  it('korte nitall er IKKE system - de kan vaere folk', () => {
    expect(erSystemnummer('9')).toBe(false)
    expect(erSystemnummer('99')).toBe(false)
    expect(erSystemnummer('999')).toBe(false)
  })

  it('lar vanlige numre vaere i fred', () => {
    expect(erSystemnummer('101')).toBe(false)
    expect(erSystemnummer('19')).toBe(false)
    expect(erSystemnummer('90')).toBe(false)
    expect(erSystemnummer('909')).toBe(false)
  })

  it('noe som ikke er et tall er ikke en person', () => {
    expect(erSystemnummer('SYSTEM')).toBe(true)
    expect(erSystemnummer('')).toBe(true)
    expect(erSystemnummer('   ')).toBe(true)
  })
})

// =====================================================================
// RATE UTEN POLITIKK
// =====================================================================

describe('per100', () => {
  it('regner avvik per hundre bonger', () => {
    expect(per100(50, 1000)).toBe(5)
  })

  it('null avvik mot ekte bonger ER 0 - det er et svar', () => {
    expect(per100(0, 1000)).toBe(0)
  })

  it('ingen bonger gir ingen rate, ikke uendelig', () => {
    expect(per100(50, 0)).toBeNull()
    expect(per100(50, -3)).toBeNull()
  })

  // BESLUTNINGEN LIGGER IKKE INNI DIVISJONEN. En `per100` som selv
  // hadde returnert null under hundre bonger ville skjult en politisk
  // grense inne i noe som ser ut som matematikk.
  it('sier ikke fra om at grunnlaget er lite - det er en annen funksjon', () => {
    expect(per100(1, 20)).toBe(5)
    expect(nokGrunnlag(20)).toBe(false)
    expect(nokGrunnlag(100)).toBe(true)
  })

  it('taaler soppel', () => {
    expect(per100(NaN, 100)).toBeNull()
    expect(per100(5, NaN)).toBeNull()
  })
})

// =====================================================================
// EGEN HISTORIKK, IKKE DE ANDRES
// =====================================================================

describe('byggKasserer', () => {
  const historikk = [
    rad({ maned: '2026-05-01', bonger: 1000, retur_kr: 100, retur_antall: 2 }),
    rad({ maned: '2026-06-01', bonger: 1000, retur_kr: 200, retur_antall: 4 }),
    rad({ maned: '2026-07-01', bonger: 1000, retur_kr: 300, retur_antall: 6 }),
    rad({ maned: '2026-08-01', bonger: 1000, retur_kr: 900, retur_antall: 18 }),
  ]

  it('maaler denne maaneden mot kassererens EGNE tidligere', () => {
    const k = byggKasserer('st-1', '101', historikk, '2026-08-01')
    // 10, 20, 30 -> snitt 20. Denne maaneden er 90.
    expect(k.egetSnitt).toBe(20)
    expect(k.denne!.krPer100).toBe(90)
    expect(k.motEgetSnitt).toBe(70)
    expect(k.egneMaaneder).toBe(3)
  })

  // KANARIFUGL. Tas den valgte maaneden med i sitt eget snitt,
  // sammenligner den delvis med seg selv - og et stort avvik trekker
  // maalestokken sin etter seg, saa utslaget blir mindre enn det er.
  it('den valgte maaneden ligger IKKE i sitt eget snitt', () => {
    const k = byggKasserer('st-1', '101', historikk, '2026-08-01')
    const medDenne = (10 + 20 + 30 + 90) / 4
    expect(k.egetSnitt).not.toBe(medDenne)
    expect(k.egetSnitt).toBe(20)
  })

  it('uten historikk finnes ingen sammenligning', () => {
    const k = byggKasserer('st-1', '101', [historikk[3]], '2026-08-01')
    expect(k.egetSnitt).toBeNull()
    expect(k.motEgetSnitt).toBeNull()
    expect(k.egneMaaneder).toBe(0)
    // Men raten for maaneden finnes fortsatt - fravaeret av historikk
    // er ikke fravaeret av et tall.
    expect(k.denne!.krPer100).toBe(90)
  })

  // En maaned med tolv bonger ville trukket snittet dit tilfeldigheten
  // peker, og gjort «egen historikk» til stoy.
  it('maaneder med for lite grunnlag teller ikke i snittet', () => {
    const k = byggKasserer('st-1', '101', [
      rad({ maned: '2026-06-01', bonger: 1000, retur_kr: 100 }),   // 10
      rad({ maned: '2026-07-01', bonger: 12, retur_kr: 100 }),     // 833, men 12 bonger
      rad({ maned: '2026-08-01', bonger: 1000, retur_kr: 300 }),
    ], '2026-08-01')
    expect(k.egetSnitt).toBe(10)
    expect(k.egneMaaneder).toBe(1)
  })

  it('en maaned uten data gir ingen rate for maaneden', () => {
    const k = byggKasserer('st-1', '101', historikk, '2026-09-01')
    expect(k.denne).toBeNull()
    expect(k.motEgetSnitt).toBeNull()
    // Historikken finnes likevel - alle fire maanedene ligger foer.
    expect(k.egneMaaneder).toBe(4)
  })

  it('flere navn paa samme nummer merkes', () => {
    const k = byggKasserer('st-1', '101', [rad({ ulike_navn: 2 })], '2026-08-01')
    expect(k.navnEtvetydig).toBe(true)
  })

  it('de tre avvikstypene holdes fra hverandre', () => {
    const k = byggKasserer('st-1', '101', [rad({
      retur_kr: 100, retur_antall: 2,
      makulert_kr: 200, makulert_antall: 3,
      slettet_kr: 300, slettet_antall: 4,
    })], '2026-08-01')
    expect(k.denne!.perType.retur.kr).toBe(100)
    expect(k.denne!.perType.makulert.antall).toBe(3)
    expect(k.denne!.perType.slettet.kr).toBe(300)
    expect(k.denne!.avvikKr).toBe(600)
    expect(k.denne!.avvikAntall).toBe(9)
  })
})

// =====================================================================
// INGEN RANGERING
// =====================================================================

describe('byggAlle', () => {
  const flere = [
    rad({ kasserer_nr: '301', retur_kr: 900 }),
    rad({ kasserer_nr: '101', retur_kr: 100 }),
    rad({ kasserer_nr: '999999', retur_kr: 5000, navn: null }),
    rad({ kasserer_nr: '201', retur_kr: 400 }),
  ]

  it('skiller systemnumre fra folk', () => {
    const { folk, system } = byggAlle(flere, '2026-08-01')
    expect(folk.map((k) => k.nr)).toEqual(['101', '201', '301'])
    expect(system.map((k) => k.nr)).toEqual(['999999'])
  })

  // DEN VIKTIGSTE PAASTANDEN I FILA. En liste sortert synkende paa
  // avvik er en mistenktliste, uansett hva kolonnen heter - den
  // oeverste raden leses som en anklage av alle som ser den.
  it('sorterer paa NUMMER, ikke paa avvik', () => {
    const { folk } = byggAlle(flere, '2026-08-01')
    expect(folk.map((k) => k.nr)).toEqual(['101', '201', '301'])

    const etterAvvik = [...folk].sort(
      (a, b) => (b.denne!.krPer100 ?? 0) - (a.denne!.krPer100 ?? 0))
    expect(folk.map((k) => k.nr)).not.toEqual(etterAvvik.map((k) => k.nr))
  })

  // KANARIFUGL. Kassanumrene starter paa nytt paa hver stasjon, saa
  // «101» finnes fem ganger i kjeden. Nokles det bare paa nummer,
  // smelter fem mennesker sammen til én rad naar eieren ser hele
  // kjeden - og den raden tilhoerer ingen av dem.
  it('samme nummer paa to stasjoner er to mennesker', () => {
    const { folk } = byggAlle([
      rad({ stasjon_id: 'a', kasserer_nr: '101', retur_kr: 100, navn: 'Kari' }),
      rad({ stasjon_id: 'b', kasserer_nr: '101', retur_kr: 900, navn: 'Ola' }),
    ], '2026-08-01')

    expect(folk).toHaveLength(2)
    expect(folk.map((k) => k.stasjon_id).sort()).toEqual(['a', 'b'])
    // Og kronene er IKKE slaatt sammen.
    expect(folk.map((k) => k.denne!.avvikKr).sort((x, y) => x - y)).toEqual([100, 900])
  })

  it('systemnummeret er med, bare ikke blant folkene', () => {
    const { system } = byggAlle(flere, '2026-08-01')
    expect(system[0].denne!.avvikKr).toBe(5000)
  })
})

// =====================================================================
// TOTALEN
// =====================================================================

describe('totaltFor', () => {
  const flere = [
    rad({ kasserer_nr: '101', bonger: 1000, omsetning_kr: 100_000, retur_kr: 100, retur_antall: 2 }),
    rad({ kasserer_nr: '201', bonger: 1000, omsetning_kr: 200_000, makulert_kr: 300, makulert_antall: 3 }),
    rad({ kasserer_nr: '999999', bonger: 5000, omsetning_kr: 900_000, slettet_kr: 7000, slettet_antall: 9 }),
    rad({ kasserer_nr: '101', maned: '2026-07-01', retur_kr: 99_999 }),
  ]

  it('summerer maaneden, uten systemnumre', () => {
    const t = totaltFor(flere, '2026-08-01')
    expect(t.bonger).toBe(2000)
    expect(t.omsetning).toBe(300_000)
    expect(t.avvikKr).toBe(400)
    expect(t.avvikAntall).toBe(5)
    expect(t.krPer100).toBe(20)
  })

  // KANARIFUGL. Kastes systemkronene ut i stillhet, ser totalen lavere
  // ut enn den er - og ingen ser at det mangler noe. Blandes de inn,
  // faar kassa skylda til en medarbeider.
  it('systemkronene forsvinner ikke, de staar for seg', () => {
    const t = totaltFor(flere, '2026-08-01')
    expect(t.systemKr).toBe(7000)
    expect(t.avvikKr).not.toBe(7400)
  })

  it('ser bort fra andre maaneder', () => {
    expect(totaltFor(flere, '2026-08-01').avvikKr).toBe(400)
  })

  it('en maaned uten data gir ingen rate', () => {
    const t = totaltFor(flere, '2026-01-01')
    expect(t.bonger).toBe(0)
    expect(t.krPer100).toBeNull()
  })
})

describe('maanederI', () => {
  it('gir distinkte maaneder, nyeste foerst', () => {
    expect(maanederI([
      rad({ maned: '2026-06-01' }), rad({ maned: '2026-08-01' }), rad({ maned: '2026-06-01' }),
    ])).toEqual(['2026-08-01', '2026-06-01'])
  })
})

describe('raten', () => {
  it('regner baade kroner og antall per 100', () => {
    const m = raten(rad({ bonger: 500, retur_kr: 50, retur_antall: 5 }))
    expect(m.krPer100).toBe(10)
    expect(m.antallPer100).toBe(1)
  })
})

// =====================================================================
// GRENSA SOM ER MAALT
// =====================================================================

describe('MIN_BONGER', () => {
  // Tallet er lest ut av `kasserer_fordeling.sql` del 3, ikke valgt:
  // under 100 bonger utelates 5-19 % av kasserermaanedene, under 500
  // utelates 20-61 % - flertallet paa tre av fem stasjoner. Endres det,
  // skal denne feile, saa den som skriver et nytt tall ogsaa leser
  // hvorfor det gamle sto der.
  it('staar paa 100, maalt mot fordelingen i produksjon', () => {
    expect(MIN_BONGER).toBe(100)
  })

  it('kan overstyres per kall, saa svaret kan tas i bruk ett sted', () => {
    const rader = [
      rad({ maned: '2026-07-01', bonger: 300, retur_kr: 30 }),
      rad({ maned: '2026-08-01', bonger: 1000, retur_kr: 500 }),
    ]
    expect(byggKasserer('st-1', '101', rader, '2026-08-01', 100).egneMaaneder).toBe(1)
    expect(byggKasserer('st-1', '101', rader, '2026-08-01', 500).egneMaaneder).toBe(0)
  })
})
