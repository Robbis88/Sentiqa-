import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { utenKommentarer } from './design'

// =====================================================================
// Proxyvakten.
//
// Proxyen fikk i trinn 09 lov til å slå opp stasjoner. Det var riktig -
// den ser URL-en før noe rendres, og er derfor det eneste stedet en
// delt lenke kan bli til et husket valg uten et kappløp mot
// navigeringen.
//
// MEN DET ER ET SMALT UNNTAK, og det er den slags unntak som vokser.
// Neste gang noen trenger «bare ett oppslag til» er terskelen lavere,
// fordi det står et oppslag der fra før. Proxyen kjører på HVER
// forespørsel: et kall som legges inn her koster på alt, og feiler det,
// feiler alt.
//
// Next sier det selv i sin egen dokumentasjon: proxyen er for
// optimistiske sjekker, ikke for datahenting.
//
// ANSVARET, SKREVET NED:
//   1  fornye sesjonen
//   2  sende uinnloggede til innlogging
//   3  lese stasjonsparameteren fra URL-en
//   4  validere den mot brukerens egne stasjoner (RLS avgjør)
//   5  skrive hukommelsen når den er gyldig
//
// Alt annet hører hjemme i en side, en serverhandling eller et
// rutehåndtak - der det kan feile alene.
// =====================================================================

const ROT = process.cwd()
const FILER = [
  join(ROT, 'src', 'proxy.ts'),
  join(ROT, 'src', 'lib', 'supabase', 'proxy.ts'),
]

const kilde = FILER.map((f) => utenKommentarer(readFileSync(f, 'utf8'))).join('\n')

/**
 * Det proxyen får importere, med grunn for hver linje.
 *
 * Ikke en samlepost: står det noe her, er det fordi de fem punktene over
 * ikke kan gjøres uten.
 */
const TILLATTE_IMPORTER = new Set([
  'next/server',          // NextResponse, NextRequest
  '@supabase/ssr',        // sesjonsfornyingen
  '@/lib/env',            // nøklene
  '@/lib/stasjonsvalg',   // ren funksjon: URL → stasjonsvalg. Ingen I/O.
  '@/lib/supabase/proxy', // src/proxy.ts sin ene import: selve arbeidet.
])

describe('proxyen holder seg innenfor sitt ansvar', () => {
  test('importerer bare det de fem punktene krever', () => {
    const funnet = [...kilde.matchAll(/from\s+'([^']+)'/g)].map((m) => m[1])
    const ulovlige = funnet.filter((i) => !TILLATTE_IMPORTER.has(i))
    expect(
      ulovlige,
      'Proxyen kjorer paa hver forespoersel. En ny import her koster paa alt, '
      + 'og feiler den, feiler alt. Hoerer koden hjemme i en side eller en '
      + 'serverhandling, legg den der - ellers utvid lista i denne testen og '
      + 'skriv HVORFOR.',
    ).toEqual([])
  })

  test('roerer bare tabellen «stasjoner»', () => {
    const tabeller = [...kilde.matchAll(/\.from\(\s*'([^']+)'/g)].map((m) => m[1])
    expect(
      [...new Set(tabeller)],
      'Proxyen skal validere stasjonsvalget og ingenting annet. Et oppslag '
      + 'til er et datalag i emning.',
    ).toEqual(['stasjoner'])
  })

  test('skriver ingenting til basen', () => {
    // Den setter en informasjonskapsel. Den skal ikke endre data - en
    // skriving i proxyen kjores paa forespoersler ingen har bedt om den
    // paa, og kan ikke rulles tilbake naar navigeringen avbrytes.
    for (const farlig of ['.insert(', '.update(', '.upsert(', '.delete(', '.rpc(']) {
      expect(kilde.includes(farlig), `Proxyen kaller ${farlig}`).toBe(false)
    }
  })

  test('gjor hoyst to oppslag: sesjonen og stasjonene', () => {
    const kall = kilde.match(/await\s+supabase/g) ?? []
    expect(
      kall.length,
      'Antall databasekall i proxyen har okt. Hvert av dem ligger i veien '
      + 'for HVER sidevisning i systemet.',
    ).toBeLessThanOrEqual(2)
  })

  test('stasjonsoppslaget skjer bare naar parameteren finnes', () => {
    // Uten denne betingelsen ville hver eneste sidevisning i systemet
    // betalt for et oppslag som nesten aldri trengs.
    expect(kilde).toMatch(/if\s*\(\s*sok\.has\('stasjon'\)\s*\|\|\s*sok\.has\('butikknummer'\)\s*\)/)
  })

  // KANARIFUGL. Slutter maalingen aa se, ser den ut som en proxy uten
  // problemer. Disse tre viser at den fortsatt leser noe.
  test('KANARIFUGL - maalingen ser faktisk innholdet', () => {
    expect(kilde).toContain('createServerClient')
    expect(kilde).toContain('STASJONSKAPSEL')
    expect(kilde.length).toBeGreaterThan(2000)
  })
})
