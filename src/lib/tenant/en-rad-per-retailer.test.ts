import { describe, it, expect } from 'vitest'
import { valider, type Ressurs } from './kontrakt'
import { genererMatrise } from './generer'

// =====================================================================
// GENERATORANTAKELSEN `en_rad_per_retailer`, BEVIST DIREKTE
//
// Husregelen: når generatoren har en strukturell antakelse som påvirker
// flere kallsteder, skal antakelsen ha en rask direkte test — ikke full
// CI som første detektor. `id_kolonne` satt fire steder og ble funnet
// gjennom tre CI-kjøringer på fire minutter hver; den fjerde ble funnet
// på millisekunder av en test som beviste regelen.
//
// Dette er den fjerde i familien:
//
//   id_kolonne            hva som identifiserer én rad
//   business_unik         hva som gjør to rader forskjellige
//   en_rad_per_stasjon    hvor mange rader som kan finnes, per stasjon
//   en_rad_per_retailer   ... per kjede
//
// Alle fire er antakelser om SKJEMAETS FORM, ikke om autorisasjon — og
// det er derfor de gjemmer seg. En autorisasjonsfeil gir 42501 og roper.
// En formfeil gir 23505 og later som den er en avvisning.
//
// ---------------------------------------------------------------------
// HVORFOR EN SYNTETISK RESSURS OG IKKE `retailer_kodeerklaering`
//
// Testes primitivet gjennom den ene tabellen som bruker det, måler den
// to ting på én gang: at flagget virker, og at akkurat den tabellen er
// riktig klassifisert. Slutter tabellen å bruke flagget, slutter testen
// å måle primitivet — uten å bli rød.
//
// Ressursen under finnes bare her.
// =====================================================================

/** Én rad per kjede, uten en eneste kolonne som kan variere. */
function enPerKjede(over: Partial<Ressurs> = {}): Ressurs {
  return {
    tabell: 'sonde_en_per_kjede',
    $hvorfor: 'Syntetisk ressurs som bare finnes i denne testen. Beviser '
      + 'generatorsemantikken for en_rad_per_retailer uten aa vaere avhengig '
      + 'av at en ekte tabell fortsetter aa bruke flagget.',
    tenant_scope: 'retailer',
    data_class: 'warm',
    operasjoner: ['select', 'insert', 'update', 'delete'],
    tablet: { select: 'retailer' },
    manager: { select: 'retailer' },
    owner: { select: 'retailer', insert: 'retailer', update: 'retailer', delete: 'retailer' },
    proberad: { merke: "'sonde'" },
    business_unik: ['retailer_id'],
    en_rad_per_retailer: true,
    oppdaterbart: "merke = 'endret'",
    ...over,
  } as Ressurs
}

/** De distinkte radene fixturen faktisk holder for tabellen. */
function distinkteIder(sql: string): string[] {
  const ider = [...sql.matchAll(
    /insert into public\.sonde_en_per_kjede \(id, [^)]*\) values \('([0-9a-f-]+)'/g)]
    .map((m) => m[1])
  return [...new Set(ider)]
}

const kontrakt = (r: Ressurs) => ({
  $kommentar: 'Bare i denne testen.',
  uklassifisert_tillatt: { $kommentar: 'tom', tabeller: [] },
  ressurser: [r],
} as unknown as Parameters<typeof valider>[0])

describe('kontrakten godtar én rad per kjede', () => {
  it('validerer uten unntak og uten varierende kolonne', () => {
    // Poenget med hele primitivet: en tabell der INGEN forretningskolonne
    // kan variere mellom to forsøk skal kunne beskrives ærlig, uten et
    // business_unik_unntak som bare er en kvittering på at vi ga opp.
    expect(valider(kontrakt(enPerKjede()))).toEqual([])
  })

  it('godtar også tom business_unik', () => {
    expect(valider(kontrakt(enPerKjede({ business_unik: undefined })))).toEqual([])
  })
})

