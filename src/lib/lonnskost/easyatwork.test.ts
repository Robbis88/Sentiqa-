import { describe, expect, it } from 'vitest'
import {
  byggEasyatwork as bygg, fraLinjer, medSykelonnsforskyvning,
  medOppdagetSykelonn, sykelonnskilde, medFastlonn, SATSER,
} from './easyatwork'
import type { Lonnsartlinje } from '@/lib/parsere/lonnsart'

const byggEasyatwork = (l: Lonnsartlinje[]) => bygg(fraLinjer(l))

const L = (
  lonnsart: string, timer: number, belopKr: number, dato = '2026-08-03', tekst?: string,
): Lonnsartlinje => ({
  ansattNr: '1', ansattNavn: 'A B', dato, lonnsart,
  lonnsartTekst: tekst ?? `${lonnsart} art`, timer, belopKr, lokasjon: 'St1 - Dale',
})

describe('byggEasyatwork', () => {
  it('legger hver lønnsart på sin konto', () => {
    const [m] = byggEasyatwork([
      L('2', 10, 2000), L('12', 5, 1000), L('1429', 3, 36), L('97', 1, 200),
    ])
    // TILLEGG OG OVERTID LIGGER I 503, ikke i 502. Malt mot Dale 2026 er
    // 502 noeyaktig 500 kroner hver maaned - fast mobildekning, ikke
    // kveld og helg. De variable tilleggene foerer St1 inne i 503.
    expect(m.perKonto).toEqual({ '503': 2236, '505': 1000 })
    expect(m.kontantKr).toBe(3236)
  })

  // TILLEGGENE BÆRER DE SAMME TIMENE EN GANG TIL. Et kveldstillegg er
  // ikke en ekstra time, det er en dyrere time. Summerte vi alle artene,
  // ga Dale august 1 907,81 timer der de arbeidede var 1 264,73 — og en
  // snittsats som var 35 % for lav.
  it('teller timer bare på lønnsart 2', () => {
    const [m] = byggEasyatwork([L('2', 8, 1600), L('1429', 3, 36), L('1430', 2, 44)])
    expect(m.timer).toBe(8)
  })

  // PENSJONEN ER UTENFOR LOENNSKOSTEN, og det er ikke en detalj: den laa
  // inne til 2026-09-07 og gjorde tallet usammenlignbart med regnskapet.
  // St1 foerer OTP som 5945 under konto 590, som /lonnskost holder
  // utenfor med vilje. Malt paa Dale juli var pensjonen 7 609 der - den
  // skjulte en del av gapet ved aa blaase opp anslaget.
  it('holder pensjonen utenfor lønnskosten, men regner den ut', () => {
    const [m] = byggEasyatwork([L('2', 10, 100000)])
    expect(m.feriepengerKr).toBe(12000)
    expect(m.pensjonKr).toBe(2000)
    // 14,1 % av (100 000 + 12 000). Konti 540 og 541 er nettopp de to.
    expect(m.agaKr).toBe(15792)
    expect(m.lonnskostKr).toBe(127792)
    // Kanarifugl: legger noen pensjonen tilbake i summen, blir dette 130 074.
    expect(m.lonnskostKr).not.toBe(130074)
  })

  // FASIT FRA DEN EKTE FILA: Dale, august 2026, 400 linjer. Bare
  // aggregater — lønn per navngitt person hører ikke hjemme i et repo.
  it('treffer Dale august 2026', () => {
    const [m] = byggEasyatwork([
      L('2', 1264.73, 247137.42),
      L('12', 75, 14651.88),
      L('1429', 162.78, 18647.67, '2026-08-03', '1429 samlet tillegg og overtid'),
    ])
    expect(m.kontantKr).toBe(280436.97)
    expect(m.timer).toBe(1264.73)
    expect(m.perKonto['503']).toBe(265785.09) // timelønn + tillegg
    expect(m.perKonto['505']).toBe(14651.88)
    expect(m.perKonto['502']).toBeUndefined()
    expect(m.feriepengerKr).toBe(33652.44)
    expect(m.pensjonKr).toBe(5608.74)
    expect(m.agaKr).toBe(44286.61)
    expect(m.lonnskostKr).toBe(358376.01)
    expect(m.ukjenteArter).toEqual([])
  })

  // KANARIFUGL. Fristelsen er «alt som ikke er 2 eller 12 er tillegg» —
  // den ville lagt en fastlønnsart rett i 502 og gjort et hull til et
  // tall. Slutter kartet å rapportere ukjente, feiler denne.
  it('rapporterer en ukjent lønnsart i stedet for å bøtte den', () => {
    const [m] = byggEasyatwork([L('2', 10, 2000), L('1', 160, 52500, '2026-08-03', '1 Fastlønn')])
    expect(m.ukjenteArter).toEqual(['1 Fastlønn'])
    expect(m.kontantKr).toBe(2000)
    expect(m.perKonto['502']).toBeUndefined()
  })

  // JULI 2026, DALE - MALINGEN SOM FORKLARTE HELE GAPET.
  //
  // Timene stemmer paa 0,10 av 1 527,66 mot St1s eget noekkeltall, saa
  // eksporten mangler ingen vakt. Differansen mot regnskapet (441 172)
  // er 28 998 kroner, og den er dekomponert til siste krone:
  //
  //   sykeloenn som ikke er i eksporten   28 896   langtidssykmeldt stempler ikke
  //   fast mobildekning (502)                500   ikke en arbeidet time
  //   timeloenn+tillegg, easy@work hoeyere  -398   vakt over maanedsskiftet
  //
  // Fasiten her er kontantloenna og timene. Bommer de, er det parseren
  // eller kontokartet som har flyttet seg - ikke virkeligheten.
  it('treffer Dale juli 2026', () => {
    const [m] = byggEasyatwork([
      L('2', 1527.56, 297990.47, '2026-07-15'),
      L('12', 35.50, 5933.88, '2026-07-15'),
      L('96', 0.96, 137.28, '2026-07-15'),
      L('1429', 552.39, 11977.40, '2026-07-15', '1429 samlet tillegg'),
    ])
    expect(m.timer).toBe(1527.56)
    expect(m.kontantKr).toBe(316039.03)
    expect(m.perKonto['505']).toBe(5933.88)
    expect(m.lonnskostKr).toBeCloseTo(403872.6, 1)
  })

  it('deler på måned, nyeste først', () => {
    const m = byggEasyatwork([L('2', 1, 100, '2026-07-31'), L('2', 1, 200, '2026-08-01')])
    expect(m.map((x) => x.maaned)).toEqual(['2026-08', '2026-07'])
    expect(m[0].kontantKr).toBe(200)
  })

  it('satsene står ett sted', () => {
    expect(SATSER).toEqual({ feriepengerPst: 12, pensjonPst: 2, agaPst: 14.1 })
  })
})

