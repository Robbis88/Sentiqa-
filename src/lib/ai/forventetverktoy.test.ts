import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

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
const TREFF = utenKommentarer(readFileSync('src/lib/forventet/treffsikkerhet.ts', 'utf8'))
const KATALOG = utenKommentarer(readFileSync('src/lib/ai/verktoy.ts', 'utf8'))

describe('AI regner ikke', () => {
  it('forventningen kommer fra motoren', () => {
    expect(KODE).toContain("from '@/lib/forventet/motor'")
    expect(KODE).toContain('forventetSalg(')
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

describe('horisonten er +1', () => {
  it('maaldatoen er dagen etter i dag', () => {
    expect(KODE).toContain('leggTilDager(idag, 1)')
  })

  it('verktoeyet tar ingen dato fra modellen', () => {
    // Et `dato`-felt i skjemaet ville invitert til «neste fredag», og da
    // maatte noe annet enn kontrakten stoppe det.
    //
    // FELTNAVNENE, IKKE BESKRIVELSENE. Foerste utgave leste hele
    // skjemablokken og felte ordet «til» i «har tilgang til» - en
    // setning til brukeren, ikke et felt modellen kan fylle.
    const skjema = KODE.slice(KODE.indexOf('properties: {'), KODE.indexOf('required:'))
    const felt = [...skjema.matchAll(/^\s{8}([a-zA-Z_]+):\s*\{/gm)].map((m) => m[1])
    expect(felt.sort()).toEqual(['stasjoner', 'vare'])
  })

  it('modellen faar beskjed om aa si fra i stedet for aa gjette', () => {
    expect(RAA).toMatch(/bare.*godkjent prognose for neste dag/i)
  })
})

describe('tilgang haandheves server-side', () => {
  it('scopet hentes foer noe annet skjer', () => {
    const kjor = KODE.slice(KODE.indexOf('async kjor'))
    expect(kjor.indexOf('hentScope(')).toBeLessThan(kjor.indexOf("from('v_butikksalg')"))
  })

  it('spoerringene avgrenses til de autoriserte stasjonene', () => {
    // BEGGE. Soekespoerringen og salgshistorikken. Glipper den ene, kan
    // en vare fra en fremmed stasjon bli funnet og faa et tall.
    const treff = KODE.match(/\.in\('stasjon_id', (valgte\.map\(\(s\) => s\.id\)|stasjonIder)\)/g)
    expect(treff, 'en spoerring mangler stasjonsavgrensning').toHaveLength(2)
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
