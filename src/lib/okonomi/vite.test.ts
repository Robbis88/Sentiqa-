import { describe, expect, it } from 'vitest'
import { byggOkonomibilde, type Bildeinput, type Dekning, type Regnskapstall } from './bilde'
import { hvaBoerJegViteNaa } from './vite'
import type { Lonnsrom } from '@/lib/lonnskost/rom'

// =====================================================================
// Samme stasjon som `bilde.test.ts` og `rom.test.ts`: Dale, med BP paa
// 1 201 000 i brutto og 383 285 i loenn.
//
// TERSKLENE ER 5 % (gul) og 10 % (roed). Standardfiksturen ligger paa
// 1,75 % over rommet - altsaa NORMAL, og dermed en maaned det ikke er
// noe aa si om. Det er med vilje: «rolig som standard» maa vaere den
// tilstanden testene starter fra, ellers beviser ingen av dem den.
// =====================================================================
const ANDEL = 383285 / 1201000

const ROM = (o: Partial<Lonnsrom> = {}): Lonnsrom => ({
  maaned: '2026-08',
  bruttoKr: 1201000,
  anslaatt: false,
  lonnsandel: ANDEL,
  romKr: 383285,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 4200000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
  ...o,
})

const DEKNING = (o: Partial<Dekning> = {}): Dekning => ({
  salgsdager: { har: 31, av: 31 },
  bilvaskUker: { har: 4, av: 4 },
  lonnsfil: true,
  regnskap: true,
  mangler: [],
  retningPaaFeil: 'ukjent',
  ...o,
})

const REGNSKAP: Regnskapstall = {
  omsetningKr: 4200000,
  bruttoKr: 1201000,
  lonnKr: 390000,
  styringskostKr: 380000, // 1,75 % over rommet - normal
  royaltyKr: 420000,
  paavirkbarDriftKr: 96000,
}

const BILDE = (o: Partial<Bildeinput> = {}) => byggOkonomibilde({
  stasjonId: 's1',
  maaned: '2026-08',
  rom: ROM(),
  regnskap: REGNSKAP,
  easyatworkStyringskostKr: null,
  easyatworkLonnKr: 371000,
  dagligOmsetningKr: 4150000,
  dekning: DEKNING(),
  ...o,
})

const titler = (b: ReturnType<typeof BILDE>) => hvaBoerJegViteNaa(b).map((x) => x.tittel)

describe('rolig som standard', () => {
  it('en maaned der alt er i orden gir INGEN beskjeder', () => {
    // Ikke «ingen funn», ikke et groent kort - en tom liste. Et
    // varselfelt som alltid staar der laerer folk aa se forbi det.
    expect(hvaBoerJegViteNaa(BILDE())).toEqual([])
  })

  it('KANARIFUGL: lista kan faktisk bli ikke-tom', () => {
    // Uten denne ville `() => []` bestaatt testen over, og hele fila
    // ville vaert stum uten at noe ble roedt. Samme form som vakter som
    // har vaert groenne mens de var i stykker.
    const over = BILDE({ regnskap: { ...REGNSKAP, lonnKr: 430000, styringskostKr: 430000 } }) // 12,2 %
    expect(hvaBoerJegViteNaa(over).length).toBeGreaterThan(0)
  })
})

describe('avviket oversettes, det doemmes ikke paa nytt', () => {
  it('over roed terskel blir kritisk', () => {
    const b = BILDE({ regnskap: { ...REGNSKAP, lonnKr: 430000, styringskostKr: 430000 } }) // 12,2 %
    const beskjed = hvaBoerJegViteNaa(b)[0]
    expect(beskjed.nivaa).toBe('kritisk')
    expect(beskjed.tittel).toContain('gikk over rommet')
  })

  it('over gul, men under roed, blir oppmerksomhet', () => {
    const b = BILDE({ regnskap: { ...REGNSKAP, lonnKr: 410000, styringskostKr: 410000 } }) // 6,97 %
    expect(hvaBoerJegViteNaa(b)[0].nivaa).toBe('oppmerksomhet')
  })

  it('KANARIFUGL: nivaaet foelger alvor, det er ikke fast', () => {
    // Uten denne kunne begge testene over bestaatt med en konstant.
    const roed = hvaBoerJegViteNaa(BILDE({ regnskap: { ...REGNSKAP, lonnKr: 430000, styringskostKr: 430000 } }))[0]
    const gul = hvaBoerJegViteNaa(BILDE({ regnskap: { ...REGNSKAP, lonnKr: 410000, styringskostKr: 410000 } }))[0]
    expect(roed.nivaa).not.toBe(gul.nivaa)
  })

  it('ET ANSLAATT AVVIK SIER «LIGGER AN TIL», ikke «gikk»', () => {
    // Forskjellen paa en prognose og en fasit maa staa i SETNINGEN.
    // Uten den leses et anslag som noe som har skjedd.
    const b = BILDE({
      regnskap: null,
      easyatworkLonnKr: 430000,
      // Avviket foelger styringskosten, saa anslaget maa baere den ogsaa
      // - ellers staar avviket som «kan ikke regnes» og testen maaler
      // noe annet enn den tror.
      easyatworkStyringskostKr: 430000,
      rom: ROM({ anslaatt: true }),
      dekning: DEKNING({ regnskap: false }),
    })
    const beskjed = hvaBoerJegViteNaa(b)[0]
    expect(beskjed.tittel).toContain('ligger an til')
    expect(beskjed.tittel).not.toContain('gikk over')
    expect(beskjed.folge).toContain('anslått')
  })
})

