import { describe, expect, test } from 'vitest'
import {
  alternativer, byggVerdier, erMindreaarig, erUtfyllingsfelt, manglerVerdi,
} from './felter'

const g = (over: Partial<Parameters<typeof byggVerdier>[0]> = {}) => byggVerdier({
  kjede: { navn: 'Kelsar Bil AS', orgNr: '977 037 859', standardfelt: { '10.': '15.', '6': '6' } },
  stasjon: { navn: 'Bønes', adresse: 'Bønesskogen 4' },
  ansatt: {
    navn: 'Kari Nordmann', fodselsdato: '2001-03-14',
    stillingsprosent: 20, timesats: 196.02, skiftordning: 'to_skift',
  },
  svar: {},
  ...over,
})

describe('erUtfyllingsfelt', () => {
  test('korte felt fylles ut', () => {
    for (const f of ['stillingsprosent', 'Navn på arbeidstaker', '37,5/35,5', '6', '10.']) {
      expect(erUtfyllingsfelt(f), f).toBe(true)
    }
  })

  test('en tom klamme er en avkryssingsboks, ikke et felt', () => {
    // Rammeavtalen for tilkalling har «[  ]» to steder i punkt 2 —
    // grunnlaget for midlertidigheten etter aml. § 14-9 (2) a eller b.
    // De krysses av i Word.
    expect(erUtfyllingsfelt('  ')).toBe(false)
    expect(erUtfyllingsfelt('')).toBe(false)
    expect(manglerVerdi(['  ', 'stillingstittel'], {}).map((m) => m.navn))
      .toEqual(['stillingstittel'])
    expect(alternativer(['  ', 'Det gjelder ingen prøvetid i stillingen.']))
      .toEqual(['Det gjelder ingen prøvetid i stillingen.'])
  })

  test('hele setninger er alternativer, ikke felt', () => {
    expect(erUtfyllingsfelt(
      'Arbeidstaker er ansatt i stilling som [stillingstittel]. Denne Avtalen erstatter tidligere arbeidsavtaler'))
      .toBe(false)
    expect(erUtfyllingsfelt('Det gjelder ingen prøvetid i stillingen.')).toBe(false)
  })
})

describe('erMindreaarig', () => {
  test('fyller 18 på dagen, ikke etter 6574 døgn', () => {
    // Bursdagen 14.03. Dagen før er hun 17, på selve dagen er hun 18.
    expect(erMindreaarig('2008-03-14', '2026-03-13')).toBe(true)
    expect(erMindreaarig('2008-03-14', '2026-03-14')).toBe(false)
  })

  test('skuddår velter ikke regnestykket', () => {
    // Fire skuddår mellom 2008 og 2026 gir 6575 døgn, ikke 6574 — nok til
    // at en millisekundregning bommer med en dag.
    expect(erMindreaarig('2008-02-29', '2026-02-28')).toBe(true)
    expect(erMindreaarig('2008-02-29', '2026-03-01')).toBe(false)
  })

  test('ukjent fødselsdato er ikke det samme som mindreårig', () => {
    expect(erMindreaarig(null, '2026-08-16')).toBe(false)
  })
})

describe('byggVerdier', () => {
  test('fyller det systemet vet', () => {
    const v = g()
    expect(v['Navn på arbeidstaker']).toBe('Kari Nordmann')
    expect(v['stillingsprosent']).toBe('20')
    expect(v['stasjonsnavn']).toBe('Bønes')
  })

  test('fødselsdato blir norsk', () => {
    expect(g()['fødselsdato']).toBe('14.03.2001')
  })

  test('timelønn får komma, ikke punktum', () => {
    expect(g()['timelønn']).toBe('196,02')
  })

  test('arbeidstiden følger skiftordningen', () => {
    expect(g()['37,5/35,5']).toBe('35,5')
    expect(g()['40/38,5']).toBe('38,5')
    const ord = byggVerdier({
      kjede: { navn: 'K', orgNr: null, standardfelt: {} },
      stasjon: { navn: 'S', adresse: null },
      ansatt: { navn: 'N', fodselsdato: null, stillingsprosent: null, timesats: null, skiftordning: 'ordinaer' },
      svar: {},
    })
    expect(ord['37,5/35,5']).toBe('37,5')
  })

  test('kjedens standardfelt kommer med', () => {
    expect(g()['10.']).toBe('15.')
    expect(g()['6']).toBe('6')
  })

  test('svar fra butikksjefen overstyrer', () => {
    const v = g({ svar: { stillingsprosent: '30', stillingstittel: 'butikkmedarbeider' } })
    expect(v['stillingsprosent']).toBe('30')
    expect(v['stillingstittel']).toBe('butikkmedarbeider')
  })

  test('tomme verdier utelates — da står klammen igjen og er synlig', () => {
    const v = byggVerdier({
      kjede: { navn: 'K', orgNr: null, standardfelt: {} },
      stasjon: { navn: 'S', adresse: null },
      ansatt: { navn: 'N', fodselsdato: null, stillingsprosent: null, timesats: null, skiftordning: null },
      svar: { beskrivelse: '  ' },
    })
    expect('organisasjonsnummer' in v).toBe(false)
    expect('adresse' in v).toBe(false)
    expect('beskrivelse' in v).toBe(false)
  })
})

describe('manglerVerdi', () => {
  test('sier hvilke felt som gjenstår og hvor de kommer fra', () => {
    const iMal = ['stillingsprosent', 'stillingstittel', 'beskrivelse', 'organisasjonsnummer']
    const m = manglerVerdi(iMal, g())
    expect(m.map((x) => x.navn).sort()).toEqual(['beskrivelse', 'stillingstittel'])
    expect(m.every((x) => x.kilde === 'spor')).toBe(true)
  })

  test('alternativsetninger regnes ikke som manglende', () => {
    const iMal = ['stillingsprosent', 'Det gjelder ingen prøvetid i stillingen.']
    expect(manglerVerdi(iMal, g())).toEqual([])
  })

  test('et felt malen har og vi ikke kjenner blir et spørsmål', () => {
    const m = manglerVerdi(['nytt felt'], {})
    expect(m[0]).toMatchObject({ navn: 'nytt felt', kilde: 'spor' })
  })
})

describe('alternativer', () => {
  test('plukker ut setningene som skal leses', () => {
    const a = alternativer(['stillingsprosent', 'Det gjelder ingen prøvetid i stillingen.'])
    expect(a).toEqual(['Det gjelder ingen prøvetid i stillingen.'])
  })
})
