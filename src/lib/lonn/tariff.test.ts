import { describe, expect, test } from 'vitest'
import {
  plasserSats, vurderSats, TIMER_PER_UKE, TARIFF_2025_07,
  omregnet, LEDENDE_TILLEGG, TRINN_BAND, type Skiftordning, vurderSkiftordning } from './tariff'

describe('tariffsatser', () => {
  test('fire uketimetall, ikke to (§ 2.7.1.1)', () => {
    // 36,5 og 33,5 manglet helt. En ansatt paa en av dem fikk baade feil
    // sammenligningssats og feil ukegrense for overtid.
    expect(TIMER_PER_UKE).toEqual({
      ordinaer: 37.5, skift_36_5: 36.5, to_skift: 35.5, skift_33_5: 33.5,
    })
  })

  test('satsene fra Bønes mai 2026 plasseres i tariffen', () => {
    // Sju av ti ansatte traff eksakt da vi sjekket mot lønnseksporten.
    const fasit: [number, string, number, string][] = [
      [255.18, 'II_butikk', 6, 'to_skift'],   // Lars
      [205.53, 'II_butikk', 4, 'to_skift'],   // Maj-Linn
      [202.36, 'II_butikk', 3, 'to_skift'],   // Olaf
      [199.19, 'II_butikk', 2, 'to_skift'],   // Lena
      [185.58, 'II_butikk', 0, 'ordinaer'],   // Olav og Marius
    ]
    for (const [sats, gruppe, ans, skift] of fasit) {
      const t = plasserSats(sats)
      expect(t.some((x) => x.gruppe === gruppe && x.ansiennitet === ans && x.skift === skift),
        String(sats)).toBe(true)
    }
  })

  test('196,02 treffer to trinn — men de meldes som ett baand', () => {
    // Avtalen har ingen 1-aarssats; opprykket gaar 0 -> 2 aar (§ 19.2).
    // Trinnene beholdes fordi begge satsene finnes i loenn, men systemet
    // skal ikke lenger paastaa en ansiennitet avtalen ikke kjenner.
    const t = plasserSats(196.02)
    expect(t).toHaveLength(2)
    expect(t.map((x) => x.ansiennitet).sort()).toEqual([0, 1])
    expect(TRINN_BAND[0]).toBe(TRINN_BAND[1])
    expect(vurderSats(196.02).melding).toMatch(/0–1 år/)
    expect(vurderSats(196.02).melding).not.toMatch(/ansiennitet 1/)
  })

  test('KANARIFUGL: 2-aarstrinnet er sitt EGET baand', () => {
    // Uten denne kunne TRINN_BAND settes til samme streng overalt, og
    // testen over ville fortsatt vaert groenn - mens meldingen sluttet aa
    // si noe som helst om ansiennitet.
    expect(TRINN_BAND[2]).not.toBe(TRINN_BAND[0])
    expect(vurderSats(199.19).melding).toMatch(/2 år/)
  })
})