describe('manglende dekning, og retningen paa feilen', () => {
  it('én mangel navngis direkte', () => {
    const b = BILDE({ dekning: DEKNING({ mangler: ['Bilvask uke 39'] }) })
    expect(titler(b)[0]).toBe('Bilvask uke 39 mangler.')
  })

  it('flere mangler listes', () => {
    const b = BILDE({ dekning: DEKNING({ mangler: ['Bilvask uke 39', 'Salg 30. august'] }) })
    expect(titler(b)[0]).toContain('Bilvask uke 39, Salg 30. august')
  })

  it('for_lavt sier at rommet er STRAMMERE enn det egentlig er', () => {
    const b = BILDE({
      dekning: DEKNING({ mangler: ['Bilvask uke 39'], retningPaaFeil: 'for_lavt' }),
    })
    expect(hvaBoerJegViteNaa(b)[0].folge).toContain('strammere')
  })

  it('for_hoyt er den FARLIGE retningen og veier tyngre', () => {
    // Et bilde som ser bedre ut enn det er, er samme form som en jobb
    // som returnerer vellykket uten aa ha gjort jobben.
    const lavt = hvaBoerJegViteNaa(BILDE({
      dekning: DEKNING({ mangler: ['Bilvask uke 39'], retningPaaFeil: 'for_lavt' }),
    }))[0]
    const hoyt = hvaBoerJegViteNaa(BILDE({
      dekning: DEKNING({ mangler: ['Bilvask uke 39'], retningPaaFeil: 'for_hoyt' }),
    }))[0]
    expect(hoyt.nivaa).toBe('oppmerksomhet')
    expect(lavt.nivaa).toBe('informasjon')
    expect(hoyt.folge).toContain('bedre ut enn det er')
  })

  it('ukjent retning gir INGEN foelge - en paastand vi ikke kan staa for', () => {
    const b = BILDE({
      dekning: DEKNING({ mangler: ['Bilvask uke 39'], retningPaaFeil: 'ukjent' }),
    })
    expect(hvaBoerJegViteNaa(b)[0].folge).toBeUndefined()
  })
})

describe('hver kjensgjerning sies én gang', () => {
  it('manglende loennsfil gir ÉN beskjed, ikke to', () => {
    // `dekning.lonnsfil` og `styringsavvik.mangler` er to stemmer om
    // samme sak. Uten dedupliseringen sto det «Loennsfila er ikke
    // kommet» rett over «Styringsavviket kan ikke regnes: Loennstallet
    // er ikke kommet enna» - to linjer, samme opplysning.
    const b = BILDE({
      regnskap: null,
      easyatworkLonnKr: null,
      dekning: DEKNING({ lonnsfil: false, regnskap: false }),
    })
    const funn = hvaBoerJegViteNaa(b)
    expect(funn).toHaveLength(1)
    expect(funn[0].tittel).toContain('Lønnsfila er ikke kommet')
  })

  it('KANARIFUGL: en mangel av en ANNEN grunn sies fortsatt', () => {
    // DEN VIKTIGSTE TESTEN I FILA. Dedupliseringen over kunne like
    // gjerne vaert skrevet som «si aldri noe om avviket», og da hadde
    // et bilde uten BP - der det verken finnes rom eller avvik - gitt
    // en TOM liste. Tom betyr «alt i orden».
    const b = BILDE({
      regnskap: { ...REGNSKAP, lonnKr: 390000, styringskostKr: 390000 },
      rom: ROM({ romKr: null, bpLonnKr: null, lonnsandel: null }),
    })
    const funn = hvaBoerJegViteNaa(b)
    expect(funn.map((f) => f.tittel)).toContain('Styringsavviket kan ikke regnes.')
    expect(funn[0].folge).toContain('BP')
  })
})

describe('rekkefoelgen er prioritet', () => {
  it('det som krever handling staar foerst', () => {
    // Flaten skal kunne rendre lista rett ned. Sorterer den selv, har vi
    // to meninger om hva som haster.
    const b = BILDE({
      regnskap: { ...REGNSKAP, lonnKr: 430000, styringskostKr: 430000 },
      dekning: DEKNING({ mangler: ['Bilvask uke 39'], retningPaaFeil: 'for_lavt' }),
    })
    const funn = hvaBoerJegViteNaa(b)
    expect(funn[0].nivaa).toBe('kritisk')
    expect(funn[1].tittel).toContain('Bilvask uke 39')
  })
})

