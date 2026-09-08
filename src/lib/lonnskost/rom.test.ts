import { describe, expect, it } from 'vitest'
import {
  byggLonnsrom, kalibrering, normalSvinnandel, erDrivstoff, erAvdelingsniva, maanedsrader,
} from './rom'

const R = (maaned: string, omsetningKr: number | null, bruttoKr: number | null) =>
  ({ maaned, omsetningKr, bruttoKr })
const G = (maaned: string, omsetningKr: number, svinnKr = 0) =>
  ({ maaned, omsetningKr, svinnKr })
const B = (
  maaned: string, omsetningKr: number | null, bruttoKr: number | null, lonnKr: number | null,
) => ({ maaned, omsetningKr, bruttoKr, lonnKr })

// BP for Dale: 4 200 000 i omsetning, 1 201 000 i brutto, 383 285 i loenn.
// Loennsandel 31,9 %, planlagt margin 28,6 %.
const BP = [
  B('2026-08', 4200000, 1201000, 383285),
  B('2026-07', 4200000, 1201000, 383285),
]
const ANDEL = 383285 / 1201000

describe('kalibrering', () => {
  it('gir 1,0 når stasjonen treffer planen', () => {
    expect(kalibrering([R('2026-07', 4200000, 1201000)], BP)).toBeCloseTo(1, 6)
  })

  // Halvparten av salget, men bare 40 % av brutto: marginen er svakere
  // enn planen, og kalibreringen skal fange det - ikke salgssvikten, som
  // skaleringen alt tar.
  it('fanger svakere margin, ikke svakere salg', () => {
    // Samme omsetning som BP, men brutto 10 % under: kalibrering 0,9.
    expect(kalibrering([R('2026-07', 4200000, 1080900)], BP)).toBeCloseTo(0.9, 6)
    // Halv omsetning og halv brutto: planen treffes, kalibrering 1,0.
    expect(kalibrering([R('2026-07', 2100000, 600500)], BP)).toBeCloseTo(1, 6)
  })

  // AA ANTA 1,0 VILLE VAERT AA PAASTAA AT PLANEN TREFFER, uten et tall bak.
  it('gir null når ingen måned kan måles', () => {
    expect(kalibrering([], BP)).toBeNull()
    expect(kalibrering([R('2026-07', 4200000, 1201000)], [])).toBeNull()
    expect(kalibrering([R('2026-07', null, 1201000)], BP)).toBeNull()
  })
})

describe('normalSvinnandel', () => {
  it('måler svinn mot omsetning i de lukkede månedene', () => {
    const a = normalSvinnandel(
      [G('2026-07', 4200000, 25200), G('2026-08', 4060000, 90000)],
      new Set(['2026-07']),
    )
    expect(a).toBeCloseTo(0.006, 6)
  })

  it('gir null uten en lukket måned å lære av', () => {
    expect(normalSvinnandel([G('2026-08', 4060000, 24000)], new Set())).toBeNull()
  })
})

