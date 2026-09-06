import { describe, it, expect } from 'vitest'
import { velgKilde, svinnstatus, kildenotat, svinnbilde, vareomradeAv, avdelingAv, nevnerHolderIkke, usynligstatus, type Budsjettlinje } from './mot-budsjett'

// =====================================================================
// Vakt over svinn mot budsjett.
//
// To kilder for samme maaned er én for mye. Reglene her avgjoer hvilken
// som gjelder, og om leseren faar vite det.
// =====================================================================

const LINJE: Budsjettlinje = {
  kode: '120', navn: 'MAT',
  kastPstAvSalg: 0.08415231157126303,
  kastBudsjettKr: 398657.63,
}

const kart = (o: Record<string, number>) => new Map(Object.entries(o))

describe('velgKilde', () => {
  // AVLAGT MAANED VINNER. To tall for samme maaned er ett for mye, og
  // det som gjelder utad maa vaere regnskapets.
  it('lar regnskapet slaa den daglige opplastingen', () => {
    const ut = velgKilde(kart({ '2026-07': 31000 }), kart({ '2026-07': 28000 }), kart({ '2026-07': 400000 }))
    expect(ut).toEqual([{ maaned: '2026-07', kastKr: 31000, kilde: 'regnskap', salgKr: 400000 }])
  })

  it('bruker den daglige der regnskapet ikke er kommet', () => {
    const ut = velgKilde(kart({}), kart({ '2026-08': 28000 }), kart({ '2026-08': 400000 }))
    expect(ut[0].kilde).toBe('daglig')
    expect(ut[0].kastKr).toBe(28000)
  })

  // KANARIFUGL. `||` i stedet for `??` ville latt en avlagt maaned med
  // NULL kastet falle tilbake paa den daglige summen - og da hadde
  // regnskapet sagt null mens skjermen viste 28 000.
  it('lar 0 kr i en avlagt maaned staa som 0', () => {
    const ut = velgKilde(kart({ '2026-07': 0 }), kart({ '2026-07': 28000 }), kart({ '2026-07': 400000 }))
    expect(ut[0].kastKr).toBe(0)
    expect(ut[0].kilde).toBe('regnskap')
  })

  it('tar med maaneder som bare finnes i én av kildene', () => {
    const ut = velgKilde(kart({ '2026-06': 30000 }), kart({ '2026-07': 28000 }), kart({}))
    expect(ut.map((m) => m.maaned)).toEqual(['2026-06', '2026-07'])
    expect(ut.map((m) => m.kilde)).toEqual(['regnskap', 'daglig'])
  })

  it('sorterer kronologisk', () => {
    const ut = velgKilde(kart({}), kart({ '2026-08': 1, '2026-02': 1, '2026-05': 1 }), kart({}))
    expect(ut.map((m) => m.maaned)).toEqual(['2026-02', '2026-05', '2026-08'])
  })
})

describe('svinnstatus', () => {
  const mnd = (m: string, kast: number, salg: number, kilde: 'regnskap' | 'daglig' = 'daglig') =>
    ({ maaned: m, kastKr: kast, salgKr: salg, kilde })

  // BUDSJETTET FOELGER SALGET. Kravet er en prosent, saa aaret delt paa
  // tolv ville vaert feil hver eneste maaned med sesong i.
  it('regner budsjettet av salget, ikke av kalenderen', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 30000, 400000), mnd('2026-08', 32000, 450000)])
    expect(s.salgHittilKr).toBe(850000)
    expect(Math.round(s.budsjettHittilKr)).toBe(Math.round(0.08415231157126303 * 850000))
    // ... og IKKE aarsbudsjettet delt paa tolv ganger to.
    expect(Math.round(s.budsjettHittilKr)).not.toBe(Math.round(398657.63 / 6))
  })

  it('gir positivt avvik naar det er kastet for mye', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 50000, 400000)])
    expect(s.avvikKr).toBeGreaterThan(0)
  })

  it('gir negativt avvik naar stasjonen ligger under', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 20000, 400000)])
    expect(s.avvikKr).toBeLessThan(0)
  })

  it('teller kildene hver for seg', () => {
    const s = svinnstatus(LINJE, [
      mnd('2026-06', 30000, 400000, 'regnskap'),
      mnd('2026-07', 31000, 410000, 'regnskap'),
      mnd('2026-08', 28000, 420000, 'daglig'),
    ])
    expect(s.avlagteMaaneder).toBe(2)
    expect(s.forelopigeMaaneder).toBe(1)
  })

  // Ingen salg gir ingen prosent. 0 % ville sett ut som en maaling.
  it('gir null prosent - ikke 0 - uten salg', () => {
    expect(svinnstatus(LINJE, [mnd('2026-07', 0, 0)]).faktiskPst).toBeNull()
  })
})