// =====================================================================
// SYKELOENNA LIGGER EN MAANED ETTER
//
// Regnskapets juli, konto 505: 34 830. easy@work juni, loennsart 12:
// 34 829,52. Med den ene flyttingen faller julis avvik fra 30 086
// kroner til 373 - fra 6,8 % til 0,08 %.
// =====================================================================
describe('medSykelonnsforskyvning', () => {
  const juni = L('12', 158, 34829.52, '2026-06-15')
  const juliArbeid = [
    L('2', 1527.56, 297990.47, '2026-07-15'),
    L('1429', 552.39, 11977.40, '2026-07-15', '1429 samlet tillegg'),
    L('96', 0.96, 137.28, '2026-07-15'),
  ]

  it('henter sykelønna fra måneden før', () => {
    const [juli] = medSykelonnsforskyvning(byggEasyatwork([
      ...juliArbeid, L('12', 35.5, 5933.88, '2026-07-15'), juni,
    ]))
    expect(juli.maaned).toBe('2026-07')
    expect(juli.sykelonnFraMaaned).toBe('2026-06')
    expect(juli.perKonto['505']).toBe(34829.52)
    // Regnskapets juli: 345 037 kontant, 441 172 loennskost.
    expect(juli.kontantKr).toBeCloseTo(344934.67, 1)
    expect(juli.lonnskostKr).toBeCloseTo(440798.91, 1)
  })

  // KANARIFUGL. Slutter flyttingen aa virke, faller juli tilbake til sin
  // egen sykeloenn og avviket mot regnskapet gaar fra 373 til 30 086.
  it('bruker ikke månedens egen sykelønn', () => {
    const [juli] = medSykelonnsforskyvning(byggEasyatwork([
      ...juliArbeid, L('12', 35.5, 5933.88, '2026-07-15'), juni,
    ]))
    expect(juli.perKonto['505']).not.toBe(5933.88)
  })

  // MAANEDEN MAA FINNES, IKKE BARE VAERE NESTE RAD I LISTA. Hopper
  // eksporten over en maaned, ville posisjon gitt feil maaned - og det
  // ville sett ut som et treff.
  it('sier fra når måneden før mangler', () => {
    const [juli] = medSykelonnsforskyvning(byggEasyatwork([
      ...juliArbeid, L('12', 35.5, 5933.88, '2026-07-15'),
      L('12', 10, 2000, '2026-05-15'), // mai, ikke juni
    ]))
    expect(juli.sykelonnFraMaaned).toBeNull()
    expect(juli.perKonto['505']).toBeUndefined()
  })

  it('krysser årsskiftet', () => {
    const m = medSykelonnsforskyvning(byggEasyatwork([
      L('2', 10, 2000, '2026-01-15'),
      L('12', 5, 900, '2025-12-15'),
    ]))
    expect(m.find((x) => x.maaned === '2026-01')!.sykelonnFraMaaned).toBe('2025-12')
    expect(m.find((x) => x.maaned === '2026-01')!.perKonto['505']).toBe(900)
  })
})

