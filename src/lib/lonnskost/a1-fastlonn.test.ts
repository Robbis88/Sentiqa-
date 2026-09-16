import { describe, expect, it } from 'vitest'
import { a1ForStasjonsmaaned } from './a1'
import { fastlonnUtenRegister } from './prisbarhet'
import type { Arbeidsrad, Arbeidstidsmaaned } from './arbeidstid'
import type { Kilder, Registerrad } from './kilder'
import type { Avtaleoppslag, Avtalerad } from './prisbarhet'

// =====================================================================
// FASTLØNN UTEN REGISTERRAD — 12 NEGATIVE VAKTER + DEN POSITIVE VEIEN
//
// Porten finnes fordi Stig er butikksjef på Bønes: han stempler 10
// vakter og 4 080 minutter i august, men står ikke i easy@work-
// eksporten, som bare bærer timelønnede. Uten denne veien blir timene
// hans `upriset('ukjent_nummer')`, og skjermen påstår at 503 er høyere
// enn den er. Timene hører til konto 501.
//
// DE FIRE FØRSTE VAKTENE HANDLER OM REKKEFØLGE, IKKE OM FASTLØNN.
// Motorløkka er: dublett -> ubetalt -> flere_lokasjoner -> avvist_rad
// -> identitet -> (ukoblet? fastlønn) -> motstrid -> prisbarhet.
// Fastlønnsoppslaget står altså BAK alle fire konfliktene og INNE i
// `ukoblet`-grenen. Flytter noen det opp i løkka, blir disse røde.
// =====================================================================

const BONES = 'sss-bones'
const LONE = 'sss-lone'
const MND = '2026-08'

const INGEN: Avtaleoppslag = () => null

/** Avtale som svarer BARE for den ene stasjonen og det ene nummeret. */
const avtaleFor = (
  stasjonId: string, ansattNr: string, rad: Avtalerad,
): Avtaleoppslag => (s, n) => (s === stasjonId && n === ansattNr ? rad : null)

const FAST: Avtalerad = { lonnsform: 'fastlonn', sistSatt: '2026-09-16' }
const TIME: Avtalerad = { lonnsform: 'timelonn', sistSatt: '2026-09-16' }
const UAVKLART: Avtalerad = { lonnsform: null, sistSatt: '2026-09-16' }

const rad = (o: Partial<Arbeidsrad> = {}): Arbeidsrad => ({
  stasjonId: BONES, kildeMaaned: MND, lokasjon: 'St1 - Bønes',
  ansattNr: '1009', ansattNavn: 'Lars Neteland', dato: '2026-08-03',
  fraDato: '2026-08-03', fraTid: '07:00', tilTid: '15:00',
  minutter: 480, lengdeTimer: 8,
  betalt: true, avvikGrunn: null, importJobbId: null, ...o,
})

const reg = (o: Partial<Registerrad> = {}): Registerrad => ({
  stasjonId: BONES, ansattNr: '1009', navn: 'Lars Neteland',
  timesats: 210, betalingsfrekvens: 'time', ...o,
})

const arbeidstid = (rader: Arbeidsrad[]): Arbeidstidsmaaned => {
  const b = rader.filter((r) => r.betalt)
  return {
    maaned: MND, rader,
    prisbareMinutter: b.filter((r) => !r.avvikGrunn).reduce((s, r) => s + r.minutter, 0),
    avvisteMinutter: b.filter((r) => r.avvikGrunn).reduce((s, r) => s + r.minutter, 0),
    betalteMinutter: b.reduce((s, r) => s + r.minutter, 0),
    personer: [...new Set(b.map((r) => r.ansattNr))].sort(),
  }
}

const kilder = (
  rader: Arbeidsrad[], egne: Registerrad[], kryss: Registerrad[] = [],
): Kilder => ({
  status: 'begge', stasjonId: BONES, maaned: MND,
  arbeidstid: arbeidstid(rader),
  register: { maaned: MND, egne, kryss, uslaatteNumre: [] },
})