describe('byggLonnsrom', () => {
  const juli = [R('2026-07', 4200000, 1201000)]
  const grunnlag = (augSvinn: number) => [
    G('2026-07', 4200000, 25200), // 0,6 % - det normale
    G('2026-08', 4060000, augSvinn),
  ]

  it('skalerer BP-brutto med hvor mye av salget som kom', () => {
    const [aug] = byggLonnsrom(juli, grunnlag(24360), BP)
    expect(aug.maaned).toBe('2026-08')
    expect(aug.anslaatt).toBe(true)
    expect(aug.kalibrering).toBeCloseTo(1, 6)
    expect(aug.lonnsandel).toBeCloseTo(ANDEL, 6)
    // 1 201 000 x (4 060 000 / 4 200 000) x 1,0
    expect(aug.bruttoKr).toBeCloseTo(1201000 * (4060000 / 4200000), 2)
    expect(aug.romKr).toBeCloseTo(ANDEL * aug.bruttoKr!, 2)
  })

  // ===================================================================
  // KANARIFUGLEN FOR DOBBELTTELLINGEN.
  //
  // Regnskapets brutto er ALLEREDE fratrukket svinn - malt i denne
  // oekta: teoretisk minus faktisk brutto var 157 842, kast pluss
  // usynlig svinn 156 493. Foerste utgave regnet
  // `omsetning x margin - svinn` med en margin laert av regnskapet, og
  // trakk dermed svinnet fra to ganger. Paa Dale august ga det et
  // loennsrom ~7 700 kroner for lite.
  //
  // Normalt svinn skal IKKE bite. Bare avviket.
  // ===================================================================
  it('trekker ikke fra svinn som ligger på det normale', () => {
    const [aug] = byggLonnsrom(juli, grunnlag(24360), BP) // 0,6 % av 4 060 000
    expect(aug.ekstraSvinnKr).toBe(0)
    expect(aug.bruttoKr).toBeCloseTo(1201000 * (4060000 / 4200000), 2)
  })

  it('lar bare svinn utover det normale krympe rommet', () => {
    const normalt = byggLonnsrom(juli, grunnlag(24360), BP)[0]
    const mye = byggLonnsrom(juli, grunnlag(44360), BP)[0]
    expect(mye.ekstraSvinnKr).toBeCloseTo(20000, 2)
    expect(mye.bruttoKr!).toBeCloseTo(normalt.bruttoKr! - 20000, 2)
    // Rommet krymper med loennsandelen av de ekstra kronene.
    expect(normalt.romKr! - mye.romKr!).toBeCloseTo(20000 * ANDEL, 2)
  })

  // EN UVANLIG REN MAANED SKAL IKKE GI EKSTRA ROM. Et lavt svinn fanges
  // naar maaneden lukkes; aa forskuttere det ville vaert aa laane av seg
  // selv.
  it('gir ikke bonus for en uvanlig ren måned', () => {
    const [aug] = byggLonnsrom(juli, grunnlag(0), BP)
    expect(aug.ekstraSvinnKr).toBe(0)
    expect(aug.bruttoKr).toBeCloseTo(1201000 * (4060000 / 4200000), 2)
  })

  it('bruker regnskapets brutto når måneden er avlagt', () => {
    const rom = byggLonnsrom(
      [R('2026-07', 4200000, 1150000)], grunnlag(24360), BP,
    )
    const j = rom.find((m) => m.maaned === '2026-07')!
    expect(j.anslaatt).toBe(false)
    expect(j.bruttoKr).toBe(1150000)
    expect(j.ekstraSvinnKr).toBe(0)
  })

  // EN NY KJEDE SKAL IKKE STAA UTEN SVAR. Uten avlagt regnskap staar
  // anslaget paa BP-en alene - daarligere enn kalibrert, men langt bedre
  // enn ingenting, og det byttes ut av seg selv naar foerste rapport er
  // inne.
  it('står på BP-en alene uten avlagt regnskap', () => {
    const [aug] = byggLonnsrom([], [G('2026-08', 4060000, 24000)], BP)
    expect(aug.kalibrering).toBeNull()
    expect(aug.ekstraSvinnKr).toBe(0)
    expect(aug.romKr).toBeCloseTo(ANDEL * 1201000 * (4060000 / 4200000), 2)
  })

  it('gir null rom når BP mangler', () => {
    const [aug] = byggLonnsrom(juli, grunnlag(24360), [B('2026-08', null, null, null)])
    expect(aug.lonnsandel).toBeNull()
    expect(aug.romKr).toBeNull()
  })

  it('deler ikke på null', () => {
    const [aug] = byggLonnsrom([], [G('2026-08', 100, 0)], [B('2026-08', 0, 0, 383285)])
    expect(aug.lonnsandel).toBeNull()
    expect(aug.romKr).toBeNull()
  })
})

// =====================================================================
// DRIVSTOFF SKAL ALDRI INN I BROEKEN
//
// Regnskapets omsetning og bruttofortjeneste per stasjon har en rad per
// avdelingsrollup, og drivstoff er en av dem. Omsetningen paa den andre
// siden kommer fra `v_butikksalg`, som holder drivstoff utenfor.
// Drivstoff er ~68 % av omsetningen: blandet ville kalibreringen blitt
// meningsloes.
// =====================================================================
describe('erDrivstoff', () => {
  it('kjenner igjen avdelingen på navnet', () => {
    expect(erDrivstoff('ENERGI')).toBe(true)
    expect(erDrivstoff('energi')).toBe(true)
  })

  // TO KILDER, TO NAVN PAA DET SAMME. Salgsdataene kaller avdelingen
  // ENERGI; regnskapsrapporten kaller den `10 Drivstoff`. Bare det
  // foerste var dekket, saa drivstoff slapp gjennom paa regnskapssida.
  it('kjenner begge navnene', () => {
    expect(erDrivstoff('10 Drivstoff')).toBe(true)
    expect(erDrivstoff('ENERGI')).toBe(true)
  })

  // NAVNET, IKKE KODEN. AGENTS.md: kodeverdien varierer mellom kjeder.
  it('slipper butikkens egne avdelinger gjennom', () => {
    expect(erDrivstoff('MAT')).toBe(false)
    expect(erDrivstoff('KIOSK')).toBe(false)
    expect(erDrivstoff('1000')).toBe(false)
  })
})

