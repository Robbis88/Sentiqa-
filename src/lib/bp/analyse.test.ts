import { describe, it, expect } from 'vitest'
import {
  summer, analyser, royaltyandel, royaltyEndring, ordinaertSalg, type Aarstall,
} from './analyse'
import type { BpResultat } from '@/lib/parsere/typer'

// =====================================================================
// TALLENE ER KELSARS EGNE, lest ut av BP25 og BP26 med `parseBp25` og
// `parseBp`, og krysset mot filenes egne kontrolltall:
//
//   BP25 «Budget»-arket   CR salg 38 835 338, Royalty 5 746 464
//   BP25 Laguneparken     120 Mat 4 651 908
//
// Oppdiktede tall ville bevist at koden gjoer det den sier. Disse beviser
// at den sier noe RIKTIG.
// =====================================================================

function aar(o: Partial<Aarstall> & { ar: number }): Aarstall {
  return {
    salg: 0, varekost: 0, brutto: 0,
    personal: 0, timelonn: 0, fastlonn: 0,
    andreKostnader: 0, royalty: 0, timer: 0,
    kategorier: new Map(), konti: new Map(),
    ...o,
  }
}
const vg = (post: string, salg: number, varekost = 0) => ({ post, salg, varekost })
const ko = (post: string, kr: number) => ({ post, kr })

// De tre stasjonene Robert har hatt sammenhengende: Laguneparken 9038,
// Varden 9145, Boenes 9467.
const BP25 = aar({
  ar: 2025,
  salg: 38835338, varekost: 19855697, brutto: 18979640,
  personal: 11568903, andreKostnader: 1960629, royalty: 5746464,
  kategorier: new Map([
    ['180', vg('180 Tobakk', 9799686)],
    ['120', vg('120 Mat', 8537572)],
    ['210', vg('210 Bilvask', 7302260, 1826486)],
    ['140', vg('140 Kald drikke', 4360032)],
    // NB: navnet er et annet i 2026. Se kanarifuglen under.
    ['160', vg('160 Kioskvarer ex smågodt', 3134014)],
    ['200', vg('200 Bil', 2158345)],
    ['170', vg('170 Butikk', 1166210)],
    ['190', vg('190 Fritidsartikler', 1030698)],
    ['130', vg('130 Varm drikke', 1017027)],
    ['250', vg('250 Pant', 252360, 252360)],
    ['220', vg('220 Utleie', 4188)],
  ]),
  konti: new Map([
    ['5010', ko('5010 Site Salary costs', 11271621)],
    ['5210', ko('5210 Andre personal', 297282)],
    ['6613', ko('6613 Rep & vedlikehold', 482451)],
    ['6450', ko('6450 Leie driftsmidler', 411773)],
    ['6271', ko('6271 Renhold-renovasj.', 394150)],
    ['6590', ko('6590 Forbruksmateriell', 292212)],
  ]),
})

const BP26 = aar({
  ar: 2026,
  salg: 40875850, varekost: 20861893, brutto: 20013957,
  personal: 12246500, timelonn: 7489430, fastlonn: 1861479,
  andreKostnader: 2348428, royalty: 6934489,
  kategorier: new Map([
    ['180', vg('180 Tobakk', 9912503)],
    ['120', vg('120 Mat', 9276278)],
    ['210', vg('210 Bilvask', 7525737, 1127617)],
    ['140', vg('140 Kald drikke', 4969234)],
    ['160', vg('160 Kioskvarer', 3559427)],
    ['200', vg('200 Bil', 1995398)],
    ['170', vg('170 Butikk', 1249344)],
    ['130', vg('130 Varm drikke', 1110472)],
    ['190', vg('190 Fritidsartikler', 928026)],
    ['250', vg('250 Pant', 268690, 268690)],
  ]),
  konti: new Map([
    ['5010', ko('5010 Kostnader', 1861479)],
    ['5012', ko('5012 Kostnader', 7489430)],
    ['6420', ko('6420 Kostnader', 775812)],
    ['6600', ko('6600 Kostnader', 438921)],
    ['6570', ko('6570 Kostnader', 263089)],
    ['6275', ko('6275 Kostnader', 241552)],
  ]),
})