// =====================================================================
// OPPDAG PERIODISERINGEN, IKKE ANTA DEN
//
// Forsinkelsen er en PRAKSIS, ikke en naturlov. Regnskapskontoret kan
// periodisere sykeloenna hvis Kelsar ber om det. Gjoer de det, ville en
// fast forskyvning flyttet den en maaned for langt - hver maaned, uten
// at noe ble roedt.
// =====================================================================
describe('sykelonnskilde', () => {
  // Juli 2026: regnskapet 34 830, egen maaned 5 934, forrige 34 829,52.
  it('kjenner igjen forsinkelsen på de ekte tallene', () => {
    expect(sykelonnskilde(34830, 5933.88, 34829.52)).toBe('forrige_maaned')
  })

  it('kjenner igjen en periodisert måned', () => {
    expect(sykelonnskilde(5933.88, 5933.88, 34829.52)).toBe('samme_maaned')
  })

  it('sier ukjent når ingen av dem treffer', () => {
    expect(sykelonnskilde(99999, 5933.88, 34829.52)).toBe('ukjent')
  })

  it('sier ukjent for en måned uten regnskap', () => {
    expect(sykelonnskilde(null, 5933.88, 34829.52)).toBe('ukjent')
  })

  it('taaler ørediffer, men ikke en faktor seks', () => {
    expect(sykelonnskilde(34830, 34829.52, 5933.88)).toBe('samme_maaned')
  })

  // EN MAANED UTEN SYKEFRAVAER BAERER INGEN INFORMASJON. Uten denne
  // regelen ville hver rolige maaned stemt for «ingen forsinkelse» av ren
  // aritmetikk - null treffer null - og trukket moensteret feil vei.
  it('gir ingen stemme når kandidatene er like', () => {
    expect(sykelonnskilde(0, 0, 0)).toBe('ukjent')
    expect(sykelonnskilde(5000, 5000, 5000)).toBe('ukjent')
  })
})