describe('kildenotat', () => {
  const status = (avlagt: number, forelopig: number) => svinnstatus(LINJE, [
    ...Array.from({ length: avlagt }, (_, i) => ({ maaned: `2026-0${i + 1}`, kastKr: 1, salgKr: 1, kilde: 'regnskap' as const })),
    ...Array.from({ length: forelopig }, (_, i) => ({ maaned: `2026-1${i}`, kastKr: 1, salgKr: 1, kilde: 'daglig' as const })),
  ])

  // Et tall uten kildeangivelse leses som fasit. Notatet staar aldri tomt.
  it('sier alltid noe om hvor tallet kommer fra', () => {
    for (const [a, f] of [[0, 0], [3, 0], [0, 2], [2, 1]]) {
      const t = kildenotat(status(a, f))
      expect(t.length, `${a} avlagte, ${f} forelopige`).toBeGreaterThan(15)
    }
  })

  it('sier «fasit» bare naar alt er avlagt', () => {
    expect(kildenotat(status(3, 0))).toMatch(/fasit/)
    expect(kildenotat(status(2, 1))).not.toMatch(/fasit/)
  })

  it('varsler at tallet kan flytte seg naar noe er forelopig', () => {
    expect(kildenotat(status(2, 1))).toMatch(/flytte seg/)
    expect(kildenotat(status(0, 2))).toMatch(/flytte seg/)
  })
})

describe('regnskapskoden', () => {
  // `13010` er 130 VARM DRIKKE >> 10 KAFFE. Samme nummerering som
  // salgsdataene, bare skrevet i ett - og det er dét som lar de to
  // kildene legges ved siden av hverandre.
  it('deler koden i avdeling og vareomraade', () => {
    expect(avdelingAv('12010')).toBe('120')
    expect(vareomradeAv('12010')).toBe('10')
    expect(vareomradeAv('13011')).toBe('11')
  })

  // KANARIFUGL. Regnskapet har ogsaa korte koder (`120`, `40`) og
  // tekstkoder. Et blindt `slice(3)` ville laget vareomraade `''` av
  // dem og slaatt dem sammen til én meningsloes linje.
  it('svarer null paa alt som ikke er fem siffer', () => {
    for (const k of ['120', '4', 'RESULTAT', '', null, '1201', '120100']) {
      expect(vareomradeAv(k), String(k)).toBeNull()
    }
  })
})