describe('ledende personell er et GULV, ikke en egen skala (§ 19.2)', () => {
  const butikk = TARIFF_2025_07.satser.II_butikk
  const ledende = TARIFF_2025_07.satser.I_ledende

  test('hvert trinn ligger noeyaktig kr 5 over butikkpersonell', () => {
    // «Ledende personell skal ligge minst kr 5,- over minstelønnssatsene.»
    // Avskriften hadde 190,52 der regelen gir 190,57 - UNDER gulvet. En
    // sats under minstelønn meldt som «paa tariff» er den feilen ingen ser
    // foer den ansatte gjoer det selv.
    for (const [ans, t] of Object.entries(butikk)) {
      expect(ledende[Number(ans)], `trinn ${ans} mangler`).toBeDefined()
      expect(ledende[Number(ans)].ordinaer, `trinn ${ans}`)
        .toBeCloseTo(t.ordinaer + LEDENDE_TILLEGG, 2)
    }
  })

  test('KANARIFUGL: skiftkolonnen er LEST, ikke regnet ut', () => {
    // DETTE ER FEILEN SOM FAKTISK SKJEDDE. Foerste utgave avledet gruppe I
    // helt: butikk + kr 5, og skiftkolonnen omregnet med x 37,5/35,5.
    // Ordinaerkolonnen ble riktig paa alle sju trinn. Skiftkolonnen laa
    // ett oere for hoeyt paa trinn 0, 3 og 6.
    //
    // Grunnen staar i arket: det har BEGGE ordinaervariantene (185,58 paa
    // trinn 0, 185,57 paa trinn 1), og skiftkolonnen er regnet fra
    // `.57`-varianten — derfor er den lik for de to trinnene. En formel
    // som starter fra `.58` gir ett oere mer.
    //
    // Tallene her er skrevet av fra «Tariffoppgjoer 2025». Endres de,
    // skal noen ha arket i haanden.
    const fasit: Record<number, number> = {
      0: 201.31, 1: 201.31, 2: 204.48, 3: 207.64, 4: 210.81, 5: 217.15, 6: 260.46,
    }
    for (const [ans, kr] of Object.entries(fasit)) {
      expect(ledende[Number(ans)].to_skift, `ledende trinn ${ans}`).toBe(kr)
    }
    // Og beviset paa at den IKKE kan avledes: tre av dem ville faatt ett
    // oere for mye. Slutter det aa vaere sant, er arket endret.
    const avvikere = Object.keys(fasit)
      .filter((a) => omregnet(ledende[Number(a)].ordinaer, 'to_skift') !== fasit[Number(a)])
    expect(avvikere.sort(), 'avledningen stemmer plutselig - er arket byttet?')
      .toEqual(['0', '3', '6'])
  })

  test('KANARIFUGL: butikkens skiftkolonne lar seg heller ikke regne ut', () => {
    // Samme form, samme tre trinn. Uten denne kunne noen «rydde opp» ved
    // aa avlede hele tabellen, og tallene ville flyttet seg ett oere paa
    // satser folk faktisk faar utbetalt.
    const b = TARIFF_2025_07.satser.II_butikk
    expect(b[0].to_skift).toBe(196.02)
    expect(omregnet(b[0].ordinaer, 'to_skift')).not.toBe(b[0].to_skift)
    expect(b[6].to_skift).toBe(255.18)
    expect(b[1].to_skift, 'trinn 0 og 1 deler skiftsats i arket').toBe(b[0].to_skift)
  })

  test('KANARIFUGL: ingen ledende sats ligger under gulvet', () => {
    // Regelen er «minst». Faller en verdi under, er den ulovlig - og det
    // er nettopp det 190,52 var.
    for (const [ans, t] of Object.entries(ledende)) {
      const gulv = butikk[Number(ans)].ordinaer + LEDENDE_TILLEGG
      expect(t.ordinaer, `trinn ${ans} er under gulvet`).toBeGreaterThanOrEqual(gulv - 0.005)
    }
    expect(plasserSats(190.52), '190,52 skal ikke lenger finnes').toEqual([])
  })

  test('alle seks trinn finnes, ikke bare to', () => {
    // Avskriften hadde trinn 0 og 1. De fire oevrige ga «ukjent», og da
    // skjedde det ingen kontroll i det hele tatt for de ansatte.
    expect(Object.keys(ledende).sort()).toEqual(Object.keys(butikk).sort())
    expect(Object.keys(ledende).length).toBeGreaterThanOrEqual(6)
  })
})

