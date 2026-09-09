import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// «IKKE SATT OPP» OG «FEIL NØKKEL» SÅ HELT LIKE UT
//
// E-post-inntaket sto med ett svar for begge:
//
//     if (!env.EPOST_INNTAK_SECRET || oppgitt !== env.EPOST_INNTAK_SECRET)
//       return 401 «uautorisert»
//
// Er nøkkelen ikke satt i miljøet, får Cloudflare-workeren nøyaktig samme
// svar som om den hadde feil nøkkel. Den som kobler opp inntaket for
// første gang kan da ikke vite hvilken av dem det er — og MX, worker,
// routing-regel og miljøvariabel er fire ledd som alle må stemme.
//
// Målt utenfra 2026-09-09: `POST https://sentiqa.ai/api/epost-inntak`
// svarte `401 {"feil":"uautorisert"}`. Ruta er altså deployet — men
// svaret sa ingenting om hvorvidt nøkkelen finnes.
//
// ---------------------------------------------------------------------
// OG ET VEDLEGG SOM FALLER UT
//
// Tre `continue` svelget hver sin feil: opplasting som feilet,
// innsetting som feilet, vedlegg uten innhold. Svaret ble
// `{ ok: true, mottatt: 2 }` av tre, og workeren kaster bare på ikke-2xx.
// En halvveis mottatt e-post så ut som en vellykket.
//
// **Fila kommer aldri igjen.** St1 sender én gang, og «rapporten kom
// ikke» ville blitt lett etter i importkøen der den aldri var.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', 'api', 'epost-inntak', 'route.ts'), 'utf8')

describe('målingen ser ruta', () => {
  test('KANARIFUGL: fila er lest og har innholdet vi tror', () => {
    expect(KILDE.length, 'fant nesten ingenting i route.ts').toBeGreaterThan(2000)
    expect(KILDE).toContain('EPOST_INNTAK_SECRET')
  })
})

describe('inntaket sier hva som mangler', () => {
  test('manglende nøkkel er 503, ikke 401', () => {
    expect(KILDE, 'ingen egen gren for «ikke satt opp»')
      .toMatch(/if \(!env\.EPOST_INNTAK_SECRET\)[\s\S]{0,300}?status: 503/)
  })

  test('feil nøkkel er fortsatt 401', () => {
    // 503 skal IKKE bli svaret paa en gjetting. Den sier bare at
    // funksjonen er avslaatt - selve noekkelen sies ikke.
    expect(KILDE).toMatch(/oppgitt !== env\.EPOST_INNTAK_SECRET[\s\S]{0,200}?status: 401/)
  })

  test('de to grenene er atskilte', () => {
    // Den gamle formen: ett `if` med `||`. Slaas de sammen igjen, er vi
    // tilbake til to tilstander tegnet likt.
    expect(
      KILDE,
      'nøkkelsjekken er slått sammen igjen — da kan «ikke satt opp» ikke '
      + 'skilles fra «feil nøkkel»',
    ).not.toMatch(/!env\.EPOST_INNTAK_SECRET \|\| oppgitt !==/)
  })
})

describe('et vedlegg som faller ut blir rapportert', () => {
  test('svaret bærer hva som ble hoppet over', () => {
    expect(KILDE, 'ingen `hoppet`-liste').toMatch(/const hoppet: string\[\] = \[\]/)
    expect(KILDE, '`hoppet` er ikke med i svaret').toMatch(/mottatt: antall, hoppet/)
  })

  test('hver continue i vedleggsløkka legger igjen et spor', () => {
    // Regelen, ikke et tall: et `continue` som ikke skriver til `hoppet`
    // er en fil som forsvant i stillhet. St1 sender én gang.
    const lokke = /for \(const v of vedlegg\)[\s\S]*?\n  \}/.exec(KILDE)?.[0] ?? ''
    expect(lokke.length, 'fant ikke vedleggsløkka').toBeGreaterThan(200)
    const utenSpor = [...lokke.matchAll(/continue/g)].length
      - [...lokke.matchAll(/hoppet\.push/g)].length
    expect(
      utenSpor,
      'Et `continue` i vedleggsløkka uten `hoppet.push` er en fil som '
      + 'forsvinner i stillhet. Svaret blir `{ ok: true }` med et lavere '
      + 'tall, og workeren kaster bare på ikke-2xx.',
    ).toBe(0)
  })
})

