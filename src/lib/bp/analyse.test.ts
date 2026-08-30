import { describe, it, expect } from 'vitest'
import { summer, royaltysats, analyser, type Aarstall } from './analyse'
import type { BpResultat } from '@/lib/parsere/typer'

// =====================================================================
// TALLENE ER KELSARS EGNE, fra BP 2025 og BP 2026.
//
// Oppdiktede tall ville bevist at koden gjor det den sier. Disse beviser
// at den sier noe RIKTIG - og de tre funnene under er alle verifisert mot
// filenes egne kontrolltall foer de ble skrevet inn her.
// =====================================================================

/** Bygger en aargang uten aa maatte lage tolv maaneder for haand. */
function aar(o: Partial<Aarstall> & { ar: number }): Aarstall {
  return {
    salg: 0, varekost: 0, brutto: 0, timelonn: 0, fastlonn: 0,
    andreKostnader: 0, royalty: 0, timer: 0,
    kategorier: new Map(), konti: new Map(),
    ...o,
  }
}

describe('royaltysatsen leses ut av tallene', () => {
  it('finner 10 % naar vask holdes utenfor', () => {
    // BP 2026, fem stasjoner. Ordinaert salg 59 346 575, royalty paa
    // ordinaert 5 934 658. Vaskeandelen er tatt ut av nevneren.
    const t = aar({
      ar: 2026,
      royalty: 5934658,
      kategorier: new Map([['120 Mat', 34316540], ['180 Tobakk', 25030035]]),
    })
    expect(royaltysats(t)).toBeCloseTo(0.10, 4)
  })

  it('KANARIFUGL: pant blaser ikke opp nevneren', () => {
    // Pant har ingen royalty. Ligger den i nevneren, ser satsen lavere
    // ut enn den er - og et aar med mer pant ser ut som en rabatt.
    const utenPant = aar({ ar: 2026, royalty: 1000, kategorier: new Map([['120 Mat', 10000]]) })
    const medPant = aar({
      ar: 2026, royalty: 1000,
      kategorier: new Map([['120 Mat', 10000], ['250 Pant', 5000]]),
    })
    // Samme ordinaere omsetning, samme royalty - saa samme sats.
    expect(royaltysats(utenPant)).toBeCloseTo(0.10, 4)
    expect(royaltysats(medPant)).toBeCloseTo(0.10, 4)
  })

  it('KANARIFUGL: satsen leses ikke naar vasken er med', () => {
    // Vasken har 60 %, ikke 10 %. En samlet sats over begge er et
    // blandingstall som ikke kan sammenlignes mellom to aar der
    // vaskeandelen har flyttet seg. Da er null det aerlige svaret.
    const medVask = aar({
      ar: 2026, royalty: 1000,
      kategorier: new Map([['120 Mat', 10000], ['210 Bilvask', 10000]]),
    })
    expect(royaltysats(medVask)).toBeNull()
  })

  it('gir null naar det ikke finnes omsetning', () => {
    expect(royaltysats(aar({ ar: 2026 }))).toBeNull()
  })
})