describe('omregning til kortere uke (§ 2.7.1.1)', () => {
  test('grunnloenn x 37,5 / uketimetall', () => {
    expect(omregnet(185.57, 'to_skift')).toBe(196.02)
    expect(omregnet(185.57, 'ordinaer')).toBe(185.57)
  })

  test('kortere uke gir hoeyere timesats, aldri lavere', () => {
    // Den som gaar kortere uke skal ikke tjene mindre for det.
    const rekke: Skiftordning[] = ['ordinaer', 'skift_36_5', 'to_skift', 'skift_33_5']
    const satser = rekke.map((o) => omregnet(200, o))
    for (let i = 1; i < satser.length; i++) {
      expect(satser[i], rekke[i]).toBeGreaterThan(satser[i - 1])
    }
  })

  test('de to nye kolonnene er regnet, ikke funnet paa', () => {
    for (const t of Object.values(TARIFF_2025_07.satser.II_butikk)) {
      expect(t.skift_36_5).toBe(omregnet(t.ordinaer, 'skift_36_5'))
      expect(t.skift_33_5).toBe(omregnet(t.ordinaer, 'skift_33_5'))
    }
  })

  test('KANARIFUGL: de LESTE kolonnene er urort', () => {
    // `ordinaer` og `to_skift` sto i tariffoversikten og treffer ekte
    // loenn. Blir de avledet, endres tall noen faktisk faar utbetalt -
    // og tre av dem ville flyttet seg ett oere.
    const b = TARIFF_2025_07.satser.II_butikk
    expect(b[0].ordinaer).toBe(185.58)
    expect(b[6].ordinaer).toBe(241.58)
    expect(b[0].to_skift).toBe(196.02)
    expect(b[6].to_skift).toBe(255.18)
  })
})

describe('vurderSats', () => {
  test('en tariffsats gjenkjennes og forklares', () => {
    const v = vurderSats(255.18)
    expect(v.status).toBe('tariff')
    expect(v.melding).toMatch(/Butikkpersonell/)
    expect(v.melding).toMatch(/to skift/)
  })

  test('170,14 flagges — under minstelønn for voksne', () => {
    // Helene på Bønes. 15,44 under laveste voksensats, men over
    // ungdomssatsen. Enten feil alder eller en sats som aldri ble justert.
    const v = vurderSats(170.14)
    expect(v.status).toBe('under')
    expect(v.melding).toMatch(/Sjekk alder/)
  })

  test('239,33 og 234,05 flagges som mellom trinn', () => {
    for (const s of [239.33, 234.05]) {
      expect(vurderSats(s).status, String(s)).toBe('mellom')
    }
  })

  test('en sats over høyeste trinn er en lokal avtale, ikke en feil', () => {
    expect(vurderSats(300).status).toBe('over')
  })

  test('ungdomssatsen er ikke under minstelønn', () => {
    expect(vurderSats(143.33).status).toBe('tariff')
    expect(vurderSats(151.41).status).toBe('tariff')
  })

  test('boka bærer sin egen gyldighetsdato', () => {
    // Et oppgjør i august med virkning fra 1. april betyr at avsluttede
    // perioder må kunne regnes om. Da må satsene være datert.
    expect(TARIFF_2025_07.gyldigFra).toBe('2025-07-01')
  })
})

