import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { BUTIKKSJEF_KOSTNAD_KODER, BUTIKKSJEF_PERSONAL_KODER } from '../regnskap-tilgang'

// =====================================================================
// KODELISTA FINNES TO STEDER, OG DA MÅ NOEN HOLDE DEM SAMMEN
//
// `regnskap-tilgang.ts` sier hvilke kontoer en butikksjef ser.
// `0192_kontoene_er_eierens.sql` gjentar den samme lista i en
// RLS-policy, fordi Postgres ikke kan lese en TypeScript-konstant.
//
// To kilder for samme regel er den formen dette repoet har blitt bitt
// av flest ganger: de er like den dagen de skrives, og de skiller lag i
// stillhet. Går de fra hverandre her, får det to helt ulike uttrykk:
//
//   Kode som står i TS men ikke i SQL → butikksjefen ser en tom rad i
//   en tabell som lover den. Ser ut som «ingen kostnad denne måneden».
//
//   Kode som står i SQL men ikke i TS → hullet policyen ble skrevet for
//   å lukke, står halvveis åpent, og ingenting sier fra: appen skjuler
//   den, så ingen ser den før noen leser den over PostgREST.
//
// Den andre er den farlige, og den er usynlig fra brukerflaten. Derfor
// denne.
//
// ---------------------------------------------------------------------
// HVORFOR IKKE BARE GENERERE SQL-EN FRA TS
//
// Fordi migrasjonene limes inn for hånd i SQL Editor og skal kunne
// kjøres om igjen fra bunn, uavhengig av en byggekjede. En generert fil
// som ingen kan lese i editoren er verre enn en duplikat med en vakt.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/** Siste migrasjon som definerer `regnskapslinjer_les`. */
function policykropp(): { fil: string; sql: string } {
  let funn: { fil: string; sql: string } | null = null
  for (const fil of readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()) {
    const sql = readFileSync(join(KATALOG, fil), 'utf8')
    // Kommentarer først: fila FORKLARER regelen i prosa, og de tallene
    // er ikke et filter. Uten strippingen ville en kode nevnt i en
    // kommentar telt som håndhevet — nøyaktig feilen `drivstoffvakt`
    // hadde.
    const ren = sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*/g, '')
    const m = /create policy regnskapslinjer_les[\s\S]*?;\s*$/m.exec(ren)
    if (m) funn = { fil, sql: m[0] }
  }
  if (!funn) throw new Error('fant ingen definisjon av regnskapslinjer_les')
  return funn
}

const policy = policykropp()
const iSql = new Set([...policy.sql.matchAll(/'(\d{3})'/g)].map((m) => m[1]))

describe('målingen ser policyen', () => {
  test('KANARIFUGL: den fant en ekte policy med koder i', () => {
    // Bytter policyen navn, eller flyttes lista til en funksjon, blir
    // settet tomt — og «TS og SQL er like» ville vært sant fordi SQL
    // ikke har noen koder i det hele tatt.
    expect(iSql.size, `fant ingen kontokoder i ${policy.fil}`).toBeGreaterThan(10)
    expect(policy.sql).toMatch(/butikksjef_stasjoner/)
  })

  test('KANARIFUGL: en kode i en kommentar teller ikke', () => {
    const ren = "-- kode '999' er eierens\ncreate policy p on t using (kode in ('501'));"
      .replace(/--.*/g, '')
    expect([...ren.matchAll(/'(\d{3})'/g)].map((m) => m[1])).toEqual(['501'])
  })
})