describe('svinnbilde', () => {
  const b = (kode: string, navn: string, pst: number, kr: number): Budsjettlinje =>
    ({ kode, navn, kastPstAvSalg: pst, kastBudsjettKr: kr })
  const m = (o: Record<string, Record<string, number>>) =>
    new Map(Object.entries(o).map(([k, v]) => [k, new Map(Object.entries(v))]))

  it('setter hver linje mot sitt eget krav', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 119577), b('11', 'PØLSE', 0.058, 83663)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { '2026-08': 12000 }, '11': { '2026-08': 4000 } }),
      salg: m({ '10': { '2026-08': 80000 }, '11': { '2026-08': 120000 } }),
    })
    expect(ut.linjer).toHaveLength(2)
    // Bakeri: 12 000 kastet mot 12 % av 80 000 = 9 600. Over.
    const bakeri = ut.linjer.find((l) => l.linje.kode === '10')!
    expect(Math.round(bakeri.budsjettHittilKr)).toBe(9600)
    expect(bakeri.avvikKr).toBeGreaterThan(0)
  })

  it('sorterer verst foerst', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 1), b('11', 'PØLSE', 0.06, 1)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 100 }, '11': { x: 9000 } }),
      salg: m({ '10': { x: 10000 }, '11': { x: 10000 } }),
    })
    expect(ut.linjer[0].linje.kode).toBe('11')
  })

  // TOTALEN ER SUMMEN AV LINJENE. Budsjettet baerer baade Mat-totalen og
  // undergruppene; leste vi begge og la dem sammen, ville hver krone
  // telt to ganger.
  it('summerer linjene i stedet for aa lese en egen totalrad', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.1, 1000), b('11', 'PØLSE', 0.1, 2000)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 500 }, '11': { x: 700 } }),
      salg: m({ '10': { x: 5000 }, '11': { x: 9000 } }),
    })
    expect(ut.total!.kastHittilKr).toBe(1200)
    expect(ut.total!.salgHittilKr).toBe(14000)
    expect(ut.total!.linje.kastBudsjettKr).toBe(3000)
  })

  // Bakeri kaster 12 % av lite, poelse 6 % av mye. Snittet av de to
  // prosentene beskriver ingen av dem.
  it('gir en VEID totalprosent, ikke et snitt av linjenes', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 1), b('11', 'PØLSE', 0.06, 1)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 0 }, '11': { x: 0 } }),
      salg: m({ '10': { x: 10000 }, '11': { x: 90000 } }),
    })
    // Veid: (0,12*10 000 + 0,06*90 000) / 100 000 = 6,6 %. Snitt: 9 %.
    expect(Math.round(ut.total!.linje.kastPstAvSalg * 1000) / 10).toBeCloseTo(6.6, 1)
  })

  it('sier fra naar det ikke finnes noe budsjett', () => {
    const ut = svinnbilde({ budsjett: [], kastRegnskap: m({}), kastDaglig: m({}), salg: m({}) })
    expect(ut.total).toBeNull()
    expect(ut.notat).toMatch(/Ingen kastbudsjett/)
  })

  it('teller kildene i totalens notat', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.1, 1)],
      kastRegnskap: m({ '10': { '2026-07': 900 } }),
      kastDaglig: m({ '10': { '2026-08': 800 } }),
      salg: m({ '10': { '2026-07': 9000, '2026-08': 9000 } }),
    })
    expect(ut.total!.avlagteMaaneder).toBe(1)
    expect(ut.total!.forelopigeMaaneder).toBe(1)
    expect(ut.notat).toMatch(/flytte seg/)
  })
})

// =====================================================================
// NEVNEREN — REGRESJONEN FRA 2026-09-05
//
// `/svinn` viste «Kast av omsetning 778,6 %» og «budsjett 2 983 kr» der
// kravet er 13,59 % og årsbudsjettet 238 393. Ingenting feilet; tallet
// var bare galt på en måte som ikke lignet en feil.
//
// Telleren var riktig hele tiden. `regnskap_usynlig_svinn` har én rad
// per kode per måned og ligger under ethvert radtak. Nevneren kom fra
// `v_butikksalg` RAD FOR RAD, og PostgREST kuttet uttrekket.
//
//     Bønes, MAT, 2026, faktisk:   1 220 436 kr
//     det siden fikk se:              21 950 kr
//
// Tallene under er de virkelige, ikke runde. En fixture med runde tall
// ville bestått uansett hvor grensen gikk.
// =====================================================================

const BONES: Budsjettlinje = {
  kode: '120', navn: 'MAT',
  kastPstAvSalg: 0.1359,
  kastBudsjettKr: 238393,
}