describe('royaltyen', () => {
  it('måler andelen av omsetningen eksakt', () => {
    expect(royaltyandel(BP25)!).toBeCloseTo(0.14797, 5)
    expect(royaltyandel(BP26)!).toBeCloseTo(0.16965, 5)
  })

  it('KANARIFUGL: volum og andel skal summere til hele endringen', () => {
    // Dekomponeringen er det funnet hviler paa. Gaar den ikke opp, er
    // kronene i funnet gjetning - og de ser like sikre ut uansett.
    const r = royaltyEndring(BP25, BP26)!
    expect(r.volum + r.sats).toBeCloseTo(r.totalt, 6)
    expect(r.totalt).toBeCloseTo(6934489 - 5746464, 6)
  })

  it('skiller kostnaden ved satsen fra prisen på vekst', () => {
    const r = royaltyEndring(BP25, BP26)!
    // ~302 000 kr fordi de selger mer, ~886 000 kr fordi andelen steg.
    expect(Math.round(r.volum)).toBeGreaterThan(290_000)
    expect(Math.round(r.volum)).toBeLessThan(310_000)
    expect(Math.round(r.sats)).toBeGreaterThan(870_000)
    expect(Math.round(r.sats)).toBeLessThan(900_000)
  })

  it('gir null når det ikke finnes omsetning', () => {
    expect(royaltyandel(aar({ ar: 2026 }))).toBeNull()
    expect(royaltyEndring(aar({ ar: 2025 }), BP26)).toBeNull()
  })

  it('KANARIFUGL: vask og pant er ikke ordinær omsetning', () => {
    // Vask har sin egen sats og pant har ingen. Blandes de inn i
    // ordinaer omsetning, er tallet ikke lenger det royaltyen maales paa.
    expect(Math.round(ordinaertSalg(BP26))).toBe(33000682)
    // ... som er nettopp alt salget minus vask og pant.
    const alt = [...BP26.kategorier.values()].reduce((a, v) => a + v.salg, 0)
    expect(Math.round(ordinaertSalg(BP26))).toBe(Math.round(alt - 7525737 - 268690))
  })
})

describe('analysen finner det en regnskapsfører ville sett', () => {
  const funn = analyser(BP25, BP26)
  const finn = (id: string) => funn.find((f) => f.id === id)

  it('setter en pris på royaltyendringen', () => {
    const f = finn('royalty')!
    expect(f.alvor).toBe('viktig')
    expect(f.dom).toBe('vond')
    expect(f.tittel).toContain('stiger')
    expect(f.tittel).toContain('14,80 %')
    expect(f.tittel).toContain('16,96 %')
    expect(Math.round(f.kroner!)).toBeGreaterThan(870_000)
  })

  it('KANARIFUGL: høyere lønnsramme er GODT, ikke vondt', () => {
    // Loennsramma er penger St1 legger inn, ikke en kostnad de baerer.
    // Snus denne, er hele fargelogikken paa sida feil igjen.
    const f = finn('lonnsramme')!
    expect(f.dom).toBe('god')
    expect(Math.round(f.kroner!)).toBe(677597)
  })

  it('KANARIFUGL: uten timetall loves ingen kr/time', () => {
    // BP25-malen har ikke timebudsjett. En kr/time regnet paa `timer = 0`
    // ville gitt Infinity - eller verre, et tall som saa fornuftig ut.
    const f = finn('lonnsramme')!
    expect(f.maalt).toContain('Timerammen står ikke i begge årganger')
    expect(f.maalt).not.toMatch(/Infinity|NaN/)
  })

  it('deler lønnsveksten i timer og timepris når begge år har timer', () => {
    const f = analyser(
      { ...BP25, timer: 28824 }, { ...BP26, timer: 30270 },
    ).find((x) => x.id === 'lonnsramme')!
    expect(f.maalt).toMatch(/\+5,0 % timer/)
    expect(f.maalt).toContain('kroner per time')
    expect(f.dom).toBe('god')
  })

  it('ser marginklemmen, og feller ingen dom over den', () => {
    const f = finn('marginklem')!
    expect(f.tittel).toContain('raskere enn salgsmålet')
    // `toLocaleString('nb-NO')` skiller tusener med HARDT mellomrom.
    // Et vanlig mellomrom i paastanden gir en test som feiler paa et
    // tegn ingen kan se.
    const flatt = f.maalt.replace(/\s/g, ' ')
    expect(flatt).toContain('13 529 532')
    expect(flatt).toContain('14 594 928')
    // Ingen dom: en romsligere ramme er ikke et daarlig aar.
    expect(f.dom).toBeUndefined()
  })

  it('peker på hvor veksten ligger', () => {
    const f = finn('vekstkonsentrasjon')!
    expect(f.maalt).toContain('120 Mat')
    expect(f.kroner).toBeGreaterThan(0)
  })

  it('KANARIFUGL: samme varegruppe med nytt navn er ikke to grupper', () => {
    // «160 Kioskvarer ex smaagodt» ble «160 Kioskvarer». Noekles det paa
    // navn, ser gruppa ut som kuttet 100 % OG som splitter ny - to funn
    // som begge er feil, i en liste der alt annet er riktig.
    const kuttet = finn('kuttede-grupper')!
    expect(kuttet.maalt).not.toContain('Kioskvarer')
    // Den skal derimot vises med det NYE navnet, og som vekst.
    expect(finn('vekstkonsentrasjon')!.maalt).toContain('160 Kioskvarer +13,6 %')
  })

  it('KANARIFUGL: sier fra om varegrupper som er budsjettert NED', () => {
    // Det som kuttes er lettest aa overse, og det er der et positivt
    // avvik kan komme av at maalet var satt lavt - ikke av god drift.
    const f = finn('kuttede-grupper')!
    expect(f.maalt).toContain('200 Bil')
    expect(f.maalt).toContain('190 Fritidsartikler')
    expect(f.kroner).toBeLessThan(0)
  })

  it('KANARIFUGL: to ulike kontoplaner gir ikke en linje-for-linje-diff', () => {
    // BP25 har 18 aggregerte konti, BP26 over femti. En diff ga «38 nye,
    // 17 borte» - som ser ut som en stor endring og er null informasjon.
    expect(finn('kontoplan')).toBeUndefined()
    const f = finn('kontoplan-omlagt')!
    expect(f.alvor).toBe('info')
    expect(f.betyr).toContain('ulik oppdeling')
  })

  it('gjør diffen når kontoplanene faktisk er de samme', () => {
    const konti = new Map(BP25.konti)
    konti.delete('6590')
    konti.set('6900', ko('6900 Telefon', 33875))
    const f = analyser(BP25, aar({ ...BP25, ar: 2026, konti }))
      .find((x) => x.id === 'kontoplan')!
    expect(f.maalt).toContain('6900 Telefon')
    expect(f.maalt).toContain('6590 Forbruksmateriell')
  })

  it('gir ingen royaltyfunn når andelen står stille', () => {
    const likt = analyser(BP25, aar({ ...BP25, ar: 2026 }))
    expect(likt.find((f) => f.id === 'royalty')).toBeUndefined()
  })
})

