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