describe('nevnerHolderIkke', () => {
  // GRENSEN ER EN IDENTITET, IKKE ET SKJØNN. Kast føres til kostpris og
  // salg til utsalgspris, så kastet kan aldri være størst. En
  // «rimelighetsgrense» på for eksempel 50 % ville felt en ekte
  // katastrofemåned og sluppet gjennom en nevner som var halvert.
  it('sier fra når kastet overstiger salget', () => {
    expect(nevnerHolderIkke(170880, 21950)).toBe(true)
  })

  it('sier ingenting om et normalt forhold', () => {
    expect(nevnerHolderIkke(170880, 1220436)).toBe(false)
  })

  // Et helt normalt tilfelle tidlig i året, og det skal IKKE ropes om.
  it('KANARIFUGL: ingen data er ikke en feil', () => {
    expect(nevnerHolderIkke(0, 0)).toBe(false)
  })

  it('kast uten noe salg i det hele tatt er det derimot', () => {
    expect(nevnerHolderIkke(1, 0)).toBe(true)
  })

  // Grensen går ved likhet: like store tall er teoretisk mulig, og en
  // vakt som feller det ville ropt på et randtilfelle som er ekte.
  it('felles ikke ved nøyaktig likhet', () => {
    expect(nevnerHolderIkke(1000, 1000)).toBe(false)
  })
})

describe('svinnstatus — den avkortede nevneren', () => {
  const med = (kast: number, salg: number) => svinnstatus(BONES, [
    { maaned: '2026-01', kastKr: kast, salgKr: salg, kilde: 'regnskap' },
  ])

  it('REGRESJON: flagger tallet siden faktisk viste', () => {
    const s = med(170880, 21950)
    expect(s.nevnerMistenkelig).toBe(true)
    // Prosenten REGNES fortsatt — den er beviset på at noe er galt.
    // Det er visningen som skal holde den tilbake, ikke regnestykket.
    expect(Math.round(s.faktiskPst! * 100)).toBe(778)
  })

  it('er rolig når salget er hentet helt', () => {
    const s = med(170880, 1220436)
    expect(s.nevnerMistenkelig).toBe(false)
    // Og da er bildet et helt annet: 14,0 % mot et krav på 13,59 %,
    // altså så vidt over — ikke åtte ganger over.
    expect((s.faktiskPst! * 100).toFixed(1)).toBe('14.0')
    expect(Math.round(s.budsjettHittilKr)).toBe(165857)
    expect(Math.round(s.avvikKr)).toBe(5023)
  })
})

describe('svinnbilde — totalen arver mistanken', () => {
  // En enkelt linje med manglende nevner drar hele prosenten med seg.
  // En total som ser rolig ut over en oedelagt linje er verre enn ingen
  // total: da er feilen bare gjemt ett nivaa ned.
  it('flagger totalen naar én linje har en umulig nevner', () => {
    const ut = svinnbilde({
      budsjett: [
        { kode: '10', navn: 'BAKERI', kastPstAvSalg: 0.12, kastBudsjettKr: 100000 },
        { kode: '11', navn: 'PØLSE', kastPstAvSalg: 0.06, kastBudsjettKr: 80000 },
      ],
      kastRegnskap: new Map([
        ['10', kart({ '2026-01': 50000 })],
        ['11', kart({ '2026-01': 5000 })],
      ]),
      kastDaglig: new Map(),
      // BAKERI mangler salg; PØLSE har rikelig, nok til at TOTALEN ser
      // frisk ut om man bare summerer.
      salg: new Map([
        ['10', kart({ '2026-01': 900 })],
        ['11', kart({ '2026-01': 900000 })],
      ]),
    })
    expect(ut.linjer.find((l) => l.linje.kode === '10')!.nevnerMistenkelig).toBe(true)
    expect(ut.linjer.find((l) => l.linje.kode === '11')!.nevnerMistenkelig).toBe(false)
    // Summen alene ville sagt «alt i orden»: 55 000 mot 900 900.
    expect(ut.total!.kastHittilKr).toBeLessThan(ut.total!.salgHittilKr)
    expect(ut.total!.nevnerMistenkelig).toBe(true)
  })
})