describe('analysen finner det en regnskapsfoerer ville sett', () => {
  // Kelsars tre stasjoner, forenklet til aarstall.
  const fjor = aar({
    ar: 2025,
    salg: 38831150, brutto: 18979640,
    timelonn: 6796990, fastlonn: 1800000, andreKostnader: 2257912,
    royalty: 2249077, timer: 28824,   // 7,75 % av ordinaert salg
    kategorier: new Map([
      ['180 Tobakk', 9799686], ['120 Mat', 8537572], ['140 Kald drikke', 4360032],
      ['160 Kioskvarer', 3134014], ['200 Bil', 2158345], ['190 Fritidsartikler', 1030698],
    ]),
    konti: new Map([['6420 Leie driftsmidler', 900000], ['6275 Renhold', 400000]]),
  })
  const iAar = aar({
    ar: 2026,
    salg: 40875850, brutto: 20100000,
    timelonn: 7489430, fastlonn: 1861479, andreKostnader: 2400000,
    royalty: 3064087, timer: 30270,   // 10,00 % av ordinaert salg
    kategorier: new Map([
      ['180 Tobakk', 9912503], ['120 Mat', 9276278], ['140 Kald drikke', 4969234],
      ['160 Kioskvarer', 3559427], ['200 Bil', 1995398], ['190 Fritidsartikler', 928026],
    ]),
    konti: new Map([['6420 Leie driftsmidler', 950000], ['6600 Rep & vedlikehold', 500000]]),
  })
  const funn = analyser(fjor, iAar)
  const finn = (id: string) => funn.find((f) => f.id === id)

  it('setter en pris paa royaltyendringen', () => {
    const f = finn('royaltysats')!
    expect(f.alvor).toBe('viktig')
    expect(f.dom).toBe('vond')
    // 7,75 % -> 10,00 % paa de tre stasjonenes ordinaere omsetning.
    expect(Math.round(f.kroner!)).toBeGreaterThan(600000)
    expect(f.tittel).toContain('hevet')
  })

  it('KANARIFUGL: hoyere timepris er GODT, ikke vondt', () => {
    // Timeprisen er en ramme St1 gir, ikke en kostnad de baerer.
    // Snur denne til «vond», er hele fargelogikken paa sida feil igjen.
    const f = finn('timeramme')!
    expect(f.dom).toBe('god')
    expect(f.betyr).toContain('ramme dere har fått')
  })

  it('deler loennsveksten i timer og timepris', () => {
    const f = finn('timeramme')!
    expect(f.maalt).toMatch(/\+5,0 % timer/)
    expect(f.maalt).toMatch(/timepris/)
  })

  it('ser marginklemmen naar kostnadene vokser raskest', () => {
    const f = finn('marginklem')!
    expect(f.tittel).toContain('raskere enn salgsmålet')
    // Ingen dom: en romsligere ramme er ikke et daarlig aar.
    expect(f.dom).toBeUndefined()
  })

  it('peker paa hvor veksten ligger', () => {
    const f = finn('vekstkonsentrasjon')!
    expect(f.maalt).toContain('120 Mat')
    expect(f.kroner).toBeGreaterThan(0)
  })

  it('KANARIFUGL: sier fra om varegrupper som er budsjettert NED', () => {
    // Det som kuttes er lettest aa overse, og det er der et positivt
    // avvik kan komme av at maalet var satt lavt - ikke av god drift.
    const f = finn('kuttede-grupper')!
    expect(f.maalt).toContain('200 Bil')
    expect(f.maalt).toContain('190 Fritidsartikler')
    expect(f.kroner).toBeLessThan(0)
  })

  it('KANARIFUGL: melder konti som er nye eller borte', () => {
    // En linje som forsvinner mellom to aar er lett aa overse.
    const f = finn('kontoplan')!
    expect(f.maalt).toContain('6600 Rep & vedlikehold')
    expect(f.maalt).toContain('6275 Renhold')
  })

  it('gir ingen royaltyfunn naar satsen staar stille', () => {
    const likt = analyser(fjor, aar({ ...fjor, ar: 2026 }))
    expect(likt.find((f) => f.id === 'royaltysats')).toBeUndefined()
  })
})

describe('summer', () => {
  const bp: BpResultat = {
    rapporttype: 'st1_bp',
    ar: 2026,
    stasjoner: [
      {
        butikknummer: '9038',
        timerAar: 13877.65,
        maaneder: [{
          maned: 1, salgKr: 100000, varekostKr: 40000, bruttoKr: 60000,
          timelonnKr: 20000, fastlonnKr: 5000,
          kategorier: [{ kode: '120', post: '120 Mat', salgKr: 60000, varekostKr: 25000 }],
          konti: [
            { kode: '6312', post: '6312 Royalty', belopKr: 8000 },
            { kode: '6315', post: '6315 FSA', belopKr: -700 },
            { kode: '6420', post: '6420 Leie driftsmidler', belopKr: 3000 },
          ],
        }],
      },
      {
        butikknummer: '4185', timerAar: 11187.47,
        maaneder: [{
          maned: 1, salgKr: 50000, varekostKr: 20000, bruttoKr: 30000,
          timelonnKr: 10000, fastlonnKr: 2500, kategorier: [], konti: [],
        }],
      },
    ],
  }

  it('summerer hele kjeden naar ingen stasjoner er valgt', () => {
    const t = summer(bp)
    expect(t.salg).toBe(150000)
    expect(t.timer).toBeCloseTo(25065.12, 2)
  })

  it('filtrerer til de stasjonene som er bedt om', () => {
    const t = summer(bp, ['9038'])
    expect(t.salg).toBe(100000)
    expect(t.timer).toBeCloseTo(13877.65, 2)
  })

  it('KANARIFUGL: royalty og FSA er ikke driftskostnader', () => {
    // Tas royaltyen med i kostnadsramma, ser rammen mye stoerre ut enn
    // den er - og FSA staar negativt, saa den ville trukket den ned.
    const t = summer(bp, ['9038'])
    expect(t.royalty).toBe(8000)
    expect(t.andreKostnader).toBe(3000)
    expect(t.konti.has('6315 FSA')).toBe(false)
    expect(t.konti.has('6312 Royalty')).toBe(false)
  })

  it('holder timeloenn og fastloenn utenfor andre kostnader', () => {
    const t = summer(bp, ['9038'])
    expect(t.timelonn).toBe(20000)
    expect(t.fastlonn).toBe(5000)
    expect(t.andreKostnader).toBe(3000)
  })
})