describe('summer', () => {
  const bp = (
    kontoRader: { kode: string; post: string; belopKr: number }[],
    timelonnKr = 0, fastlonnKr = 0,
  ): BpResultat => ({
    rapporttype: 'st1_bp',
    ar: 2026,
    stasjoner: [{
      butikknummer: '9038',
      timerAar: 13877.65,
      maaneder: [{
        maned: 1, salgKr: 100000, varekostKr: 40000, bruttoKr: 60000,
        timelonnKr, fastlonnKr,
        kategorier: [{ kode: '120', post: '120 Mat', salgKr: 60000, varekostKr: 25000 }],
        konti: kontoRader,
      }],
    }],
  })

  it('summerer stasjoner og filtrerer på butikknummer', () => {
    const to: BpResultat = {
      rapporttype: 'st1_bp', ar: 2026,
      stasjoner: [
        ...bp([]).stasjoner,
        { butikknummer: '4185', timerAar: 11187.47, maaneder: [{
          maned: 1, salgKr: 50000, varekostKr: 20000, bruttoKr: 30000,
          timelonnKr: 0, fastlonnKr: 0, kategorier: [], konti: [],
        }] },
      ],
    }
    expect(summer(to).salg).toBe(150000)
    expect(summer(to).timer).toBeCloseTo(25065.12, 2)
    expect(summer(to, ['9038']).salg).toBe(100000)
    expect(summer(to, ['9038']).timer).toBeCloseTo(13877.65, 2)
  })

  it('KANARIFUGL: royalty og FSA er ikke driftskostnader', () => {
    // Tas royaltyen med i kostnadsramma, ser rammen mye stoerre ut enn
    // den er - og FSA staar negativt, saa den ville trukket den ned.
    const t = summer(bp([
      { kode: '6312', post: '6312 Royalty', belopKr: 8000 },
      { kode: '6315', post: '6315 FSA', belopKr: -700 },
      { kode: '6420', post: '6420 Leie driftsmidler', belopKr: 3000 },
    ]))
    expect(t.royalty).toBe(8000)
    expect(t.andreKostnader).toBe(3000)
    expect(t.konti.has('6315')).toBe(false)
    expect(t.konti.has('6312')).toBe(false)
  })

  it('KANARIFUGL: lønn leses av kontoplanen, ikke av splittfeltene', () => {
    // BP25 foerer alt paa 5010 og har ingen splitt. Leses loennen av
    // feltene, blir 2025 staaende paa null og hele kostnadsveksten mot
    // 2026 blir +546 % - et tall som er aapenbart galt, men som en
    // graf tegner like villig som et riktig ett.
    const bp25 = summer(bp([{ kode: '5010', post: '5010 Site Salary costs', belopKr: 9000 }]))
    expect(bp25.personal).toBe(9000)
    expect(bp25.andreKostnader).toBe(0)
    expect(bp25.timelonn).toBe(0)
  })

  it('KANARIFUGL: lønn som står både som felt og som konto telles én gang', () => {
    // BP26 gir begge deler. Summeres de, blir loennsramma dobbel.
    const bp26 = summer(bp(
      [
        { kode: '5010', post: '5010 Kostnader', belopKr: 2000 },
        { kode: '5012', post: '5012 Kostnader', belopKr: 7000 },
      ],
      7000, 2000,
    ))
    expect(bp26.personal).toBe(9000)
    expect(bp26.timelonn).toBe(7000)
    expect(bp26.fastlonn).toBe(2000)
    expect(bp26.andreKostnader).toBe(0)
  })

  it('faller tilbake på splittfeltene når kontoplanen mangler lønn', () => {
    const t = summer(bp([{ kode: '6420', post: '6420 Leie', belopKr: 3000 }], 7000, 2000))
    expect(t.personal).toBe(9000)
    expect(t.andreKostnader).toBe(3000)
  })

  it('nøkler varegrupper på kode og tar vare på varekosten', () => {
    const t = summer(bp([]))
    expect(t.kategorier.get('120')).toEqual({ post: '120 Mat', salg: 60000, varekost: 25000 })
  })
})
