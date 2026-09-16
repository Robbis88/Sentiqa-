import { describe, expect, it } from 'vitest'
import {
  UPRISET_GRUNN, FORKLART_GRUNN, KILDEMANGEL, FORBEHOLD_KORT,
  utfallstekst, beloepsledetekst, statusforklaring,
} from './a1-sprak'
import type { Uprisetgrunn } from './a1'

// Hver eneste tekst som kan naa en skjerm.
const ALLE_TEKSTER = [
  ...Object.values(UPRISET_GRUNN),
  ...Object.values(FORKLART_GRUNN),
  ...Object.values(KILDEMANGEL),
  FORBEHOLD_KORT,
  beloepsledetekst('minimum'), beloepsledetekst('komplett'),
  statusforklaring('minimum'), statusforklaring('komplett'),
]

describe('ingen interne navn naar skjermen', () => {
  // Kontraktsnavn er ikke norsk. En bruker skal aldri se dem, og en
  // kommentar som ber utvikleren huske det er ikke en vakt.
  const FORBUDT = [
    'Vurdertrad', 'Uprisetgrunn', 'Radutfall', 'a1_registeroppslag',
    'basisvakt', 'lonnsregister', 'ansatt_avtale', 'hentKilder',
    'beregnA1', 'MedBeggeKilder', 'registerStasjonId', 'innlaantKr',
    'kildemangel', 'mangler_register', 'mangler_arbeidstid', 'mangler_begge',
    'motstrid', 'ukoblet', 'prisbar', 'maanedslonn', 'fastlonn_klassifisert',
    'mangler_sats', 'ukjent_enhet', 'avvist_rad', 'flere_lokasjoner',
    'ukjent_nummer', 'dublett',
  ]

  it('ingen tekst inneholder et kontraktsnavn', () => {
    for (const tekst of ALLE_TEKSTER) {
      for (const ord of FORBUDT) {
        expect(tekst.toLowerCase(), `«${tekst}» inneholder «${ord}»`)
          .not.toContain(ord.toLowerCase())
      }
    }
  })

  it('ordet «komplett» vises ALDRI', () => {
    // Statusen betyr komplett FOR MODELLEN. Overtid står fortsatt
    // utenfor, så ordet ville vært sant om modellen og usant om lønna.
    for (const tekst of ALLE_TEKSTER) {
      expect(tekst.toLowerCase()).not.toContain('komplett')
    }
  })

  it('ordet «minimum» vises heller ikke — «Minst» gjør jobben', () => {
    for (const tekst of ALLE_TEKSTER) {
      expect(tekst.toLowerCase()).not.toContain('minimum')
    }
  })
})

describe('hver årsak har en tekst', () => {
  it('alle Uprisetgrunn-verdiene er dekket', () => {
    // KANARIFUGL. Legges en ny grunn til i motoren uten tekst her, blir
    // denne rød i stedet for at brukeren får se enum-verdien rå.
    const grunner: Uprisetgrunn[] = [
      'ukjent_nummer', 'motstrid_navn', 'motstrid_kollisjon', 'motstrid_bro',
      'mangler_sats', 'ukjent_enhet', 'avvist_rad', 'flere_lokasjoner', 'dublett',
    ]
    for (const g of grunner) {
      expect(UPRISET_GRUNN[g], `mangler tekst for ${g}`).toBeTruthy()
      expect(UPRISET_GRUNN[g].length).toBeGreaterThan(10)
    }
    expect(Object.keys(UPRISET_GRUNN)).toHaveLength(grunner.length)
  })

  it('1004 sin årsak er lesbar uten å kjenne koden', () => {
    expect(UPRISET_GRUNN.ukjent_nummer)
      .toBe('Finnes ikke i lønnsgrunnlaget for måneden')
  })
})

describe('forklart arbeid presenteres aldri som 0 kr', () => {
  it('månedslønn sier at timene telles', () => {
    expect(FORKLART_GRUNN.maanedslonn).toContain('telles')
    expect(FORKLART_GRUNN.maanedslonn).not.toContain('0 kr')
  })

  it('fastlønn sier at timene telles', () => {
    expect(FORKLART_GRUNN.fastlonn_klassifisert).toContain('telles')
    expect(FORKLART_GRUNN.fastlonn_klassifisert).not.toContain('0 kr')
  })
})

describe('utfallstekst', () => {
  it('skiller innlånt sats fra vanlig prising', () => {
    expect(utfallstekst({
      slag: 'priset', timesats: 138, belopKr: 828, perArt: {}, innlaant: true,
    })).toContain('annen stasjon')
    expect(utfallstekst({
      slag: 'priset', timesats: 210, belopKr: 1680, perArt: {}, innlaant: false,
    })).toBe('Priset')
  })

  it('oversetter upriset til årsaken', () => {
    expect(utfallstekst({
      slag: 'upriset', grunn: 'ukjent_nummer', forklaring: 'intern tekst',
    })).toBe('Finnes ikke i lønnsgrunnlaget for måneden')
  })

  it('ubetalt tid har sin egen tekst', () => {
    expect(utfallstekst({ slag: 'ubetalt' })).toBe('Ubetalt tid')
  })
})

describe('ledetekst og forklaring', () => {
  it('minimum får «Minst» foran beløpet', () => {
    expect(beloepsledetekst('minimum')).toBe('Minst')
  })

  it('komplett sier «Beregnet», ikke «Komplett»', () => {
    expect(beloepsledetekst('komplett')).toBe('Beregnet')
  })

  it('komplett-forklaringen lover ikke hele lønnskosten', () => {
    // «Alle REGISTRERTE timer» — ikke «all lønn». Overtid er utenfor.
    expect(statusforklaring('komplett')).toContain('registrerte timer')
  })

  it('minimum-forklaringen sier at det faktiske beløpet er høyere', () => {
    expect(statusforklaring('minimum')).toContain('høyere')
  })
})

describe('forbeholdet', () => {
  it('nevner både overtid og helligdag, kort', () => {
    expect(FORBEHOLD_KORT).toContain('Overtid')
    expect(FORBEHOLD_KORT).toContain('Helligdagstillegget')
    expect(FORBEHOLD_KORT.length).toBeLessThan(80)
  })
})
