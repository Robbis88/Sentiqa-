import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  BUTIKKSJEF_BEGREP, BUTIKKSJEF_PERSONAL_BEGREP, BUTIKKSJEF_KOSTNAD_KODER,
} from '../regnskap-tilgang'
import { registrertePar } from '../parsere/kontoregister'

// =====================================================================
// GRENSEN RESONNERER IKKE LENGER OM TALL
// =====================================================================
//
// Fram til `0203` gjentok `regnskapslinjer_les` kodelista fra
// `regnskap-tilgang.ts`, og denne testen holdt de to sammen.
//
// Den bindingen er borte fordi PREMISSET var feil: en kode er en
// adresse, ikke en identitet. St1 renummererte rapportlinjene i februar
// 2026, og `628` betydde «Leie driftsmidler» før det. En policy skrevet
// i tall ville vist butikksjefen leasingkostnaden som renovasjon på hver
// rad fra den gamle epoken — og prisen for å unngå det var at januar
// 2026 og alt eldre ikke kunne importeres i det hele tatt.
//
// `0203` skriver grensen i `begrep`. Denne testen beviser at den er det,
// og at den ikke sklir tilbake.
//
// Selve lista (begrep i policyen == `BUTIKKSJEF_BEGREP`) bindes av
// `src/lib/parsere/begrepliste.test.ts`. Her måles FORMEN på grensen og
// de to reglene som ikke handler om lista.
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
const koderISql = [...policy.sql.matchAll(/'(\d{3})'/g)].map((m) => m[1])
const begrepISql = [...policy.sql.matchAll(/'([a-z_]{4,})'/g)].map((m) => m[1])

describe('målingen ser policyen', () => {
  test('KANARIFUGL: den fant en ekte policy', () => {
    // Bytter policyen navn, eller flyttes lista til en funksjon, blir
    // uttrekket tomt — og hver påstand under ville vært sann fordi det
    // ikke er noe å måle.
    expect(policy.sql).toMatch(/butikksjef_stasjoner/)
    expect(begrepISql.length, `fant ingen begreper i ${policy.fil}`).toBeGreaterThan(10)
    expect(begrepISql).toContain('renhold')
  })

  test('KANARIFUGL: en kode i en kommentar teller ikke', () => {
    const ren = "-- kode '999' er eierens\ncreate policy p on t using (kode in ('501'));"
      .replace(/--.*/g, '')
    expect([...ren.matchAll(/'(\d{3})'/g)].map((m) => m[1])).toEqual(['501'])
  })

  test('KANARIFUGL: kodeuttrekket ville sett en kode hvis den var der', () => {
    // Uten denne kunne påstanden «ingen koder i policyen» vært grønn
    // fordi regexen var død, ikke fordi kodene var borte.
    expect([...("using (kode in ('501','628'))").matchAll(/'(\d{3})'/g)].map((m) => m[1]))
      .toEqual(['501', '628'])
  })
})

describe('grensen er skrevet i begrep, ikke i koder', () => {
  test('ingen kontokoder igjen i policyen', () => {
    expect(
      koderISql,
      `\n${policy.fil} har kontokoder i tilgangsgrensen igjen: ${koderISql.join(', ')}\n\n`
      + 'En kode er en ADRESSE. St1 renummererte rapportlinjene i februar 2026 '
      + '- 628 betydde «Leie driftsmidler» foer og «Renovasjon» naa. En grense '
      + 'i tall viser derfor leasingkostnaden til butikksjefen paa hver rad fra '
      + 'den gamle epoken, og tvinger importen til aa avvise gamle filer for aa '
      + 'unngaa det.\n\nBruk `begrep`. Se 0203 og parsere/kontoregister.ts.\n',
    ).toEqual([])
  })

  test('en rad uten begrep er skjult, ikke synlig', () => {
    // NULL betyr «vi vet ikke hva denne raden er». Ukjent skal falle paa
    // eierens side, akkurat som en ukjent kode gjorde i 0192.
    expect(policy.sql, 'policyen krever ikke at begrep er satt')
      .toMatch(/begrep\s+is\s+not\s+null/i)
  })

  test('RESULTAT-linja er stengt for butikksjef', () => {
    expect(policy.sql, 'policyen slipper fortsatt gjennom seksjon = resultat')
      .toMatch(/seksjon\s*<>\s*'resultat'/)
  })

  test('hjelpekallene er pakket, saa policyen ikke evalueres per rad', () => {
    // Samme regel som RLS-vakthunden punkt 1, maalt her fordi denne
    // policyen leses paa hver regnskapsside.
    for (const kall of ['gjeldende_retailer_id', 'gjeldende_rolle', 'auth.uid']) {
      const navn = kall.replace('.', '\\.')
      const alle = [...policy.sql.matchAll(new RegExp(`${navn}\\s*\\(`, 'g'))]
      const pakket = [...policy.sql.matchAll(
        new RegExp(`select\\s+public\\.${navn}\\s*\\(|select\\s+${navn}\\s*\\(`, 'g'),
      )]
      expect(alle.length, `${kall} kalles ikke i policyen`).toBeGreaterThan(0)
      expect(
        pakket.length,
        `${kall} er kalt uten (select ...) - da evalueres den per rad og `
        + 'regnskapssidene faar statement timeout, som ser ut som 0 rader.',
      ).toBe(alle.length)
    }
  })
})