// =====================================================================
// EN AVLAGT MAANED TRENGER INGEN LOENNSFIL
// =====================================================================
//
// PRODUKSJONSFUNN 2026-09-16, avdekket av maanedsreisen i «Min maaned».
// Flaten lot oss for foerste gang aapne en AVLAGT maaned, og da sa
// skjermen to ting samtidig:
//
//     styringskost   391 462  [fasit]
//     styringsavvik   -1 611  [fasit]
//     «Uten den finnes det ingen loenn aa maale mot rommet.»
//
// Laguneparken juli 2026. easy@work-kronefila finnes bare paa tre av fem
// stasjoner, saa tilstanden er normal - ikke et kanttilfelle.
//
// `byggDekning` hadde alt skrevet regelen ned: en avlagt maaned har
// ingen mangler som betyr noe for tallet. Punkt 2 fulgte den; punkt 4
// gjorde det ikke.
//
// De fire kontrastene under er hele rettelsen. Den tredje er den som
// hindrer at rettelsen bytter en usann setning mot en taushet.
// =====================================================================
describe('loennsfilbeskjeden og regnskapsfasiten', () => {
  it('AVLAGT + regnskap + ingen loennsfil: ingen loennsfilbeskjed', () => {
    const b = BILDE({ dekning: DEKNING({ lonnsfil: false, regnskap: true }) })
    expect(titler(b).some((t) => /lønnsfila/i.test(t))).toBe(false)
    // OG TALLENE STAAR. Rettelsen fjerner en setning, ikke et tall.
    expect(b.styringskost.kilde).toBe('fasit')
    expect(b.styringsavvik.kilde).toBe('fasit')
    expect(b.styringsavvik.avvik.mangler).toBeNull()
    expect(b.sikkerhet).toBe('hoy')
  })

  it('AAPEN + ingen loennsfil + ingen fasit: beskjeden staar som foer', () => {
    const b = BILDE({
      regnskap: null,
      easyatworkLonnKr: null,
      easyatworkStyringskostKr: null,
      dekning: DEKNING({ lonnsfil: false, regnskap: false }),
    })
    const funn = hvaBoerJegViteNaa(b)
    expect(funn.map((f) => f.tittel)).toContain('Lønnsfila er ikke kommet for denne måneden.')
    // Og den sies ÉN gang: punkt 3 tier fordi dekningen forklarer det.
    expect(funn.filter((f) => /ikke kommet/i.test(f.tittel))).toHaveLength(1)
  })

  it('AVLAGT + ingen loennsfil + avviket lar seg IKKE regne: mangelen sies likevel', () => {
    // =================================================================
    // RETTELSEN SKAL IKKE GJOERE EN EKTE MANGEL USYNLIG
    // =================================================================
    //
    // Her er fella: strammer man bare punkt 4, tier punkt 3 fortsatt -
    // fordi det tror mangelen «alt er forklart» av en beskjed som ikke
    // lenger blir sagt. Da ville en avlagt maaned med ukjente
    // loennskonti sagt INGENTING om hvorfor avviket mangler.
    //
    // En taushet er verre enn en usann setning: tom liste betyr «alt i
    // orden».
    const b = BILDE({
      // `niva.styringskostKr === null` i produksjon - ukjente konti.
      regnskap: { ...REGNSKAP, styringskostKr: null },
      easyatworkStyringskostKr: null,
      dekning: DEKNING({ lonnsfil: false, regnskap: true }),
    })
    expect(b.styringsavvik.avvik.mangler).not.toBeNull()
    const funn = hvaBoerJegViteNaa(b)
    expect(funn.map((f) => f.tittel)).toContain('Styringsavviket kan ikke regnes.')
    expect(funn.map((f) => f.tittel).some((t) => /lønnsfila/i.test(t))).toBe(false)
  })

  it('manglende grunnlag UTEN regnskapsfasit varsles fortsatt', () => {
    // Salgsdager og bilvaskuker er dekningens egen liste, og den skal
    // ikke roeres av rettelsen.
    const b = BILDE({
      regnskap: null,
      dekning: DEKNING({
        lonnsfil: false, regnskap: false,
        mangler: ['3 salgsdager', '1 bilvaskuke'], retningPaaFeil: 'for_lavt',
      }),
    })
    const funn = hvaBoerJegViteNaa(b)
    expect(funn.map((f) => f.tittel).join(' ')).toContain('3 salgsdager')
    expect(funn.map((f) => f.tittel)).toContain('Lønnsfila er ikke kommet for denne måneden.')
    expect(funn.find((f) => /salgsdager/.test(f.tittel))?.folge).toContain('for lavt')
  })
})