/** Stig: ukoblet, 10 vakter, 4 080 minutter — som i produksjon. */
const stigsVakter = (): Arbeidsrad[] => {
  const dager: [string, number][] = [
    ['10', 480], ['11', 480], ['12', 240], ['17', 480], ['18', 480],
    ['19', 240], ['24', 480], ['25', 480], ['26', 240], ['31', 480],
  ]
  return dager.map(([d, min]) => rad({
    ansattNr: '1004', ansattNavn: 'Stig E.E Litlehamar',
    dato: `2026-08-${d}`, fraDato: `2026-08-${d}`,
    fraTid: min === 480 ? '08:00' : '12:00', tilTid: '16:00', minutter: min,
  }))
}

const kjor = (k: Kilder, a: Avtaleoppslag) => a1ForStasjonsmaaned(k, a)

// =====================================================================
// DEN POSITIVE VEIEN
// =====================================================================

describe('fastlønn uten registerrad — den nye veien', () => {
  it('1004 med eksplisitt fastlønn på Bønes blir FORKLART', () => {
    const r = kjor(
      kilder([rad(), ...stigsVakter()], [reg()]),
      avtaleFor(BONES, '1004', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')

    expect(r.status).toBe('komplett')
    expect(r.forklarteMinutter).toBe(4080)
    expect(r.uprisedeMinutter).toBe(0)

    const stigs = r.rader.filter((v) => v.rad.ansattNr === '1004')
    expect(stigs).toHaveLength(10)
    for (const v of stigs) {
      expect(v.utfall.slag).toBe('forklart')
      expect(v.utfall.slag === 'forklart' && v.utfall.grunn).toBe('fastlonn_uten_register')
    }
  })

  it('proveniensen følger med, uten easyObservasjon', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), avtaleFor(BONES, '1004', FAST))
    if (r.status === 'kildemangel') throw new Error('feil')
    const u = r.rader[0].utfall
    if (u.slag !== 'forklart') throw new Error('feil')
    const p = u.prisbarhet
    if (p.status !== 'fastlonn_uten_register') throw new Error('feil')

    expect(p.proveniens).toBe('ansatt_avtale')
    expect(p.arbeidsstasjonId).toBe(BONES)
    expect(p.sistSatt).toBe('2026-09-16')
    // Satt 16. september, anvendt paa august: bakover.
    expect(p.anvendtBakover).toBe(true)
    expect(Object.keys(p)).not.toContain('easyObservasjon')
  })

  it('anvendtBakover er false når avtalen sto FØR månedens utgang', () => {
    const f = fastlonnUtenRegister(
      BONES, '1004', MND,
      avtaleFor(BONES, '1004', { lonnsform: 'fastlonn', sistSatt: '2026-07-01' }),
    )
    expect(f?.anvendtBakover).toBe(false)
  })

  it('bevaringen holder: priset + forklart + upriset = betalt', () => {
    const r = kjor(
      kilder([rad(), ...stigsVakter()], [reg()]),
      avtaleFor(BONES, '1004', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.prisedeMinutter + r.forklarteMinutter + r.uprisedeMinutter)
      .toBe(r.betalteMinutter)
  })
})

// =====================================================================
// VAKT 1-8: DE OPPRINNELIG LÅSTE
// =====================================================================

