import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// EN MEDALJE ER TILDELT EN PERSON PAA EN DATO.
//
// Reglene rundt utdelingen kan ikke kjores her — de snakker med Supabase
// — men de staar i teksten, og hver av dem er lett aa miste uten at noe
// roper:
//
//   ANSATT      Uten `ansatt_id` finnes det ingen aa gi merket til.
//               Perioden bar bare et NAVN fram til `0171`, og et navn
//               kan ikke baere et merke.
//   UTPEKT      Kjeden velger hvilket av sine egne merker som betyr
//               «ferdig opplaert». Systemet kan ikke gjette.
//   IKKE TO     `ignoreDuplicates` — en periode kan angres og fullfoeres
//               igjen, og da skal hun ikke faa merket to ganger.
//
// Og den viktigste: en periode skal kunne fullfoeres selv om ingen av
// delene er paa plass. Aa la fullfoeringen feile fordi ingen har pekt ut
// et merke ville vaert aa la pynten stoppe arbeidet.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'opplaring', 'handlinger.ts'), 'utf8')

/** Kommentarene strippes. En vakt som leser sin egen prosa staar groenn
    mens den den vokter er borte — det har skjedd fire ganger her. */
const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n').map((l) => l.replace(/\/\/.*$/, '')).join('\n')

function kroppen(navn: string): string {
  const kode = utenKommentarer(KILDE)
  const start = kode.indexOf(`function ${navn}(`)
  if (start < 0) return ''
  const neste = kode.indexOf('\nexport async function ', start + 1)
  const etter = kode.indexOf('\nasync function ', start + 1)
  const slutt = [neste, etter].filter((n) => n > 0).sort((a, b) => a - b)[0]
  return kode.slice(start, slutt ?? undefined)
}

describe('leggTilPeriode', () => {
  const kropp = kroppen('leggTilPeriode')

  it('KANARIFUGL: vakten finner handlingen', () => {
    expect(kropp.length).toBeGreaterThan(300)
  })

  it('knytter perioden til en ansatt, ikke til et skrevet navn', () => {
    expect(kropp).toContain('ansatt_id')
    expect(kropp, 'et fritekstnavn fra skjemaet ville gitt en periode ingen kan faa merke for')
      .not.toMatch(/formData\.get\(\s*['"]ansatt_navn/)
  })

  it('henter stasjonen fra den ansatte, ikke fra skjemaet', () => {
    // To felt som kan motsi hverandre er ett felt for mye: en nyansatt paa
    // Boenes registrert paa Laguneparken faar sjekklista paa feil nettbrett.
    expect(kropp).toContain('ansatt.stasjon_id')
    expect(kropp).not.toMatch(/formData\.get\(\s*['"]stasjon_id/)
  })

  it('slaar opp den ansatte gjennom RLS foer den skriver', () => {
    expect(kropp).toContain("from('ansatte')")
    expect(kropp, 'uten dette kan en id utenfor kjeden skrives inn').toMatch(/if \(!ansatt\) return/)
  })
})

describe('medaljen ved fullfoert opplaering', () => {
  const kropp = kroppen('tildelOpplaeringsmerke')
  const fullfor = kroppen('fullforPeriode')

  it('KANARIFUGL: vakten finner utdelingen', () => {
    expect(kropp.length).toBeGreaterThan(300)
    expect(kropp).toContain('tildelte_merker')
  })

  it('gir ingenting naar perioden ikke har en ansatt', () => {
    expect(kropp).toMatch(/if \(!periode\?\.ansatt_id\) return/)
  })

  it('gir bare merket kjeden har pekt ut', () => {
    expect(kropp).toContain("'opplaering_fullfort'")
    expect(kropp, 'uten dette ville den gjettet blant kjedens egne merker')
      .toMatch(/if \(!merke\) return/)
  })

  it('gir aldri det samme merket to ganger', () => {
    expect(kropp).toContain('ignoreDuplicates: true')
  })

  it('deles ut BARE naar perioden settes til fullfoert', () => {
    // `til` er av/paa. Uten vilkaaret ville en angring ogsaa delt ut merket.
    expect(fullfor).toMatch(/if \(til\)\s*await tildelOpplaeringsmerke/)
  })

  it('lar perioden fullfoeres selv om merket ikke kan gis', () => {
    // Utdelingen staar ETTER at fullfoeringen er skrevet, og kaster ikke
    // videre. Snus rekkefoelgen, kan pynten stoppe arbeidet.
    const iFullfor = fullfor.indexOf('opplaering_periode')
    const iMerke = fullfor.indexOf('tildelOpplaeringsmerke')
    expect(iFullfor).toBeGreaterThan(-1)
    expect(iMerke).toBeGreaterThan(iFullfor)
  })
})