// =====================================================================
// USYNLIG SVINN — DEN ANDRE HALVDELEN
//
// Identiteten St1 regner med, målt på Laguneparken:
//
//     teoretisk brutto − faktisk brutto = synlig + usynlig
//     2 680 962 − 2 102 133 = 578 828 = 426 681 + 152 148
//
// Tallene under er de virkelige.
// =====================================================================
describe('usynligstatus', () => {
  const kast = kart({ '2026-01': 200000, '2026-02': 226681 })
  const usynlig = kart({ '2026-01': 100000, '2026-02': 52148 })

  it('legger sammen til hele svinnet', () => {
    const u = usynligstatus(usynlig, kast)!
    expect(Math.round(u.kastAvlagtKr)).toBe(426681)
    expect(Math.round(u.usynligKr)).toBe(152148)
    expect(Math.round(u.totaltKr)).toBe(578829)
    expect(u.maaneder).toBe(2)
  })

  // PERIODENE MÅ VÆRE LIKE. Kast har to kilder, usynlig har én — så en
  // åpen måned har kast og ikke usynlig. Summeres de likevel, dekker de
  // to halvdelene ulike perioder og totalen blir for lav uten at noe
  // synes.
  it('KANARIFUGL: en måned uten usynlig teller ikke med', () => {
    const medAapen = kart({ '2026-01': 200000, '2026-02': 226681, '2026-03': 40000 })
    const u = usynligstatus(usynlig, medAapen)!
    expect(u.maaneder).toBe(2)
    expect(Math.round(u.kastAvlagtKr)).toBe(426681)
    // 40 000 fra den åpne måneden skal IKKE være med i totalen.
    expect(Math.round(u.totaltKr)).toBe(578829)
  })

  it('og en måned uten kast teller heller ikke', () => {
    const u = usynligstatus(kart({ '2026-05': 9000 }), kart({ '2026-01': 100 }))
    expect(u).toBeNull()
  })

  // FORTEGNET ER IKKE PYNT: + er manko, − er overskudd. En telling kan
  // finne mer enn forventet, og da skal summen gå NED. Tas absoluttverdi
  // et sted, blir et overskudd lest som et tap.
  it('KANARIFUGL: overskudd trekker fra, det legges ikke til', () => {
    const u = usynligstatus(kart({ '2026-01': -30000 }), kart({ '2026-01': 100000 }))!
    expect(u.usynligKr).toBe(-30000)
    expect(u.totaltKr).toBe(70000)
  })

  it('sier fra når ingen måned er avlagt', () => {
    expect(usynligstatus(new Map(), new Map())).toBeNull()
  })

  // GRENSEN KOMMER FRA BP-EN, IKKE FRA DELINGSFILA.
  //
  // St1 setter ingen grense for usynlig svinn. De setter en BRUTTO, og
  // da foelger svinnbudsjettet av identiteten:
  //
  //     tillatt svinn = teoretisk brutto - brutto budsjettert i BP
  //
  // Kast og usynlig deler den grensen. De spiser av samme brutto, og en
  // krone tapt i manko koster like mye som en krone kastet.
  it('regner tillatt svinn av BP-bruttoen', () => {
    const u = usynligstatus(usynlig, kast, {
      teoretiskPerMaaned: kart({ '2026-01': 700000, '2026-02': 700000 }),
      bpBruttoPerMaaned: kart({ '2026-01': 300000, '2026-02': 300000 }),
    })!
    expect(u.teoretiskBruttoKr).toBe(1400000)
    expect(u.bpBruttoKr).toBe(600000)
    expect(u.tillattSvinnKr).toBe(800000)
    // 578 829 av 800 000 - innenfor, med god margin.
    expect(Math.round(u.avvikMotBpKr!)).toBe(578829 - 800000)
  })

  it('sier fra naar svinnet spiser mer enn BP-en taaler', () => {
    const u = usynligstatus(usynlig, kast, {
      teoretiskPerMaaned: kart({ '2026-01': 300000, '2026-02': 300000 }),
      bpBruttoPerMaaned: kart({ '2026-01': 100000, '2026-02': 100000 }),
    })!
    expect(u.tillattSvinnKr).toBe(400000)
    expect(Math.round(u.avvikMotBpKr!)).toBe(178829)
  })

  // KANARIFUGL: BP-siden maa dekke de SAMME maanedene. Mangler én,
  // sammenlignes to perioder - samme feil som en avkortet nevner, bare
  // paa den andre siden av broeken.
  it('KANARIFUGL: holder BP-tallene tilbake naar en maaned mangler', () => {
    const u = usynligstatus(usynlig, kast, {
      teoretiskPerMaaned: kart({ '2026-01': 700000 }),
      bpBruttoPerMaaned: kart({ '2026-01': 300000 }),
    })!
    expect(u.tillattSvinnKr).toBeNull()
    expect(u.avvikMotBpKr).toBeNull()
    // Svinnet selv staar fortsatt - det er grensen som mangler.
    expect(Math.round(u.totaltKr)).toBe(578829)
  })

  it('staar uten grense naar BP ikke er sendt inn', () => {
    const u = usynligstatus(usynlig, kast)!
    expect(u.tillattSvinnKr).toBeNull()
    expect(u.bpBruttoKr).toBeNull()
  })
})