// =====================================================================
// ROLLUPEN OG DELENE ER SAMME KRONER
//
// Regnskapet gir begge nivaaene som egne rader. Summeres begge, telles
// hver krone to ganger - og feilen traff BARE de avlagte maanedene,
// siden den inneVAERENDE regnes av daglige salgstall uten rollups.
// Sida saa derfor riktig ut for august og gal for alt foer.
// =====================================================================
describe('erAvdelingsniva', () => {
  it('tar avdelingene, ikke varegruppene under', () => {
    expect(erAvdelingsniva('40 CR')).toBe(true)
    expect(erAvdelingsniva('10 Drivstoff')).toBe(true)
    expect(erAvdelingsniva('120 Mat')).toBe(false)
    expect(erAvdelingsniva('140 Kald drikke')).toBe(false)
    expect(erAvdelingsniva('250 Pant')).toBe(false)
  })

  // FASIT FRA DALE. `40 CR` er noeyaktig summen av varegruppene under -
  // 10 444 947 mot 10 444 946, én krone fra avrunding. Summeres begge,
  // blir bruttoen dobbel.
  it('holder Dale-rollupen fra aa telles to ganger', () => {
    const rader = [
      { post: '40 CR', kr: 10444947 },
      { post: '120 Mat', kr: 4926038 },
      { post: '140 Kald drikke', kr: 1641156 },
      { post: '160 Kioskvarer', kr: 1268443 },
      { post: '180 Tobakk', kr: 892358 },
      { post: '130 Varm drikke', kr: 785535 },
      { post: '200 Bil', kr: 489387 },
      { post: '190 Fritidsartikler', kr: 249156 },
      { post: '250 Pant', kr: 98415 },
      { post: '170 Butikk', kr: 94352 },
      { post: '240 Drift', kr: 106 },
    ]
    const alt = rader.reduce((a, r) => a + r.kr, 0)
    const bare = rader.filter((r) => erAvdelingsniva(r.post)).reduce((a, r) => a + r.kr, 0)
    expect(bare).toBe(10444947)
    // Kanarifugl: uten filteret blir summen naer det dobbelte.
    expect(alt).toBeCloseTo(bare * 2, -3)
  })

  it('sier nei til en post uten ledetall', () => {
    expect(erAvdelingsniva('CR')).toBe(false)
    expect(erAvdelingsniva('')).toBe(false)
  })
})

// =====================================================================
// EN OPPLASTET MAANED SKAL ALDRI VAERE USYNLIG
//
// Boenes august: loennsartfila var lastet opp, men stasjonen manglet
// BP-rader for maaneden - og `byggLonnskost` hopper over en maaned uten
// verken regnskap eller BP. Raden fantes derfor ikke, og skjermen saa ut
// som om ingenting var kommet inn.
// =====================================================================
describe('maanedsrader', () => {
  it('tar med en måned som bare har easy@work-data', () => {
    const r = maanedsrader(
      [{ maaned: '2026-07' }],
      [{ maaned: '2026-08' }],
      [],
    )
    expect(r).toEqual(['2026-08', '2026-07'])
  })

  it('tar med en måned som bare har et lønnsrom', () => {
    expect(maanedsrader([], [], [{ maaned: '2026-09', romKr: 1000 }]))
      .toEqual(['2026-09'])
  })

  // Et rom som ikke lot seg regne er ingen rad - den ville staatt tom i
  // hver eneste kolonne.
  it('tar ikke med en måned uten noe å vise', () => {
    expect(maanedsrader([], [], [{ maaned: '2026-09', romKr: null }])).toEqual([])
  })

  it('slår sammen uten duplikater, nyeste først', () => {
    expect(maanedsrader(
      [{ maaned: '2026-07' }, { maaned: '2026-06' }],
      [{ maaned: '2026-07' }, { maaned: '2026-08' }],
      [{ maaned: '2026-06', romKr: 1 }],
    )).toEqual(['2026-08', '2026-07', '2026-06'])
  })
})
