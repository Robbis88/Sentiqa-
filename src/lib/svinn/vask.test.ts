import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { erVask, svinnPerStasjon, VASKAVDELINGER, type Stasjonsrad } from './aggreger'

// =====================================================================
// VASK MOTREGNER IKKE ØVRIGE VAREGRUPPER I EIERENS SVINNRANGERING
// =====================================================================
//
// Målt i produksjon juli 2026 (`src/lib/vaskneting.test.ts`, A + B = C
// med 0 kr avvik på alle fem stasjoner):
//
//   stasjon          øvrig      vask       total i dag
//   Varden         +14 696   −28 622       −13 926
//   Bønes          +12 196   −14 713        −2 516
//
// Varden og Bønes sto med MINUS i rangeringen — altså «usynlig
// overskudd» — mens øvrig drift hadde over 12 000 kr i manko hver. Og
// Dale, som ikke har vaskedata i det hele tatt, kunne aldri komme øverst
// uansett hvordan den styrte svinnet sitt.
//
// ---------------------------------------------------------------------
// HVA DENNE FILA FELLER
// ---------------------------------------------------------------------
//
// Splitten er billig å skrive og lett å miste. Tre måter den kan dø på,
// og alle tre ser grønne ut uten vaktene under:
//
//   1  `erVask` slutter å treffe gruppenivået (`210`) fordi noen
//      gjenbruker `avdelingAv`, som krever fem siffer.
//   2  Motoren regner splitten, men flaten rangerer på råtotalen igjen.
//   3  Settet vokser med en avdeling som bare LIGNER — `200 Bil`.
//
// Punkt 2 kan ikke ses i denne modulen i det hele tatt. Derfor leser de
// siste testene kilden til `stasjonsrangering.tsx` og
// `admin-dashbord.tsx`: en motor som deler riktig, foran en flate som
// ikke bruker delingen, er en port uten virkning.
// =====================================================================

const S = '11111111-1111-1111-1111-111111111111'
const D = '22222222-2222-2222-2222-222222222222'

/** Grupperad slik reimporten legger dem: tresifret kode, `nivaa = 'gruppe'`. */
function g(
  stasjon: string, kode: string, usynlig: number, kast = 0,
): Stasjonsrad {
  return {
    stasjon_id: stasjon, periode: '2026-07-01', nivaa: 'gruppe',
    analyseomraade: 'butikk', kode, kast, usynlig_kr: usynlig,
  }
}

const sum = (rader: Stasjonsrad[], stasjon = S) =>
  svinnPerStasjon(rader).find((x) => x.stasjonId === stasjon)!

describe('erVask — strukturell kode, aldri navn', () => {
  it('treffer vaskavdelingene paa BEGGE nivaaer', () => {
    // Gruppenivaa er det reimporten faktisk legger inn, og det er
    // nettopp det `avdelingAv` ikke taaler.
    expect(erVask('210')).toBe(true)
    expect(erVask('211')).toBe(true)
    // Produktnivaa, slik radene laa foer reimporten.
    expect(erVask('21010')).toBe(true)
    expect(erVask('21014')).toBe(true)
    expect(erVask('21110')).toBe(true)
  })

  it('treffer IKKE en avdeling som bare ligner i navn', () => {
    // `200 Bil` er bil, ikke bilvask. Matchet noen paa teksten «vask»,
    // ville denne staatt.
    expect(erVask('200')).toBe(false)
    expect(erVask('20010')).toBe(false)
  })

  it('treffer IKKE 130 selv om den staar i MOTPOSTER', () => {
    // 130 motposterer seg selv (kaffe mot kaffelojalitet). Det er en
    // mekanisme, ikke en betydning — og fire av fem stasjoner har
    // POSITIV netto der og faar varsel som de skal.
    expect(erVask('130')).toBe(false)
    expect(erVask('13011')).toBe(false)
  })

  it('taaler tomt, null og soppel uten aa kaste', () => {
    expect(erVask(null)).toBe(false)
    expect(erVask('')).toBe(false)
    expect(erVask('  ')).toBe(false)
    expect(erVask('VASK')).toBe(false)
    expect(erVask('21')).toBe(false)
  })

  it('KANARIFUGL — settet er ikke tomt', () => {
    // Blir `VASKAVDELINGER` tom, blir hver `erVask` usann, og hele
    // splitten faller sammen til raatotalen igjen. Testene over ville
    // fortsatt bestaatt: de positive ville blitt de eneste roede, og en
    // uforsiktig hand kunne «rettet» dem.
    expect(VASKAVDELINGER.size).toBeGreaterThan(0)
    expect([...VASKAVDELINGER].every((k) => /^\d{3}$/.test(k))).toBe(true)
  })
})