describe('svinnbilde — usynlig kobles på', () => {
  const grunn = {
    budsjett: [BONES],
    kastRegnskap: new Map([['120', kart({ '2026-01': 164734 })]]),
    kastDaglig: new Map([['120', kart({ '2026-02': 6146 })]]),
    salg: new Map([['120', kart({ '2026-01': 900000, '2026-02': 320436 })]]),
  }

  it('er null når ingen usynligdata er sendt inn', () => {
    expect(svinnbilde(grunn).usynlig).toBeNull()
  })

  it('regner hele svinnet av de avlagte månedene', () => {
    const ut = svinnbilde({
      ...grunn,
      usynligPerMaaned: kart({ '2026-01': 40000 }),

    })
    expect(ut.usynlig!.maaneder).toBe(1)
    expect(Math.round(ut.usynlig!.kastAvlagtKr)).toBe(164734)
    expect(Math.round(ut.usynlig!.totaltKr)).toBe(204734)
    // Kastet totalt er større enn kastet i avlagte måneder — den åpne
    // måneden er med der og ikke her, og det er hele poenget.
    expect(Math.round(ut.total!.kastHittilKr)).toBe(170880)
  })
})

// =====================================================================
// KANARIFUGL FOR AVDELINGSAVGRENSNINGEN
//
// `hent-budsjett.ts` avgrenser ALT til avdelingen budsjettet gjelder før
// vareområdet brukes. Den avgrensningen ser overflødig ut — budsjettet
// er jo MAT — og er det ikke.
//
// Testen under er grunnen. Faller den, er noen i ferd med å ta den bort.
// =====================================================================
describe('vareomradeAv er IKKE entydig alene', () => {
  // Målt i produksjon 2026-09-05: elleve koder ender på `10`.
  const ENDER_PAA_10 = [
    '12010', '13010', '14010', '16010', '17010',
    '18010', '19010', '20010', '21010', '24010', '25010',
  ]

  it('elleve ulike varegrupper gir samme vareområdekode', () => {
    expect(new Set(ENDER_PAA_10.map(vareomradeAv))).toEqual(new Set(['10']))
  })

  // BAKERI er 12010. Uten avdelingsleddet ville kaffe, brus, sjokolade,
  // tobakk, aviser og pant blitt lagt til bakeriets kast — og tallet sett
  // ut som et bakeriproblem.
  it('men avdelingen skiller dem', () => {
    expect(new Set(ENDER_PAA_10.map(avdelingAv)).size).toBe(ENDER_PAA_10.length)
    expect(avdelingAv('12010')).toBe('120')
    expect(avdelingAv('13010')).toBe('130')
  })

  it('paret avdeling + vareområde er entydig', () => {
    const par = ENDER_PAA_10.map((k) => `${avdelingAv(k)}/${vareomradeAv(k)}`)
    expect(new Set(par).size).toBe(par.length)
  })
})
