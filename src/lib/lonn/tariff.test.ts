import { describe, expect, test } from 'vitest'
import {
  plasserSats, vurderSats, TIMER_PER_UKE, TARIFF_2025_07,
  omregnet, LEDENDE_TILLEGG, TRINN_BAND, type Skiftordning,
} from './tariff'

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