describe('kodelista er én regel, ikke to', () => {
  test('SQL og TypeScript har nøyaktig de samme kodene', () => {
    const iTs = new Set(BUTIKKSJEF_KOSTNAD_KODER)
    const baresql = [...iSql].filter((k) => !iTs.has(k)).sort()
    const bareTs = [...iTs].filter((k) => !iSql.has(k)).sort()

    expect(
      { baresql, bareTs },
      '\nKodelista i regnskap-tilgang.ts og i RLS-policyen har skilt lag.\n\n'
      + `  bare i SQL:  ${baresql.join(', ') || '(ingen)'}\n`
      + `  bare i TS:   ${bareTs.join(', ') || '(ingen)'}\n\n`
      + 'Bare i SQL: hullet policyen skulle lukke staar halvveis aapent, '
      + 'og appen skjuler raden - saa ingen ser det foer noen leser den '
      + 'over PostgREST.\n'
      + 'Bare i TS: butikksjefen faar en tom rad i en tabell som lover '
      + 'tallet, og det ser ut som «ingen kostnad denne maaneden».\n',
    ).toEqual({ baresql: [], bareTs: [] })
  })

  test('de ni lønnskontoene staar i policyen', () => {
    // Loennskosten leser HELE `driftskostnader` og filtrerer i TS.
    // Faller én av de ni ut av policyen, blir loennskosten feil uten at
    // noe feiler - tallet blir bare mindre.
    const mangler = [...BUTIKKSJEF_PERSONAL_KODER].filter((k) => !iSql.has(k)).sort()
    expect(
      mangler,
      `Loennskontoene ${mangler.join(', ')} mangler i RLS-policyen. `
      + 'Loennskosten leser dem gjennom den, og et manglende konto gir et '
      + 'lavere tall - ikke en feilmelding.',
    ).toEqual([])
  })

  test('RESULTAT-linja er stengt for butikksjef', () => {
    expect(policy.sql, 'policyen slipper fortsatt gjennom seksjon = resultat')
      .toMatch(/seksjon\s*<>\s*'resultat'/)
  })

  test('hjelpekallene er pakket, saa policyen ikke evalueres per rad', () => {
    // Samme regel som RLS-vakthunden punkt 1, maalt her fordi denne
    // policyen leses paa hver regnskapsside.
    for (const kall of ['gjeldende_retailer_id', 'gjeldende_rolle', 'auth.uid']) {
      const raa = new RegExp(`(?<!select\\s)${kall.replace('.', '\\.')}\\s*\\(`, 'g')
      const alle = [...policy.sql.matchAll(new RegExp(`${kall.replace('.', '\\.')}\\s*\\(`, 'g'))]
      const pakket = [...policy.sql.matchAll(new RegExp(`select\\s+public\\.${kall.replace('.', '\\.')}\\s*\\(|select\\s+${kall.replace('.', '\\.')}\\s*\\(`, 'g'))]
      expect(alle.length, `${kall} kalles ikke i policyen`).toBeGreaterThan(0)
      expect(
        pakket.length,
        `${kall} er kalt uten (select ...) - da evalueres den per rad og `
        + 'regnskapssidene faar statement timeout, som ser ut som 0 rader.',
      ).toBe(alle.length)
      void raa
    }
  })
})

// =====================================================================
// REGELEN SOM VILLE FUNNET 506 FØR MIGRASJONEN BLE SKREVET
//
// `LONNSKONTI` (lonnskost/maaned.ts) og `BUTIKKSJEF_PERSONAL_KODER`
// (regnskap-tilgang.ts) er to lister over de samme kontoene, skrevet
// til hvert sitt formål: den ene summerer lønn, den andre bestemmer
// hvem som får se den.
//
// De hadde skilt lag på ett konto: **506 Refundert sykelønn**.
// /lonnskost regnet den inn — den er refusjonen av 505, ført negativt.
// /regnskap gjorde det ikke. Butikksjefen så altså sykelønnen som
// kostnad, men ikke pengene tilbake, og «Personalkostnad» var for høy
// på hver stasjon med sykefravær.
//
// Det var usynlig så lenge begge var visningsfiltre — to sider som
// viser litt ulike tall er ubehagelig, men ikke farlig. Det ble farlig
// i det øyeblikket den ene lista skulle bli en RLS-grense: da ville
// policyen kuttet 506 for butikksjefen, og lønnskosten hadde blitt for
// høy også der. En sikkerhetsstramming som gjør et tall galt.
//
// Regelen er enkel: **alt lønnskosten summerer, må butikksjefen kunne
// lese.** Ellers er den ikke lønnskost lenger, den er et utvalg.
// =====================================================================
describe('lønnskosten og innsynet er enige om kontoplanen', () => {
  test('hver konto lønnskosten summerer, kan butikksjefen lese', async () => {
    const { LONNSKONTI, ANDRE_PERSONALKONTI } = await import('../lonnskost/maaned')
    const mangler = [...LONNSKONTI, ...ANDRE_PERSONALKONTI]
      .filter((k) => !BUTIKKSJEF_KOSTNAD_KODER.has(k)).sort()

    expect(
      mangler,
      `\nKontoene ${mangler.join(', ')} inngaar i loennskosten, men staar ikke `
      + 'i BUTIKKSJEF_KOSTNAD_KODER.\n\n'
      + 'Fra 0192 er den lista en RLS-grense. En konto som mangler her blir '
      + 'usynlig for butikksjefen - og siden 506 er NEGATIV, blir tallet da '
      + 'for HOEYT, ikke for lavt. En stramming som gjoer et tall galt er '
      + 'verre enn hullet den lukket.\n',
    ).toEqual([])
  })

  test('KANARIFUGL: regelen ville tatt 506 slik den sto', () => {
    const somDenVar = new Set(['501', '502', '503', '505', '508', '509', '540', '541', '590',
      '627', '628', '629', '632', '633', '634', '636', '638', '746'])
    const lonn = ['501', '502', '503', '505', '506', '508', '509', '540', '541']
    expect(lonn.filter((k) => !somDenVar.has(k))).toEqual(['506'])
  })
})