describe('svinnPerStasjon — splitten', () => {
  it('holder 210 og 211 utenfor styringstallet, men beholder raatotalen', () => {
    const r = sum([
      g(S, '120', 5_000),
      g(S, '160', 7_196),
      g(S, '210', -28_000),
      g(S, '211', -622),
    ])
    expect(r.utenVaskKr).toBe(12_196)
    expect(r.vaskKr).toBe(-28_622)
    // RAATOTALEN ER IKKE ROERT. Den er fortsatt tilgjengelig for enhver
    // leser som vil ha hele bildet.
    expect(r.usynligKr).toBe(-16_426)
  })

  it('utenVask + vask = raatotal, ogsaa naar fortegnene sprikher', () => {
    const rader = [
      g(S, '120', 31_902), g(S, '130', 16_862), g(S, '140', -4_656),
      g(S, '210', -18_119), g(S, '211', -6_520), g(S, '250', 3_663),
    ]
    const r = sum(rader)
    expect(r.utenVaskKr + r.vaskKr).toBe(r.usynligKr)
  })

  it('en stasjon UTEN vaskedata er uendret — utenVask er lik raatotalen', () => {
    // Dale. Ingen 210/211-rader i det hele tatt. Porten skal ikke flytte
    // tallet hennes en krone.
    const r = sum([g(D, '120', 20_000), g(D, '160', 19_919)], D)
    expect(r.vaskKr).toBe(0)
    expect(r.utenVaskKr).toBe(r.usynligKr)
    expect(r.usynligKr).toBe(39_919)
  })

  it('en vaskrad med 0 kr gir ikke utslag noen vei', () => {
    const r = sum([g(S, '120', 1_000), g(S, '210', 0)])
    expect(r.vaskKr).toBe(0)
    expect(r.utenVaskKr).toBe(1_000)
    expect(r.usynligKr).toBe(1_000)
  })

  it('bare vask: styringstallet er 0, raatotalen er ikke', () => {
    // Grensetilfellet som skiller «ingen oevrig manko» fra «ingen data».
    const r = sum([g(S, '210', -50_000)])
    expect(r.utenVaskKr).toBe(0)
    expect(r.vaskKr).toBe(-50_000)
    expect(r.usynligKr).toBe(-50_000)
  })

  it('splitten respekterer nivaavalget — grupperaden eier totalen', () => {
    // Etter reimporten ligger `210` og `21010` i samme svar.
    // `velgGrunnlag` slipper gjennom ETT nivaa; teller splitten begge,
    // ville vasken blitt talt to ganger og styringstallet blitt feil.
    const r = sum([
      g(S, '120', 5_000),
      g(S, '210', -10_000),
      { ...g(S, '21010', -10_000), nivaa: 'produkt' },
    ])
    expect(r.vaskKr).toBe(-10_000)
    expect(r.utenVaskKr).toBe(5_000)
  })
})

// ---------------------------------------------------------------------
// FLATEN MAA FAKTISK BRUKE SPLITTEN
// ---------------------------------------------------------------------
//
// Testene over kan alle vaere groenne mens rangeringen sorterer paa
// raatotalen som foer. Det er den formen for stillhet porten skulle
// fjerne, saa den maales i kilden.
//
// KOMMENTARER STRIPPES FOERST. Begge filene FORKLARER vasken i prosa,
// og et `toContain` mot raa filtekst ville truffet forklaringen i stedet
// for koden — samme felle som `bildevakt.test.ts` beskriver.
const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n')
    .filter((l) => !l.trim().startsWith('//'))
    .map((l) => l.replace(/\s\/\/.*$/, ''))
    .join('\n')

const RANG = utenKommentarer(
  readFileSync('src/app/(beskyttet)/stasjonsrangering.tsx', 'utf8'))
const DASH = utenKommentarer(
  readFileSync('src/app/(beskyttet)/admin-dashbord.tsx', 'utf8'))

describe('eierens rangering bruker styringstallet', () => {
  it('usynlig-fanen sorterer paa usynligUtenVask, ikke paa raatotalen', () => {
    const linje = RANG.split('\n').find((l) => l.includes('linjer = rader.map')
      && l.includes('usynlig'))
    expect(linje, 'fant ikke usynlig-fanens linje i stasjonsrangering.tsx').toBeTruthy()
    expect(linje!).toContain('r.usynligUtenVask')
    // `r.usynlig` alene ville vaert raatotalen tilbake. `usynligUtenVask`
    // inneholder tegnfoelgen `usynlig`, saa det holder ikke aa lete etter
    // fravaer av ordet - linja maa ikke lese FELTET `r.usynlig`.
    expect(/r\.usynlig[^U]/.test(linje!), 'rangerer paa raatotalen igjen').toBe(false)
  })

  it('RangRad baerer begge tallene', () => {
    expect(RANG).toContain('usynlig: number')
    expect(RANG).toContain('usynligUtenVask: number')
  })

  it('dashbordet henter `kode` — uten den er all vask «oevrig»', () => {
    // DEN STILLE FEILEN. Faller `kode` ut av select-lista, blir feltet
    // `undefined`, `erVask` usann for hver rad, og vasken lander i
    // `utenVaskKr` uten at noe feiler.
    const linje = DASH.split('\n').find((l) => l.includes('regnskap_usynlig_svinn'))
    expect(linje, 'fant ikke spoerringen i admin-dashbord.tsx').toBeTruthy()
    expect(linje!).toContain('kode')
    expect(linje!).toContain('usynlig_kr')
  })

  it('dashbordet foerer begge tallene videre', () => {
    expect(DASH).toContain('r.usynlig += s.usynligKr')
    expect(DASH).toContain('r.usynligUtenVask += s.utenVaskKr')
  })
})
