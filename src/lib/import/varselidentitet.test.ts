import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'

// `varsler.ts` er `server-only` og sender web-push. Begge maa staa
// utenfor testen: den ene kaster i node, den andre snakker med nettet.
// Samme oppsett som `src/lib/varsler.test.ts`.
vi.mock('server-only', () => ({}))
vi.mock('@/lib/push', () => ({ sendPushForVarsel: async () => undefined }))

const { varselnoekkel } = await import('@/lib/varsler')

// =====================================================================
// ET IMPORTVARSEL ER EN SAK, IKKE EN HENDELSE
// =====================================================================
//
// Robert, 2026-09-17, om Dales oppmerksomhetsflate: «12 ting å se på»
// inneholdt samme `export.csv (27).csv` flere ganger, ved siden av
// «mulig utsolgt» og «treffsikkerhet».
//
// Kjeden, målt i koden:
//
//   import/kjerne.ts:207          opprettVarsel(type: 'import_feil')
//   butikksjef-dashbord.tsx:264   for (const v of d.varsler) raa.push(…)
//
// Én rad blir ett kort. Uten dedup-nøkkel skrev hvert mislykkede forsøk
// en ny rad, så fem forsøk på samme fil ble fem kort med samme vekt som
// «produksjonsplanen bommer 6 dager på rad».
//
// `0201` innførte `noekkel` nettopp for dette, og skrev ned hvorfor det
// er verre enn støy:
//
//   «Det verste er ikke bråket. Det er at de ekte varslene drukner: et
//    varselsystem man lærer seg å avfeie, er et varselsystem som ikke
//    finnes.»
//
// Bemanningsvarslene og kaffevarselet fikk nøkkel da. Importen ble
// stående igjen.
//
// ---------------------------------------------------------------------
// IDENTITETEN ER STRUKTURELL, IKKE TEKSTLIG
// ---------------------------------------------------------------------
//
//   import_feil    -> `raa_fil_id`      FILA, ikke filnavnet
//   import_avvik   -> stasjon + dato    DØGNET, ikke fila
//
// To opplastinger som heter det samme er to `raa_filer`-rader, og skal
// forbli to saker. Et filnavn er presentasjon — brukeren kan laste opp
// «export.csv (27).csv» to ganger med forskjellig innhold.
//
// Og motsatt: samme døgn kan komme inn i flere filer. Da er det fortsatt
// ÉN dag å se på, så avviket nøkles ikke på fila.
//
// ---------------------------------------------------------------------
// DENNE FILA FELLER OGSÅ EN NØKKEL SOM FINNES MEN ER FEIL
// ---------------------------------------------------------------------
//
// En vakt som bare krever at `noekkel:` står der, ville vært grønn med
// `noekkel: tittel` — og da hadde vi dedupliserert på tekst, som er
// nøyaktig det `0201` forbyr: «NØKKELEN KAN IKKE VÆRE TITTELEN. Titlene
// skrives ut av tallene, og et tall som endrer seg litt mellom to
// importer ville gitt en ny tittel og dermed et nytt varsel.»
//
// Derfor bindes hvert kallsted til SIN identitet, ikke bare til at en
// nøkkel er til stede.
// =====================================================================

const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n')
    .filter((l) => !l.trim().startsWith('//'))
    .map((l) => l.replace(/\s\/\/.*$/, ''))
    .join('\n')

const KJERNE = utenKommentarer(readFileSync('src/lib/import/kjerne.ts', 'utf8'))

/** Kallet til `opprettVarsel` som inneholder `type: '<t>'`. */
function kallFor(type: string): string {
  const biter = KJERNE.split('opprettVarsel(')
  const treff = biter.filter((b) => b.slice(0, 900).includes(`type: '${type}'`))
  expect(treff.length, `fant ${treff.length} kall med type '${type}', ventet 1`).toBe(1)
  return treff[0].slice(0, 900)
}