describe('flagget er en smal kontrakt, ikke en vei forbi validatoren', () => {
  it('avvises når en forretningskolonne kan finnes i tillegg', () => {
    // DETTE ER DEN VIKTIGSTE PÅSTANDEN I FILA. Nevner business_unik en
    // kolonne utover retailer_id, tillater skjemaet per definisjon flere
    // rader per kjede — og da ville flagget fått generatoren til å slutte
    // å teste noe den burde testet, i stillhet.
    const feil = valider(kontrakt(enPerKjede({ business_unik: ['retailer_id', 'merke'] })))
    const treff = feil.filter((f) => /en_rad_per_retailer, men business_unik nevner/.test(f))
    expect(treff, `ingen klage paa flagget. Alle feil: ${feil.join(' | ')}`).toHaveLength(1)
    expect(treff[0], 'feilmeldingen sier ikke hva som er galt').toMatch(/FLERE rader per kjede/)
  })

  it('avvises på feil tenant_scope', () => {
    // Plassen er kjeden, så kjeden må være scopet. En stasjonsscopet
    // tabell har ingen «én per kjede» å snakke om.
    const feil = valider(kontrakt(enPerKjede({
      tenant_scope: 'station', tablet: 'none', manager: 'none',
      owner: { select: 'own_station', insert: 'own_station', update: 'own_station', delete: 'own_station' },
    })))
    expect(feil.some((f) => /krever tenant_scope retailer/.test(f))).toBe(true)
  })

  it('avvises sammen med en_rad_per_stasjon', () => {
    const feil = valider(kontrakt(enPerKjede({ en_rad_per_stasjon: true })))
    expect(feil.some((f) => /utelukker\s+hverandre/.test(f))).toBe(true)
  })

  it('avvises sammen med fast_rad', () => {
    const feil = valider(kontrakt(enPerKjede({ fast_rad: '{{retailer}}' })))
    expect(feil.some((f) => /fast_rad utelukker hverandre/.test(f))).toBe(true)
  })
})

describe('generatoren lager fortsatt en meningsfull isolasjonstest', () => {
  const sql = genererMatrise(kontrakt(enPerKjede()))

  it('holder ÉN rad per kjede - to distinkte i alt', () => {
    // Uten dette ville seedingen selv gitt 23505 - kjede A har tre
    // stasjoner - og hele matrisen falt over foer noen paastand ble maalt.
    //
    // Tellingen gaar paa DISTINKTE id-er, ikke paa antall `insert`:
    // matrisen setter den samme raden tilbake etter hvert forsoek, saa
    // setningene er mange mens radene er to.
    expect(distinkteIder(sql), 'flere enn to rader - da er plassen stasjonen, ikke kjeden')
      .toHaveLength(2)
  })

  it('frigjør plassen på retailer_id, ikke stasjon_id', () => {
    expect(sql).toMatch(/delete from public\.sonde_en_per_kjede where retailer_id =/)
    expect(sql, 'sletter fortsatt paa stasjon - da er plassen feil')
      .not.toMatch(/delete from public\.sonde_en_per_kjede where stasjon_id =/)
  })

  it('lager ingen nyrad-hjelper', () => {
    // Hjelperen lager en FERSK rad før hver update/delete. Med plass til
    // én ville rad nummer to kollidert.
    expect(sql).not.toMatch(/nyrad_sonde_en_per_kjede/)
  })

  it('KANARIFUGL: en vanlig ressurs seeder fortsatt fem rader', () => {
    // Uten denne kunne «to seedede rader» vært sant fordi generatoren
    // sluttet å seede i det hele tatt — og hver påstand over ville
    // bestått mens fixturen var tom.
    const vanlig = genererMatrise(kontrakt(enPerKjede({
      en_rad_per_retailer: undefined,
      business_unik: ['merke'],
      proberad: { merke: "'sonde {{unik}}'" },
    })))
    expect(distinkteIder(vanlig).length,
      'en vanlig ressurs skal ha en rad per stasjon').toBeGreaterThanOrEqual(5)
    expect(vanlig, 'en vanlig ressurs skal ha nyrad-hjelper')
      .toMatch(/nyrad_sonde_en_per_kjede/)
  })
})

describe('den andre kjeden er fortsatt isolert', () => {
  const sql = genererMatrise(kontrakt(enPerKjede()))

  it('begge kjedene har sin egen ene rad', () => {
    // «Ser ingen andres rad» er en tom seier hvis den andre kjeden ikke
    // har noen. Begge retailer-id-ene må stå i fixturen.
    const kjeder = [...sql.matchAll(/'(aaaa|bbbb)[0-9a-f-]*'/g)].map((m) => m[1])
    expect(new Set(kjeder).size,
      'bare én kjede seedet - da beviser isolasjonspaastandene ingenting').toBe(2)
  })
})
