import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { BUTIKKSJEF_BEGREP } from '@/lib/regnskap-tilgang'

// =====================================================================
// LISTA I POLICYEN OG LISTA I KODEN SKAL VAERE DEN SAMME
// =====================================================================
//
// Policyene har begrepene inline fordi en policy ikke kan importere en
// TypeScript-modul. Da finnes lista flere steder, og lister som skal
// vaere like driver fra hverandre - det skjedde mellom `rls_vakthund.sql`
// og `rls_funn.sql` i august, og den lesbare utgaven loey om tabeller som
// var i orden i maanedsvis.
//
// I dag er det to policyer med lista: `bilagssum` (bilagene) og
// `regnskapslinjer` (rapportlinjene).
//
// ---------------------------------------------------------------------
// TESTEN PEKER IKKE PAA EN FIL. DEN LETER.
//
// Foerste utgave leste `0199_bilagssum.sql`. Saa kom `0203` og definerte
// bilagssum-policyen paa nytt - fila var utdatert samme dag. Andre
// utgave leste `0203`, og `0204` gjorde det samme med
// regnskapslinjer-policyen én time senere.
//
// **En vakt som peker paa et filnavn blir utdatert av neste migrasjon,
// og den blir det i stillhet** - den fortsetter aa maale en gammel
// definisjon og sier at alt er i orden. Derfor leses hele katalogen, og
// SISTE definisjon av hver policy er den som gjelder. Det er samme regel
// migrasjonene selv foelger: hele settet kjoeres fra bunn, og den siste
// vinner.
//
// VIKTIGST: policyene er TILGANGSGRENSER. Et begrep som sniker seg inn
// der uten aa staa i koden er en kostnad butikksjefen ser uten at noen
// har bestemt det.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/** Siste definisjon av hver policy, uten `--`-kommentarer. */
function sistePolicyer(): Map<string, string> {
  const ut = new Map<string, string>()
  for (const fil of readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()) {
    // `[^\n]` og ikke `.` fordi `.` ikke matcher `\r`, og filene sjekkes
    // ut med CRLF paa Windows - se crlf-notatet i AGENTS.md-sporet.
    const ren = readFileSync(join(KATALOG, fil), 'utf8')
      .split('\n')
      .map((l) => l.replace(/--[^\n]*$/, ''))
      .join('\n')
    for (const m of ren.matchAll(/create policy\s+(\w+)[\s\S]*?;/gi)) {
      ut.set(m[1], m[0])
    }
  }
  return ut
}

/** Policyene som baerer begrepslista, med lista pakket ut. */
function begrepspolicyer(): Map<string, string[]> {
  const ut = new Map<string, string[]>()
  for (const [navn, sql] of sistePolicyer()) {
    const m = /begrep\s*=\s*any\s*\(\s*array\[([\s\S]*?)\]/i.exec(sql)
    if (!m) continue
    ut.set(navn, [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]))
  }
  return ut
}

describe('begrepslistene i policyene og i regnskap-tilgang.ts', () => {
  it('HVER policy har den samme lista, i samme rekkefoelge', () => {
    // Skiller to lag, ser butikksjefen ulike kostnader avhengig av om
    // tallet kom fra bilagene eller fra rapportlinja - og ingen av dem
    // ser feil ut.
    for (const [navn, liste] of begrepspolicyer()) {
      expect(liste, `${navn} har en annen begrepsliste`).toEqual([...BUTIKKSJEF_BEGREP])
    }
  })

  it('KANARI: uttrekket finner BEGGE policyene', () => {
    // En regex som slutter aa treffe gir tom liste mot tom liste, og da
    // maaler testen over ingenting. Samme felle som CRLF-en tok tre
    // ganger i dette prosjektet. Finner den bare EN, staar den andre
    // uvoktet.
    const p = begrepspolicyer()
    expect([...p.keys()].sort()).toEqual(['bilagssum_les_butikksjef', 'regnskapslinjer_les'])
    for (const [navn, l] of p) {
      expect(l.length, navn).toBeGreaterThanOrEqual(15)
      expect(l, navn).toContain('renhold')
    }
  })

  it('KANARI: det er SISTE definisjon som leses', () => {
    // 0192 definerte `regnskapslinjer_les` med koder og uten begrep i
    // det hele tatt. Leser vakten den, er alt groent og ingenting maalt.
    const sql = sistePolicyer().get('regnskapslinjer_les') ?? ''
    expect(sql, 'vakten leser en definisjon uten begrepsliste').toMatch(/begrep\s*=\s*any/i)
    expect(sql, 'vakten leser en definisjon fra foer 0204').toMatch(/bp_kostnad/)
  })

  it('KANARI: «leie_driftsmidler» staar ikke i noen av dem', () => {
    // Det er det 628 betydde foer februar 2026. Slipper den inn, ser
    // butikksjefen leasingkostnaden paa enhver rad fra den epoken - og
    // fra 0203 importeres nettopp slike rader.
    for (const [navn, l] of begrepspolicyer()) expect(l, navn).not.toContain('leie_driftsmidler')
  })

  it('KANARI: den sammenslaatte renholdslinja ER med', () => {
    // `renhold_og_renovasjon` er 627 fra foer februar 2026, siden
    // splittet i 627 Renhold og 628 Renovasjon. Begge delene er
    // butikksjefens. Utelates unionen, forsvinner hele renholdskostnaden
    // for hver maaned foer skiftet - og en kostnad som mangler ser ut som
    // en kostnad som er null.
    for (const [navn, l] of begrepspolicyer()) expect(l, navn).toContain('renhold_og_renovasjon')
  })

  it('hver av dem krever at begrep ikke er null', () => {
    // NULL = vi kjente ikke igjen paret (kode, navn), eller raden ble
    // skrevet foer 0203. Ukjent skal bety SKJULT, ikke synlig.
    const alle = sistePolicyer()
    for (const navn of begrepspolicyer().keys()) {
      expect(alle.get(navn), `${navn} godtar begrep = null`)
        .toMatch(/begrep\s+is\s+not\s+null/i)
    }
  })

  it('KANARI: null-sjekken ville sett en policy uten den', () => {
    // Uten denne kunne loekka over vaert tom, eller regexen doed.
    expect(/begrep\s+is\s+not\s+null/i.test("using (begrep = any (array['renhold']))"))
      .toBe(false)
  })
})