// =====================================================================
// SATSEN ROEPER ORDNINGEN
//
// «Nesten alle jobber to skift utenom butikksjefer» (Robert 2026-09-02).
// Staar feltet tomt, blir ukegrensen for overtid 37,5 i stedet for 35,5,
// og detektoren UNDER-rapporterer - den retningen antakelsen aldri
// skulle ta.
// =====================================================================
describe('vurderSkiftordning', () => {
  test('KANARIFUGL: ingen sats finnes i BEGGE kolonnene', () => {
    // Hele sjekken hviler paa dette. Fantes en sats i begge, ville den
    // paastaatt en ordning den ikke kan vite - og en 4-oeres avstand er
    // det som gjoer `plasserSats` sin 0,005-toleranse trygg.
    const alle = Object.values(TARIFF_2025_07.satser).flatMap((g) => Object.values(g))
    const ord = new Set(alle.map((t) => t.ordinaer))
    const skift = new Set(alle.map((t) => t.to_skift))
    expect([...ord].filter((x) => skift.has(x)), 'en sats finnes i begge kolonner').toEqual([])
    const naermest = Math.min(...[...ord].flatMap((a) => [...skift].map((b) => Math.abs(a - b))))
    expect(naermest, 'kolonnene ligger for taett til aa skilles').toBeGreaterThan(0.01)
  })

  test('skiftsats uten registrert ordning sier fra', () => {
    // 196,02 er butikkpersonells to-skift-sats.
    const a = vurderSkiftordning(196.02, null)
    expect(a?.slag).toBe('ikke_satt')
    expect(a?.antydet).toBe('to_skift')
    expect(a?.melding).toContain('ordinær')
  })

  test('skiftsats mot registrert ordinaer er en motsigelse', () => {
    const a = vurderSkiftordning(196.02, 'ordinaer')
    expect(a?.slag).toBe('motsier')
    expect(a?.melding).toMatch(/Én av dem er feil/)
  })

  test('den andre veien ogsaa', () => {
    // 185,58 er ordinaersatsen. Staar den ansatte som to skift, er noe galt.
    const a = vurderSkiftordning(185.58, 'to_skift')
    expect(a?.slag).toBe('motsier')
    expect(a?.antydet).toBe('ordinaer')
  })

  test('stemmer satsen med feltet, er det ingenting aa si', () => {
    expect(vurderSkiftordning(196.02, 'to_skift')).toBeNull()
    expect(vurderSkiftordning(185.58, 'ordinaer')).toBeNull()
  })

  test('en sats som finnes i BEGGE kolonnene gir ingen paastand', () => {
    // Kan ikke skje med dagens ark - derfor en syntetisk bok. Uten den
    // ville vakten vaert uproevbar: aa fjerne regelen endrer ingenting
    // saa lenge kolonnene ikke kolliderer, og da maaler testen bare
    // forutsetningen i stedet for regelen.
    //
    // Et fremtidig oppgjoer KAN gi en kollisjon. Da skal sjekken tie, ikke
    // gjette hvilken kolonne den ansatte hoerer til.
    const tvetydig: typeof TARIFF_2025_07 = {
      gyldigFra: '2099-01-01',
      satser: {
        II_butikk: {
          0: { ordinaer: 200, to_skift: 211.87, skift_36_5: 205, skift_33_5: 224 },
          1: { ordinaer: 190, to_skift: 200, skift_36_5: 195, skift_33_5: 213 },
        },
        I_ledende: {},
        IV_under18: {},
      },
    }
    // 200 er ordinaer paa trinn 0 og to_skift paa trinn 1.
    expect(vurderSkiftordning(200, null, tvetydig)).toBeNull()
    // Kontroll: en entydig sats i samme bok svarer fortsatt.
    expect(vurderSkiftordning(211.87, null, tvetydig)?.antydet).toBe('to_skift')
  })

  test('KANARIFUGL: en sats uten tarifftreff paastaar ingenting', () => {
    // En lokal avtale eller en sats som aldri ble justert. Sjekken skal
    // tie, ikke gjette - ellers ville hver eneste ansatt utenfor tabellen
    // faatt en paastand om arbeidstid.
    expect(vurderSkiftordning(210.00, null)).toBeNull()
    expect(vurderSkiftordning(0, null)).toBeNull()
  })

  test('ledende personells skiftsats gjenkjennes ogsaa', () => {
    // 201,31 er gruppe I, trinn 0 og 1.
    const a = vurderSkiftordning(201.31, null)
    expect(a?.antydet).toBe('to_skift')
  })

  test('de nye 36,5- og 33,5-ordningene forveksles ikke med to skift', () => {
    // De er regnet ut (0164), ikke lest av arket - men de skal fortsatt
    // peke paa sin EGEN ordning naar de treffer.
    const t = TARIFF_2025_07.satser.II_butikk[2]
    expect(vurderSkiftordning(t.skift_33_5, null)?.antydet).toBe('skift_33_5')
    expect(vurderSkiftordning(t.skift_36_5, null)?.antydet).toBe('skift_36_5')
  })
})