describe('negative vakter — fastlønn skal ikke smitte', () => {
  it('1 · 1004 UTEN avtale er fortsatt upriset(ukjent_nummer)', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), INGEN)
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.status).toBe('minimum')
    expect(r.uprisedeMinutter).toBe(4080)
    expect(r.forklarteMinutter).toBe(0)
    expect(r.rader[0].utfall.slag === 'upriset'
      && r.rader[0].utfall.grunn).toBe('ukjent_nummer')
  })

  it('2 · 1004 med TIMELONN-avtale blir ikke fastlønn', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), avtaleFor(BONES, '1004', TIME))
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.forklarteMinutter).toBe(0)
    expect(r.uprisedeMinutter).toBe(4080)
  })

  it('3 · UAVKLART lønnsform er ikke fastlønn', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), avtaleFor(BONES, '1004', UAVKLART))
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.uprisedeMinutter).toBe(4080)
  })

  it('4 · fastlønn på en ANNEN arbeidsstasjon treffer ikke', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), avtaleFor(LONE, '1004', FAST))
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.uprisedeMinutter).toBe(4080)
    expect(r.forklarteMinutter).toBe(0)
  })

  it('5 · innlånt (kryssregister) går ALDRI den nye veien', () => {
    // Carmen arbeider paa Boenes, registerraden ligger paa Lone. Selv
    // MED en fastlonnsavtale paa Boenes skal hun prises gjennom
    // kryssoppslaget - hun er koblet, og naar aldri ukoblet-grenen.
    const r = kjor(
      kilder(
        [rad({ ansattNr: '1104265', ansattNavn: 'Carmen Valentina Toro', minutter: 360 })],
        [reg()],
        [reg({ stasjonId: LONE, ansattNr: '1104265', navn: 'Carmen Valentina Toro', timesats: 138 })],
      ),
      avtaleFor(BONES, '1104265', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.rader[0].utfall.slag).toBe('priset')
    expect(r.forklarteMinutter).toBe(0)
    expect(r.innlaantKr).toBeGreaterThan(0)
  })

  it('6 · koblet fastlønn går fortsatt B2b-veien, ikke den nye', () => {
    const r = kjor(
      kilder([rad({ ansattNr: '118', ansattNavn: 'Sandra' })],
        [reg({ ansattNr: '118', navn: 'Sandra', timesats: 285 })]),
      avtaleFor(BONES, '118', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    const u = r.rader[0].utfall
    expect(u.slag).toBe('forklart')
    // DEN STERKERE varianten, med Easys egen observasjon bevart.
    expect(u.slag === 'forklart' && u.grunn).toBe('fastlonn_klassifisert')
    if (u.slag !== 'forklart' || u.prisbarhet.status !== 'fastlonn_klassifisert') {
      throw new Error('feil variant')
    }
    expect(u.prisbarhet.easyObservasjon).toEqual({ betalingsfrekvens: 'time', timesats: 285 })
  })

  it('7 · fastlonn_uten_register kan strukturelt ikke bære kroner', () => {
    const r = kjor(kilder(stigsVakter(), [reg()]), avtaleFor(BONES, '1004', FAST))
    if (r.status === 'kildemangel') throw new Error('feil')
    for (const v of r.rader) {
      if (v.utfall.slag !== 'forklart') continue
      expect(Object.keys(v.utfall)).not.toContain('belopKr')
      expect(Object.keys(v.utfall.prisbarhet)).not.toContain('belopKr')
      expect(Object.keys(v.utfall.prisbarhet)).not.toContain('timesats')
    }
    // Ingen kroner kom fra dem: bare den ene prisede raden finnes ikke her.
    expect(r.status === 'komplett' ? r.konto503Kr : -1).toBe(0)
  })

  it('8 · ingen navnebasert kobling introduseres', () => {
    // SAMME NAVN, annet nummer. Finner veien personen paa navn, blir
    // denne groenn feilaktig.
    const r = kjor(
      kilder(
        [rad({ ansattNr: '9999', ansattNavn: 'Stig E.E Litlehamar', minutter: 480 })],
        [reg()],
      ),
      avtaleFor(BONES, '1004', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.forklarteMinutter).toBe(0)
    expect(r.uprisedeMinutter).toBe(480)
  })
})

// =====================================================================
// VAKT 9-12: STERKERE KONFLIKTER VINNER
//
// Alle fire står FORAN fastlønnsoppslaget i motorløkka. Testene beviser
// plasseringen, ikke bare oppførselen.
// =====================================================================

describe('negative vakter — en avtale reparerer ingen sterkere konflikt', () => {
  it('9 · MOTSTRID overlever en fastlønnsavtale', () => {
    // Nummeret FINNES i registeret, men med et annet navn. Identiteten
    // blir `motstrid`, ikke `ukoblet` - og motstrid behandles etter
    // ukoblet-grenen, saa avtalen naas aldri.
    const r = kjor(
      kilder(
        [rad({ ansattNr: '1018', ansattNavn: 'Andre Fjørstad', minutter: 480 })],
        [reg({ ansattNr: '1018', navn: 'Marietta Iacovou' })],
      ),
      avtaleFor(BONES, '1018', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    const u = r.rader[0].utfall
    expect(u.slag).toBe('upriset')
    expect(u.slag === 'upriset' && u.grunn).toBe('motstrid_navn')
    expect(r.forklarteMinutter).toBe(0)
  })

  it('10 · AVVIST_RAD overlever en fastlønnsavtale', () => {
    const r = kjor(
      kilder(stigsVakter().map((v) => ({ ...v, avvikGrunn: 'lengde' as const })), [reg()]),
      avtaleFor(BONES, '1004', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.rader[0].utfall.slag === 'upriset'
      && r.rader[0].utfall.grunn).toBe('avvist_rad')
    expect(r.forklarteMinutter).toBe(0)
  })

  it('11 · DUBLETT overlever en fastlønnsavtale', () => {
    const v = stigsVakter()[0]
    const r = kjor(kilder([v, { ...v }], [reg()]), avtaleFor(BONES, '1004', FAST))
    if (r.status === 'kildemangel') throw new Error('feil')
    expect(r.dubletter).toBe(1)
    // Foerste rad forklares, KOPIEN forblir dublett.
    expect(r.rader[1].utfall.slag === 'upriset'
      && r.rader[1].utfall.grunn).toBe('dublett')
  })

  it('12 · FLERE_LOKASJONER overlever en fastlønnsavtale', () => {
    const r = kjor(
      kilder(
        [rad({ ansattNr: '1004', ansattNavn: 'Stig E.E Litlehamar', lokasjon: 'St1 - Bønes' }),
          rad({
            ansattNr: '1004', ansattNavn: 'Stig E.E Litlehamar',
            lokasjon: 'St1 - Varden', dato: '2026-08-04', fraDato: '2026-08-04',
          })],
        [reg()],
      ),
      avtaleFor(BONES, '1004', FAST),
    )
    if (r.status === 'kildemangel') throw new Error('feil')
    for (const v of r.rader) {
      expect(v.utfall.slag === 'upriset' && v.utfall.grunn).toBe('flere_lokasjoner')
    }
    expect(r.forklarteMinutter).toBe(0)
  })
})

// =====================================================================
// PORTFUNKSJONEN FOR SEG
// =====================================================================

describe('fastlonnUtenRegister — porten alene', () => {
  it('svarer null når avtalen mangler', () => {
    expect(fastlonnUtenRegister(BONES, '1004', MND, INGEN)).toBeNull()
  })

  it('svarer null på timelonn og på uavklart', () => {
    expect(fastlonnUtenRegister(BONES, '1004', MND, avtaleFor(BONES, '1004', TIME))).toBeNull()
    expect(fastlonnUtenRegister(BONES, '1004', MND, avtaleFor(BONES, '1004', UAVKLART))).toBeNull()
  })

  it('kaster på ugyldig månedsform i stedet for å svare null', () => {
    expect(() => fastlonnUtenRegister(BONES, '1004', 'august', INGEN)).toThrow(/Ugyldig måned/)
  })

  it('slår opp på ARBEIDSSTASJONEN, og bare den', () => {
    const sett: [string, string][] = []
    const spion: Avtaleoppslag = (s, n) => { sett.push([s, n]); return null }
    fastlonnUtenRegister(BONES, '1004', MND, spion)
    expect(sett).toEqual([[BONES, '1004']])
  })
})