describe('importvarsler baerer strukturell identitet', () => {
  it('import_feil noekles paa raa_fil_id — fila, ikke filnavnet', () => {
    const kall = kallFor('import_feil')
    expect(kall).toContain('noekkel:')
    expect(kall).toContain('raa_fil_id')
    // Tittelen baerer filnavnet. Noekles det paa den, er to ulike filer
    // med samme navn blitt én sak — og en tittel som endrer seg gir en
    // ny sak. Begge deler er feil.
    expect(/noekkel:[^\n]*tittel/.test(kall), 'noekler paa tittelen').toBe(false)
    expect(/noekkel:[^\n]*filnavn/.test(kall), 'noekler paa filnavnet').toBe(false)
  })

  it('import_avvik noekles paa stasjon og dato — doegnet, ikke fila', () => {
    const kall = kallFor('import_avvik')
    expect(kall).toContain('noekkel:')
    expect(kall).toContain('stasjonId')
    expect(kall).toContain('dato')
    expect(/noekkel:[^\n]*tittel/.test(kall), 'noekler paa tittelen').toBe(false)
    expect(/noekkel:[^\n]*raa_fil/.test(kall), 'avviket noekles paa fila').toBe(false)
  })

  it('spoerringen henter raa_fil_id — uten den finnes ingen identitet', () => {
    // DEN STILLE FEILEN. Faller `raa_fil_id` ut av select-lista, blir
    // feltet `undefined`, noekkelen ender paa 'import_feil:kjede:na', og
    // da blir HVER importfeil i hele kjeden én og samme sak. Det er
    // verre enn ingen noekkel.
    const linje = KJERNE.split('\n').find((l) => l.includes("from('import_jobber')")
      || l.includes('raa_filer(filnavn'))
    expect(KJERNE).toContain("select('id, raa_fil_id, raa_filer(")
    expect(linje, 'fant ikke jobbspoerringen').toBeTruthy()
  })

  it('begge bruker den felles noekkelbyggeren', () => {
    // `varselnoekkel` finnes fordi to noekler som skal vaere like driver
    // fra hverandre naar de skrives for haand — og da slutter sperren aa
    // virke uten at noe blir roedt.
    expect(kallFor('import_feil')).toContain('varselnoekkel(')
    expect(kallFor('import_avvik')).toContain('varselnoekkel(')
  })
})

describe('noekkelen skiller det som skal skilles', () => {
  it('to ulike filer gir to saker, ogsaa med samme filnavn', () => {
    const a = varselnoekkel({ slag: 'import_feil', detalj: 'fil-aaa' })
    const b = varselnoekkel({ slag: 'import_feil', detalj: 'fil-bbb' })
    expect(a).not.toBe(b)
  })

  it('samme fil gir samme sak, uansett hvor mange forsoek', () => {
    const noekler = [1, 2, 3, 4, 5].map(() =>
      varselnoekkel({ slag: 'import_feil', detalj: 'fil-aaa' }))
    expect(new Set(noekler).size).toBe(1)
  })

  it('feil og avvik er ikke samme sak', () => {
    expect(varselnoekkel({ slag: 'import_feil', detalj: 'x' }))
      .not.toBe(varselnoekkel({ slag: 'import_avvik', detalj: 'x' }))
  })

  it('avvik skilles paa baade stasjon og dato', () => {
    const k = (st: string, d: string) =>
      varselnoekkel({ slag: 'import_avvik', stasjonId: st, periode: d })
    expect(k('s1', '2026-07-01')).not.toBe(k('s2', '2026-07-01'))
    expect(k('s1', '2026-07-01')).not.toBe(k('s1', '2026-07-02'))
    expect(k('s1', '2026-07-01')).toBe(k('s1', '2026-07-01'))
  })

  it('KANARIFUGL — byggeren skiller faktisk paa detalj', () => {
    // Slutter `varselnoekkel` aa ta med `detalj`, blir HVER importfeil
    // én sak, og testene over ville vaert de eneste roede. En
    // uforsiktig hand kunne «rettet» dem.
    expect(varselnoekkel({ slag: 's', detalj: 'a' }))
      .not.toBe(varselnoekkel({ slag: 's', detalj: 'b' }))
  })
})
