import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { VERKTOY } from './verktoy'

// =====================================================================
// AI-VERKTØYET SKAL IKKE KUNNE LYVE PÅ FIRE MÅTER
// =====================================================================
//
//   1  regne ut en forventning selv
//   2  gjøre «22 % historisk feil» om til et spenn
//   3  svare på en annen dag enn i morgen
//   4  hente tall for en stasjon brukeren ikke har
//
// Alle fire ville sett ut som et velfungerende svar.
//
// Fila leser KILDEN. Verktøyet er `server-only` og snakker med basen, så
// det kan ikke instansieres her — men kontraktsbruddene er synlige i
// koden, og det er dem vi vokter.
// =====================================================================

const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n')
    .filter((l) => !l.trim().startsWith('//'))
    .filter((l) => !l.trim().startsWith('*'))
    .map((l) => l.replace(/\s\/\/.*$/, ''))
    .join('\n')

const RAA = readFileSync('src/lib/ai/forventetverktoy.ts', 'utf8')
const KODE = utenKommentarer(RAA)
const MOTOR = utenKommentarer(readFileSync('src/lib/forventet/motor.ts', 'utf8'))
const PERIODMOTOR = utenKommentarer(readFileSync('src/lib/forventet/periode.ts', 'utf8'))
const TREFF = utenKommentarer(readFileSync('src/lib/forventet/treffsikkerhet.ts', 'utf8'))
const KATALOG = utenKommentarer(readFileSync('src/lib/ai/verktoy.ts', 'utf8'))
// Systemprompten bygges av en funksjon som tar en innlogget bruker; kilden
// leses derfor som tekst, slik `lonnsverktoy.test.ts` alt gjoer.
const SYSTEM = utenKommentarer(readFileSync('src/lib/ai/assistent.ts', 'utf8'))

