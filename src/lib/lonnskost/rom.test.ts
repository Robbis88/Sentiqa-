import { describe, expect, it } from 'vitest'
import {
  byggLonnsrom, kalibrering, normalSvinnandel, erDrivstoff, erAvdelingsniva, maanedsrader,
  styringsavvik, type Lonnsrom, type Styringsrom,
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

// =====================================================================
// BILVASKEN SOM KASSA IKKE SER
//
// Abonnementene betales rett til konto. Regnskapet har dem naar det
// kommer - derfor er bilvask der alltid hoeyere enn kassaomsetningen -
// men den aapne maaneden mangler dem.
// =====================================================================
describe('byggLonnsrom med bilvask', () => {
  const juli = [R('2026-07', 4200000, 1201000)]
  const grunn = [G('2026-07', 4200000, 25200), G('2026-08', 4060000, 24360)]

  it('legger bruttobidraget på anslaget', () => {
    const uten = byggLonnsrom(juli, grunn, BP)[0]
    const med = byggLonnsrom(juli, grunn, BP, new Map([['2026-08', 30000]]))[0]
    expect(med.maaned).toBe('2026-08')
    expect(med.bilvaskBruttoKr).toBe(30000)
    expect(med.bruttoKr!).toBeCloseTo(uten.bruttoKr! + 30000, 2)
    // Rommet vokser med loennsandelen av bidraget, ikke med hele.
    expect(med.romKr! - uten.romKr!).toBeCloseTo(30000 * ANDEL, 2)
  })

  // KANARIFUGL FOR DOBBELTTELLING. En avlagt maaned har kronene fra
  // regnskapet alt. Slipper de inn her ogsaa, telles de to ganger - og
  // et for hoeyt brutto gir et for stort rom, altsaa feil i den snille
  // retningen.
  it('rører ikke en avlagt måned', () => {
    const rom = byggLonnsrom(juli, grunn, BP, new Map([['2026-07', 30000]]))
    const j = rom.find((m) => m.maaned === '2026-07')!
    expect(j.anslaatt).toBe(false)
    expect(j.bruttoKr).toBe(1201000)
    expect(j.bilvaskBruttoKr).toBe(0)
  })

  it('uten bilvask er alt som før', () => {
    const uten = byggLonnsrom(juli, grunn, BP)[0]
    expect(uten.bilvaskBruttoKr).toBe(0)
  })
})

// =====================================================================
// STYRINGSAVVIKET
// =====================================================================
//
// Dales BP: 1 201 000 i brutto, 383 285 i loenn. Loennsandel 31,9 %.
//
// Faller brutto 10 % til 1 080 900, faller rommet til 344 957 - og den
// som brukte hele BP-loenna er da 11 % over det hun hadde raad til,
// mens BP-varselet sier null avvik.
// =====================================================================

const ROM = (romKr: number | null, anslaatt = false): Lonnsrom => ({
  maaned: '2026-08',
  bruttoKr: romKr === null ? null : romKr / ANDEL,
  anslaatt,
  lonnsandel: ANDEL,
  romKr,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 4200000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
})

/** Rommet naar bruttoen faller ti prosent under planen. */
const ROM_SVAKT = ROM(ANDEL * 1080900)

describe('styringsavvik', () => {
  it('maaler mot ROMMET, ikke mot BP-loenna', () => {
    // Samme `bpLonnKr` i begge, ulikt rom. Maalte den mot BP, ville de
    // to gitt samme svar - og det er hele feilen denne funksjonen
    // finnes for aa hindre.
    const paaPlanen = styringsavvik(ROM(383285), 383285)
    const svaktSalg = styringsavvik(ROM_SVAKT, 383285)

    expect(paaPlanen.kroner).toBeCloseTo(0, 6)
    expect(paaPlanen.alvor).toBe('normal')

    expect(svaktSalg.kroner).toBeGreaterThan(38000)
    expect(svaktSalg.alvor).toBe('handling')
  })

  it('KANARIFUGL: de to rommene har SAMME bpLonnKr', () => {
    // Uten denne kunne testen over bestaatt fordi fiksturene skilte seg
    // paa BP i stedet for paa rommet.
    expect(ROM(383285).bpLonnKr).toBe(ROM_SVAKT.bpLonnKr)
    expect(ROM(383285).romKr).not.toBeCloseTo(ROM_SVAKT.romKr!, 0)
  })

  it('bruker tersklene fra regnskap/terskler, ikke egne', () => {
    const rom = ROM_SVAKT.romKr!
    // Rett under 5 % er normalt, rett over er en endring.
    expect(styringsavvik(ROM_SVAKT, rom * 1.049).alvor).toBe('normal')
    expect(styringsavvik(ROM_SVAKT, rom * 1.051).alvor).toBe('endring')
    // Rett under 10 % er fortsatt endring, rett over krever handling.
    expect(styringsavvik(ROM_SVAKT, rom * 1.099).alvor).toBe('endring')
    expect(styringsavvik(ROM_SVAKT, rom * 1.101).alvor).toBe('handling')
  })

  it('under rommet gir negative kroner og ingen alarm', () => {
    const v = styringsavvik(ROM_SVAKT, ROM_SVAKT.romKr! * 0.9)
    expect(v.kroner).toBeLessThan(0)
    expect(v.andelAvRom).toBeCloseTo(-0.1, 6)
    expect(v.alvor).toBe('normal')
  })

  // =================================================================
  // ET MANGLENDE TALL ER IKKE ET AVVIK PAA NULL
  // =================================================================
  it('sier fra naar loennstallet ikke er kommet', () => {
    const v = styringsavvik(ROM(383285), null)
    expect(v.kroner).toBeNull()
    expect(v.mangler).toMatch(/ikke kommet/)
    // IKKE null kroner. En maaned uten loennsfil ville ellers sett ut
    // som en maaned i balanse.
    expect(v.kroner).not.toBe(0)
  })

  it('sier fra naar BP mangler, saa det ikke finnes noe rom', () => {
    const v = styringsavvik(ROM(null), 383285)
    expect(v.kroner).toBeNull()
    expect(v.mangler).toMatch(/BP/)
  })

  // =================================================================
  // TYPEGRENSEN, HAANDHEVET AV KOMPILATOREN
  // =================================================================
  //
  // Paastanden var «strukturelt umulig aa maale mot BP». Den var ikke
  // sann saa lenge signaturen tok hele `Lonnsrom`, som BAERER
  // `bpLonnKr`. Naa tar den `Styringsrom` - to felt - og da er det
  // `tsc` som sier nei, ikke en roed test.
  it('KANARIFUGL: typegrensen sperrer for bpLonnKr', () => {
    const rom: Styringsrom = { romKr: 344957, anslaatt: false }
    // @ts-expect-error `bpLonnKr` finnes ikke paa `Styringsrom`, og det
    // er hele poenget. Utvides typen tilbake til `Lonnsrom`, slutter
    // dette aa vaere en feil - og da feiler `tsc` paa en ubrukt
    // `@ts-expect-error`.
    expect(rom.bpLonnKr).toBeUndefined()
  })

  it('avviser et rom som ikke er et tall', () => {
    // Hver sammenligning mot NaN er usann, saa `NaN <= 0` slipper
    // gjennom. Uten en egen finite-vakt ville maaneden staatt som
    // `normal` med `NaN` kroner - rolig fordi tallet var oedelagt.
    for (const rom of [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
      const v = styringsavvik({ romKr: rom, anslaatt: false }, 383285)
      expect(v.kroner, String(rom)).toBeNull()
      expect(v.andelAvRom, String(rom)).toBeNull()
      expect(v.mangler, String(rom)).toMatch(/ikke et tall|null eller negativt/)
    }
  })

  it('KANARIFUGL: uten finite-vakten ville NaN gitt normal med NaN-beloep', () => {
    // Beviser at det er VAKTEN som fanger det, ikke `<= 0`-testen.
    expect(Number.NaN <= 0).toBe(false)
    expect(Number.NaN >= 10).toBe(false)
    expect(Number.isFinite(Number.NaN)).toBe(false)
  })

  it('deler ikke paa et rom som er null eller negativt', () => {
    for (const rom of [0, -1000]) {
      const v = styringsavvik(ROM(rom), 383285)
      expect(v.andelAvRom, `rom ${rom}`).toBeNull()
      expect(Number.isFinite(v.andelAvRom ?? 0)).toBe(true)
      expect(v.mangler).toMatch(/null eller negativt/)
    }
  })

  // =================================================================
  // ET ANSLAATT AVVIK ER LIKE ALVORLIG - OG SKAL MERKES
  // =================================================================
  it('arver rommets usikkerhet uten aa dempe alvoret', () => {
    const sikkert = styringsavvik(ROM(ANDEL * 1080900, false), 383285)
    const anslaatt = styringsavvik(ROM(ANDEL * 1080900, true), 383285)

    expect(sikkert.anslaatt).toBe(false)
    expect(anslaatt.anslaatt).toBe(true)
    // Hele poenget med aa ligge foran regnskapet er at et anslag er
    // verdt aa handle paa. Sikkerheten staar ved siden av tallet;
    // alvoret trekkes ikke ned.
    expect(anslaatt.alvor).toBe(sikkert.alvor)
    expect(anslaatt.kroner).toBe(sikkert.kroner)
  })

  it('anslaatt foelger med ogsaa naar avviket ikke kan regnes', () => {
    expect(styringsavvik(ROM(null, true), 383285).anslaatt).toBe(true)
  })
})