// =====================================================================
// TOM LISTE BETYDDE «ALLE»
//
// Adressen er `slug@sentiqa.ai` der slug utledes av firmanavnet — altså
// gjettbar. Cloudflare bruker catch-all, så den finnes uansett. Og
// vedlegg auto-behandles rett etter mottak.
//
// Med tom allowlist kunne derfor hvem som helst som gjettet adressen
// sende inn en fil som ble parset rett inn i tallene. Det sto i UI-en
// som «tom = alle slipper gjennom», så det var ikke et hull i koden —
// det var en dør ingen hadde tatt stilling til. **Begge kjedene i basen
// hadde tom liste 2026-09-09.**
//
// Fail-closed er halve svaret. Den andre halvparten er at sida sier det:
// et inntak som avviser alt i stillhet ser ut som at St1 ikke sendte.
// =====================================================================
describe('tom allowlist slipper ingen inn', () => {
  test('en tom liste er sin egen avvisning, ikke en åpen dør', () => {
    expect(KILDE, 'ingen egen gren for tom liste')
      .toMatch(/liste\.length === 0[\s\S]{0,300}?status: 403/)
    expect(
      KILDE,
      'den gamle formen er tilbake: `liste.length > 0 &&` betyr at en tom '
      + 'liste slipper ALLE gjennom, og adressen er gjettbar.',
    ).not.toMatch(/liste\.length > 0 &&/)
  })

  test('avsenderen står i avvisningen', () => {
    // En avvist e-post er ellers stum: Cloudflare faar 403, og den som
    // venter paa rapporten ser ingenting. Med adressen i svaret kan den
    // limes rett inn i allowlisten.
    const avvisninger = [...KILDE.matchAll(/status: 403/g)]
    expect(avvisninger.length, 'fant ingen 403-gren').toBeGreaterThanOrEqual(2)
    for (const m of KILDE.matchAll(/NextResponse\.json\(\{[\s\S]{0,300}?status: 403/g)) {
      expect(m[0], 'en 403 uten avsender er en stum avvisning').toMatch(/avsender/)
    }
  })
})

describe('sida sier fra naar inntaket er lukket', () => {
  const IMPORT = readFileSync(
    join(process.cwd(), 'src', 'app', '(beskyttet)', 'import', 'page.tsx'), 'utf8')

  test('KANARIFUGL: fila er lest', () => {
    expect(IMPORT.length).toBeGreaterThan(2000)
    expect(IMPORT).toContain('E-post-inntak')
  })

  test('tom allowlist gir en synlig advarsel', () => {
    expect(
      IMPORT,
      'Uten denne ser «ingen filer kom» ut som at St1 ikke sendte, mens '
      + 'sannheten er at inntaket avviser alt.',
    ).toMatch(/avsender_allowlist \?\? \[\]\)\.length === 0 &&/)
  })

  test('etiketten lyver ikke lenger', () => {
    // EN KOMMENTAR ER IKKE EN ETIKETT. Første utgave felte sin egen
    // rettelse: kommentaren over feltet SITERER den gamle teksten for å
    // forklare hva som ble endret. Uten strippingen melder vakten en
    // endring som er gjort — og en vakt med falske funn lærer folk å se
    // bort fra rødt. Nøyaktig samme feil drivstoffvakten hadde.
    const ren = IMPORT.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')
    expect(
      ren,
      'Feltet sier fortsatt at en tom liste slipper alle gjennom. Det er '
      + 'ikke sant lenger, og en etikett som lyver er verre enn ingen.',
    ).not.toMatch(/tom = alle slipper gjennom/)
  })
})