describe('medOppdagetSykelonn', () => {
  const raa = () => bygg(fraLinjer([
    L('2', 1527.56, 297990.47, '2026-07-15'),
    L('1429', 552.39, 11977.40, '2026-07-15', '1429 samlet tillegg'),
    L('96', 0.96, 137.28, '2026-07-15'),
    L('12', 35.5, 5933.88, '2026-07-15'),
    L('2', 1263.40, 262463.65, '2026-06-15'),
    L('12', 158, 34829.52, '2026-06-15'),
  ]))

  it('flytter juli når regnskapet viser forsinkelse', () => {
    const r = medOppdagetSykelonn(raa(), new Map([['2026-07', 34830]]))
    expect(r.moenster).toBe('forrige_maaned')
    expect(r.forsinkede).toBe(1)
    const juli = r.maaneder.find((m) => m.maaned === '2026-07')!
    expect(juli.sykelonnFraMaaned).toBe('2026-06')
    expect(juli.perKonto['505']).toBe(34829.52)
    expect(juli.lonnskostKr).toBeCloseTo(440798.91, 1)
  })

  // KANARIFUGLEN FOR HELE OMBYGGINGEN. Begynner Kelsar aa periodisere,
  // skal juli IKKE flyttes lenger. Med den gamle, faste forskyvningen
  // ville den blitt flyttet uansett - og tallet ville sett rimelig ut.
  it('lar juli stå når regnskapet er periodisert', () => {
    const r = medOppdagetSykelonn(raa(), new Map([['2026-07', 5933.88]]))
    expect(r.moenster).toBe('samme_maaned')
    expect(r.forsinkede).toBe(0)
    const juli = r.maaneder.find((m) => m.maaned === '2026-07')!
    expect(juli.perKonto['505']).toBe(5933.88)
    expect(juli.sykelonnFraMaaned).toBe('2026-07')
  })

  // En aapen maaned har ikke noe regnskap aa maales mot, saa den foelger
  // det de avlagte viste. Et eget svar der ville vaert en gjetning uten
  // grunnlag.
  it('lar åpne måneder arve mønsteret', () => {
    const m = bygg(fraLinjer([
      L('2', 10, 2000, '2026-08-15'),
      L('12', 5, 1000, '2026-08-15'),
      L('2', 1527.56, 297990.47, '2026-07-15'),
      L('12', 35.5, 5933.88, '2026-07-15'),
      L('12', 158, 34829.52, '2026-06-15'),
    ]))
    const r = medOppdagetSykelonn(m, new Map([['2026-07', 34830]]))
    expect(r.moenster).toBe('forrige_maaned')
    const aug = r.maaneder.find((x) => x.maaned === '2026-08')!
    expect(aug.sykelonnFraMaaned).toBe('2026-07')
    expect(aug.perKonto['505']).toBe(5933.88)
  })

  it('rører ingenting når ingenting kan måles', () => {
    const r = medOppdagetSykelonn(raa(), new Map())
    expect(r.moenster).toBe('ukjent')
    expect(r.maalte).toBe(0)
    expect(r.maaneder.find((m) => m.maaned === '2026-07')!.perKonto['505']).toBe(5933.88)
  })
})