// =====================================================================
// REGELEN SOM VILLE FUNNET 506 FØR MIGRASJONEN BLE SKREVET
//
// `LONNSKONTI` (lonnskost/maaned.ts) og personallista i
// `regnskap-tilgang.ts` er to lister over de samme kontoene, skrevet til
// hvert sitt formål: den ene summerer lønn, den andre bestemmer hvem som
// får se den.
//
// De hadde skilt lag på ett konto: **506 Refundert sykelønn**.
// /lonnskost regnet den inn — den er refusjonen av 505, ført negativt.
// /regnskap gjorde det ikke. Butikksjefen så altså sykelønnen som
// kostnad, men ikke pengene tilbake, og «Personalkostnad» var for høy
// på hver stasjon med sykefravær.
//
// Det var usynlig så lenge begge var visningsfiltre. Det ble farlig i
// det øyeblikket den ene lista skulle bli en RLS-grense: da ville
// policyen kuttet 506, og lønnskosten hadde blitt for høy også der. En
// sikkerhetsstramming som gjør et tall galt.
//
// Regelen er enkel: **alt lønnskosten summerer, må butikksjefen kunne
// lese.** Ellers er den ikke lønnskost lenger, den er et utvalg.
//
// Etter `0203` går regelen gjennom registeret: konto → begrep → lista.
// Det er ett ledd mer, og det er ledd nummer to som er poenget — det er
// der epoken håndteres.
// =====================================================================

/** Begrepene en rapportlinjekode kan bety, på tvers av epokene. */
function begrepFor(kode: string): string[] {
  return [...new Set(registrertePar().filter((p) => p.kode === kode).map((p) => p.begrep))]
}

describe('lønnskosten og innsynet er enige om kontoplanen', () => {
  test('hver konto lønnskosten summerer, kan butikksjefen lese', async () => {
    const { LONNSKONTI, ANDRE_PERSONALKONTI } = await import('../lonnskost/maaned')
    const tillatt = new Set<string>(BUTIKKSJEF_BEGREP)
    const mangler = [...LONNSKONTI, ...ANDRE_PERSONALKONTI]
      .filter((k) => {
        const b = begrepFor(k)
        return b.length === 0 || !b.every((x) => tillatt.has(x))
      })
      .sort()

    expect(
      mangler,
      `\nKontoene ${mangler.join(', ')} inngaar i loennskosten, men begrepet `
      + 'deres staar ikke i BUTIKKSJEF_BEGREP.\n\n'
      + 'Fra 0203 er den lista en RLS-grense. En konto som mangler her blir '
      + 'usynlig for butikksjefen - og siden 506 er NEGATIV, blir tallet da '
      + 'for HOEYT, ikke for lavt. En stramming som gjoer et tall galt er '
      + 'verre enn hullet den lukket.\n',
    ).toEqual([])
  })

  test('KANARIFUGL: regelen ville tatt 506 slik den sto', () => {
    // Lista slik den var foer 506 ble lagt til - uttrykt i begrep.
    const somDenVar = new Set<string>(
      BUTIKKSJEF_BEGREP.filter((b) => b !== 'refundert_sykelonn'),
    )
    const b = begrepFor('506')
    expect(b, 'registeret kjenner ikke 506 lenger').toEqual(['refundert_sykelonn'])
    expect(
      b.every((x) => somDenVar.has(x)),
      'regelen ville IKKE sett at 506 manglet - da maaler den ingenting',
    ).toBe(false)
  })

  test('KANARIFUGL: loennskodene staar stille over epokeskiftet', () => {
    // Hele grunnen til at kallsteder fortsatt kan filtrere loennskonti
    // paa KODE. Flytter St1 en av dem, skal dette bli roedt foer noen
    // rekker aa stole paa antakelsen.
    const flyttet = [...BUTIKKSJEF_KOSTNAD_KODER]
      .filter((k) => Number(k) < 600)
      .filter((k) => registrertePar().some((p) => p.kode === k && p.epoke !== null))
      .sort()
    expect(
      flyttet,
      `Loennskontoene ${flyttet.join(', ')} har faatt en epoke i registeret. `
      + 'Da er de ikke lenger trygge aa filtrere paa kode, og kallstedene i '
      + 'lonnskost/ og kurs/ maa over paa begrep.',
    ).toEqual([])
  })

  test('personallista i begrep og i koder beskriver det samme', () => {
    const fraKoder = new Set(
      [...BUTIKKSJEF_KOSTNAD_KODER].filter((k) => Number(k) < 600).flatMap(begrepFor),
    )
    expect([...fraKoder].sort()).toEqual([...BUTIKKSJEF_PERSONAL_BEGREP].sort())
  })
})