describe('AI regner ikke', () => {
  it('forventningen kommer fra motoren', () => {
    expect(KODE).toContain("from '@/lib/forventet/motor'")
    expect(KODE).toContain('forventetPeriode(')
    expect(PERIODMOTOR).toContain('forventetSalg(')
  })

  it('verktoeyet inneholder ingen egen prognoseformel', () => {
    // En fallback som «snitt av siste fire uker» ville sett rimelig ut og
    // gitt Sentiqa to forventninger som lignet paa hverandre.
    expect(KODE).not.toMatch(/\bmedian\s*\(/)
    expect(KODE).not.toMatch(/\bsnitt\s*\(/)
    expect(KODE).not.toMatch(/trendfaktor\s*=/)
    expect(KODE).not.toMatch(/basis\s*\*/)
  })

  it('tallet brukes som det er — bias legges ikke til', () => {
    // Dale maalte bias -3,0. Aa legge tre paa tallet ville vaert aa
    // kalibrere i presentasjonslaget, og da eier ingen sannheten.
    expect(KODE).not.toMatch(/antall\s*[+-]\s*.*bias/)
    expect(KODE).not.toMatch(/bias\s*[+-]\s*.*antall/)
    expect(KODE).toContain('f.antall')
  })

  it('ingen dekning gir ingen tall', () => {
    expect(KODE).toContain("f.slag === 'beregnet' ? f.antall : null")
  })
})

describe('treffsikkerhet er ikke et intervall', () => {
  it('INGEN INTERVALLORD I DET SOM NAAR MODELLEN', () => {
    // Foerste utgave leste hele fila og felte sin egen blokkkommentar -
    // den som forklarer at ordene er forbudt. Vakta maa lese det som
    // FAKTISK sendes: strengene i `description` og `merknad`.
    //
    // Kommentarer kan bruke ordet for aa forby det. En streng kan ikke.
    const strenger = (KODE.match(/'(?:[^'\\]|\\.)*'/g) ?? []).join(' ')
    expect(strenger).not.toMatch(/konfidens|confidence|prediksjonsintervall/i)
    expect(strenger).not.toMatch(/sannsynlig(e|het)?\s*(omraade|spenn|intervall)/i)
    // Og typen kan ikke baere et spenn uansett hva strengene sier.
    expect(KODE).not.toMatch(/intervall\s*[:?]/i)
  })

  it('maalingen baerer ingen fra/til', () => {
    expect(TREFF).not.toMatch(/\bfra:\s*number/)
    expect(TREFF).not.toMatch(/\btil:\s*number/)
    expect(TREFF).not.toMatch(/intervall|konfidens/i)
  })

  it('modellen faar beskjed om aa ikke lage et spenn', () => {
    expect(RAA).toContain('IKKE et usikkerhetsintervall')
    expect(RAA).toMatch(/aldri.*spenn/i)
  })

  it('SVAK TREFFSIKKERHET STOPPER IKKE SVARET', () => {
    // Motoren bestemmer om en forventning finnes; maalingen beskriver
    // hvor godt den har fungert. En terskel her ville gjort AI til en
    // tredje sannhet.
    expect(KODE).not.toMatch(/wmape\s*[><]/)
    // BEGGE RETNINGER. Foerste utgave saa bare etter `=== 'svak'`, og en
    // injeksjon med `!== 'svak'` gikk rett gjennom — den holdt tilbake
    // maalingen nettopp naar den var mest verdt aa vise.
    expect(KODE, 'tillit brukes som en port').not.toMatch(/tillit\([^)]*\)\s*(===|!==)/)
    // Maalingen skal foelge med uansett hva den viser.
    expect(KODE).toContain('historiskTreffsikkerhet: m ? { ...m, tillit: tillit(m) } : null')
  })

  it('maalingen kjoeres uansett dekning', () => {
    // `maalTreff` staar UTENFOR en `if (f.slag === 'beregnet')`.
    const kjor = KODE.slice(KODE.indexOf('const svar: Forventetsvar[]'))
    const iMaal = kjor.indexOf('maalTreff(')
    const iDekning = kjor.indexOf("f.slag === 'beregnet' ? f.antall")
    expect(iMaal).toBeGreaterThan(-1)
    expect(iMaal).toBeLessThan(iDekning)
  })
})

describe('horisonten er maalingens h1–h13, maksimalt sju dager sammen', () => {
  it('perioden valideres server-side', () => {
    expect(KODE).toContain('prognosePeriode(input, idag)')
  })

  it('skjemaet gir perioder, men ingen maanedsprognose', () => {
    // Utvidet med samme kunnskapstidspunkt og separat periodemaaling.
    const skjema = KODE.slice(KODE.indexOf('properties: {'), KODE.indexOf('required:'))
    const felt = [...skjema.matchAll(/^\s{8}([a-zA-Z_]+):\s*\{/gm)].map((m) => m[1])
    expect(felt.sort()).toEqual(['fra', 'periode', 'stasjoner', 'til', 'vare'])
  })

  it('modellen faar beskjed om aa si fra i stedet for aa gjette', () => {
    expect(RAA).toContain('Månedsprognose er ikke godkjent')
  })
})

describe('tilgang haandheves server-side', () => {
  it('scopet hentes foer noe annet skjer', () => {
    const kjor = KODE.slice(KODE.indexOf('async kjor'))
    expect(kjor.indexOf('hentScope(')).toBeLessThan(kjor.indexOf('hentVaresok('))
    expect(kjor.indexOf('hentScope(')).toBeLessThan(kjor.indexOf('hentSalg('))
  })

  it('spoerringene avgrenses til de autoriserte stasjonene', () => {
    // BEGGE. Soekespoerringen og salgshistorikken. Glipper den ene, kan
    // en vare fra en fremmed stasjon bli funnet og faa et tall.
    const treff = KODE.match(/\.in\('stasjon_id', (valgte\.map\(\(s\) => s\.id\)|stasjonIder)\)/g)
    expect(treff, 'en spoerring mangler stasjonsavgrensning').toHaveLength(3)
  })

  it('ingen autorisert stasjon gir ingenTilgang, ikke tomt svar', () => {
    expect(KODE).toContain('ingenTilgang: true')
  })

  it('en uautorisert stasjon naevnes uten tall', () => {
    expect(KODE).toContain('utenfor_tilgang: utenfor')
  })
})

describe('resolveren velger ikke stille', () => {
  it('flere kandidater gir et spoersmaal, ikke et tall', () => {
    const del = KODE.slice(KODE.indexOf("oppslag.slag === 'flere'"))
    expect(del).toContain('spoersmaal(')
    // Ingen `forventetSalg` mellom «flere» og returen.
    const retur = del.slice(0, del.indexOf('const vare ='))
    expect(retur).not.toContain('forventetSalg(')
  })

  it('modellen faar beskjed om aa ikke velge selv', () => {
    expect(RAA).toMatch(/ikke velg selv/i)
  })

  it('ingen treff gir ingen vare, ikke naermeste', () => {
    expect(KODE).toContain("oppslag.slag === 'ingen'")
  })

  it('INGEN KANDIDAT BLIR IKKE EN PAASTAND OM SORTIMENTET', () => {
    // Malt paa preview 2026-09-17: «varen er ... ikke i sortimentet» om
    // en vare med 432 salgsdager paa Dale. Et oppslag som ikke traff er
    // et utsagn om SOEKET, ikke om butikken.
    //
    // Vakta ligger paa BRUKERRESULTATET. `Oppslag`-unionen var riktig
    // hele tiden; det var formuleringen som loey.
    // STRENGENE SETTES SAMMEN FOERST. Kildekoden brekker dem over
    // linjer (`'selges ' + 'ikke'`), og modellen ser den sammensatte
    // teksten. Foerste utgave lette i kildeformateringen og fant ikke
    // «selges ikke» - samme feil som vakta selv advarer mot.
    const sydd = (s: string) => s.replace(/'\s*\+\s*'/g, '')
    const ingen = sydd(KODE.slice(
      KODE.indexOf("oppslag.slag === 'ingen'"),
      KODE.indexOf("oppslag.slag === 'flere'"),
    ))
    expect(ingen, 'merknaden forbyr ikke slutningene').toContain('SIER INGENTING OM SORTIMENTET')
    for (const forbudt of [
      'ikke i sortimentet', 'selges ikke', 'ingen salgshistorikk',
      'ikke registrert', 'finnes ikke',
    ]) {
      expect(ingen, `«${forbudt}» er ikke naevnt som forbudt`).toContain(forbudt)
    }
    // Og teksten skal ikke SELV paastaa noe om salget.
    expect(ingen).not.toMatch(/Fant ingen vare som (selges|finnes)/i)
  })
})

// =====================================================================
// ÉN SANNHETSEIER FOR FREMTIDIG VARESALG — MÅLT PÅ INVENTARET
// =====================================================================
//
// AI-2 E2E på preview 2026-09-17 (SHA 576e46d, anthropic ok): modellen
// valgte `hent_vareprognose` framfor `forventet_salg` og svarte at
// Coca-Cola 0,5L ikke var registrert på Dale — en vare med 432
// salgsdager der.
//
// Grunnen var ikke modellens. `assistent.ts` rutet «forventet salg per
// vare» dit, og `hent_vareprognose` lovte «FORVENTET SALG FRAMOVER …
// inntil 14 dager» med «treffer flere varer, spås den som selger mest».
//
// 4 097 grønne tester og grønn build fanget det ikke, fordi hver
// komponent isolert var riktig. Først da en språkmodell fikk se hele
// verktøykassen, ble de to sannhetene synlige.
//
// ---------------------------------------------------------------------
// VAKTA LESER INVENTARET, IKKE KILDETEKSTEN
// ---------------------------------------------------------------------
//
// Preflighten min bommet fordi den grep'et etter `name: '` og ikke
// fanget verktøy bygget med `stasjonsverktoy(...)`. Et regex over
// kildekoden kan bomme igjen på neste byggemåte.
//
// Derfor importeres `VERKTOY` og `SYSTEM`, og påstanden stilles mot det
// modellen FAKTISK får se.
// =====================================================================

describe('bare ett verktoey lover fremtidig varesalg', () => {
  it('forventet_salg er eksponert', () => {
    expect(VERKTOY.forventet_salg, 'sannhetseieren er ikke i katalogen').toBeDefined()
  })

  it('hent_vareprognose er pensjonert og ikke eksponert', () => {
    expect(VERKTOY.hent_vareprognose, 'det pensjonerte verktoeyet er tilbake').toBeUndefined()
  })

  it('INGEN ANNEN BESKRIVELSE LOVER EN FREMTIDIG FORVENTNING', () => {
    // REGELEN: snakker en beskrivelse om framtidig salg, MAA den peke
    // videre til sannhetseieren. Gjoer den ikke det, lover den selv.
    //
    // Foerste utgave forboed ordene og felte sin egen advarsel:
    // `hent_salg` sier «Bygg aldri en forventning ... da har Sentiqa to
    // prognoser», og ordet «prognoser» staar der nettopp for aa forby
    // dem. En vakt som ikke skiller et LOEFTE fra en ADVARSEL, tvinger
    // fram vagere tekst - og vag tekst var hele problemet.
    const framtid = /(forventet salt?|forventer|prognose|spaa|framover|kommer til aa selge)/i
    const brudd = Object.entries(VERKTOY)
      .filter(([navn]) => navn !== 'forventet_salg')
      .filter(([, v]) => {
        const d = String(v.schema.description ?? '')
        if (!framtid.test(d) || !/salg|vare|selge/i.test(d)) return false
        return !d.includes('forventet_salg')
      })
      .map(([navn]) => navn)
    expect(brudd, `disse snakker om framtidig salg uten aa peke paa `
      + `forventet_salg: ${brudd.join(', ')}`).toEqual([])
  })

  it('HENT_SALG KREVER IKKE AT SKILLETEGNENE STAAR LIKT', () => {
    // Malt paa preview 2026-09-17: modellen soekte «Coca Cola»,
    // `ilike('%Coca Cola%')` traff ikke «COCA-COLA 0.5L», og svaret ble
    // at varen «ikke er i sortimentet». Varen har 432 salgsdager paa
    // Dale.
    //
    // Kontrakten er felles med `forventet/varesok.ts`: skilletegn
    // skiller ikke. Soeket deles i ord, og hvert ord kreves for seg.
    const sydd = KATALOG.replace(/'\s*\+\s*'/g, '')
    expect(sydd, 'soeket krever eksakt skrivemaate igjen')
      .not.toMatch(/ilike\('varenavn', `%\$\{sok\}%`\)/)
    expect(sydd, 'soeket deles ikke i ord').toMatch(/sok\.split\(/)
  })

  it('systemprompten ruter spoersmaalet til sannhetseieren', () => {
    // Den konkrete aarsaken til at E2E ikke var groenn.
    expect(SYSTEM).toContain('forventet_salg')
    expect(SYSTEM, 'systemprompten peker fortsatt paa det pensjonerte verktoeyet')
      .not.toContain('hent_vareprognose')
  })

  it('KANARIFUGL — den gamle teksten ville blitt felt', () => {
    // Slutter moensteret aa kjenne igjen et framtidsloefte, er vakta
    // blind og testene over sier ingenting. Teksten under er den
    // faktiske beskrivelsen `hent_vareprognose` hadde.
    const gammel = 'FORVENTET SALG FRAMOVER for én vare, per dag i inntil 14 dager. '
      + 'Bruk denne paa «hvor mye X selger vi neste uke».'
    const framtid = /(forventet salt?|forventer|prognose|spaa|framover|kommer til aa selge)/i
    expect(framtid.test(gammel), 'moensteret ser ikke et framtidsloefte').toBe(true)
    expect(gammel.includes('forventet_salg'), 'den pekte aldri videre').toBe(false)
  })
})

describe('katalogen kjenner verktoeyet', () => {
  it('det er registrert', () => {
    expect(KATALOG).toContain('forventet_salg: forventetSalgVerktoy')
  })

  it('modellen og terskelen er de backtesten forsvarte', () => {
    // `basis+trend` ved 60+ salgsdager: 55,6 % wMAPE mot 71,8 % ved 30.
    // Vaeret var inert. Endres tallene, skal git vise det.
    expect(KODE).toContain("m.navn === 'basis+trend'")
    expect(KODE).toContain('MINST_DAGER = 60')
  })

  it('KANARIFUGL — motoren eier fortsatt dekningsbegrepet', () => {
    // Forsvinner `ikke_dekning` fra motoren, maaler halve denne fila
    // ingenting.
    expect(MOTOR).toContain("slag: 'ikke_dekning'")
  })
})