// =====================================================================
// FASTLOENNA - DEN ENE POSTEN EASY@WORK ALDRI KAN SE
//
// En fastloennet stempler ikke for aa faa betalt. Hen dukker ikke opp
// med null i eksporten - hen dukker ikke opp i det hele tatt, og
// fravaeret er usynlig: anslaget ser ut som en komplett stasjon, bare
// billigere. Paa Boenes er lederens fastloenn 27 % av loennskosten.
// =====================================================================
describe('medFastlonn', () => {
  const maaneder = () => bygg(fraLinjer([
    L('2', 100, 20000, '2026-08-15'),
    L('2', 100, 20000, '2026-07-15'),
  ]))

  it('bruker månedens egen 501 når den er avlagt', () => {
    const [aug] = medFastlonn(maaneder(), new Map([['2026-08', 52500]]))
    expect(aug.fastlonnKr).toBe(52500)
    expect(aug.fastlonnFraMaaned).toBe('2026-08')
    expect(aug.perKonto['501']).toBe(52500)
    // Paaslagene foelger med: 72 500 x 1,12, saa 14,1 % av summen.
    expect(aug.kontantKr).toBe(72500)
    expect(aug.feriepengerKr).toBeCloseTo(8700, 2)
    expect(aug.agaKr).toBeCloseTo((72500 + 8700) * 0.141, 2)
  })

  // FASTLOENN ER FAST - det er nettopp det som gjoer den til fastloenn.
  // Da er sist kjente verdi et godt anslag for den aapne maaneden.
  it('bærer sist kjente fastlønn inn i en måned uten regnskap', () => {
    const [aug] = medFastlonn(maaneder(), new Map([['2026-07', 52500]]))
    expect(aug.maaned).toBe('2026-08')
    expect(aug.fastlonnKr).toBe(52500)
    // MAANEDEN STAAR PAA RADEN. Er den en annen enn maaneden selv, er
    // tallet en antakelse - og en antakelse som ikke sier fra er den
    // farligste sorten.
    expect(aug.fastlonnFraMaaned).toBe('2026-07')
  })

  // BAERES BARE BAKOVER I TID. Ellers ville en gammel maaned faatt dagens
  // loenn, og serien sett ut som om ingen hadde faatt loennsoekning.
  it('lar ikke en senere måned smitte bakover', () => {
    const juli = medFastlonn(maaneder(), new Map([['2026-08', 52500]]))
      .find((m) => m.maaned === '2026-07')!
    expect(juli.fastlonnKr).toBe(0)
    expect(juli.fastlonnFraMaaned).toBeNull()
  })

  // EN STASJON UTEN KONTO 501 HAR INGEN FASTLOENNEDE. Dale er en slik.
  it('rører ingenting når stasjonen ikke har fastlønn', () => {
    const foer = maaneder()
    const etter = medFastlonn(foer, new Map())
    expect(etter[0].fastlonnKr).toBe(0)
    expect(etter[0].lonnskostKr).toBe(foer[0].lonnskostKr)
    expect(etter[0].perKonto['501']).toBeUndefined()
  })
})

// =====================================================================
// OPPGITT GRUNNLOENN SLAAR BAARET, MEN ALDRI REGNSKAPET
//
// BP-en foerer kjedesnittet for fastloenn, saa den kan ikke brukes. Konto
// 501 er faktisk - men den finnes foerst naar maaneden er avlagt. I
// mellomtiden baaret `medFastlonn` sist kjente framover, og en
// loennsoekning eller en ny butikksjef gjoer at anslaget ligger etter i
// inntil halvannen maaned.
// =====================================================================
describe('medFastlonn med oppgitt grunnloenn', () => {
  const maaneder = () => bygg(fraLinjer([
    L('2', 100, 20000, '2026-09-15'),
    L('2', 100, 20000, '2026-08-15'),
  ]))

  it('bruker oppgitt grunnlønn når regnskapet mangler', () => {
    const [sep] = medFastlonn(
      maaneder(),
      new Map([['2026-08', 52500]]),
      new Map([['2026-09', 58000]]),
    )
    expect(sep.maaned).toBe('2026-09')
    expect(sep.fastlonnKr).toBe(58000)
    expect(sep.fastlonnKilde).toBe('oppgitt')
    expect(sep.fastlonnFraMaaned).toBe('2026-09')
    // Paaslagene regnes av den oppgitte grunnloenna.
    expect(sep.kontantKr).toBe(78000)
  })

  // KANARIFUGL. Slaar oppgitt regnskapet, blir en avlagt maaned
  // overstyrt av et tall ingen har avstemt - og fasiten taper for et
  // anslag.
  it('lar regnskapet vinne over det oppgitte', () => {
    const aug = medFastlonn(
      maaneder(),
      new Map([['2026-08', 52500]]),
      new Map([['2026-08', 99999]]),
    ).find((m) => m.maaned === '2026-08')!
    expect(aug.fastlonnKr).toBe(52500)
    expect(aug.fastlonnKilde).toBe('regnskap')
  })

  it('faller tilbake på båret når ingenting er oppgitt', () => {
    const [sep] = medFastlonn(maaneder(), new Map([['2026-08', 52500]]))
    expect(sep.fastlonnKr).toBe(52500)
    expect(sep.fastlonnKilde).toBe('baaret')
    expect(sep.fastlonnFraMaaned).toBe('2026-08')
  })

  it('sier ingen kilde når stasjonen ikke har fastlønn', () => {
    const [sep] = medFastlonn(maaneder(), new Map())
    expect(sep.fastlonnKr).toBe(0)
    expect(sep.fastlonnKilde).toBeNull()
  })
})
