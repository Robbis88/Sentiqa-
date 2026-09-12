import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { BUTIKKSJEF_BEGREP } from '@/lib/regnskap-tilgang'

// =====================================================================
// LISTA I POLICYEN OG LISTA I KODEN SKAL VAERE DEN SAMME
// =====================================================================
//
// Policyene har begrepene inline fordi en policy ikke kan importere en
// TypeScript-modul. Da finnes lista to steder, og to lister som skal
// vaere like driver fra hverandre - det skjedde mellom
// `rls_vakthund.sql` og `rls_funn.sql` i august, og den lesbare utgaven
// loey om tabeller som var i orden i maanedsvis.
//
// FRA `0203` ER DET TO POLICYER MED SAMME LISTE: `bilagssum` (bilagene)
// og `regnskapslinjer` (rapportlinjene). Begge leses her. `0199` er
// kjoert og roeres ikke - `0203` definerer bilagssum-policyen paa nytt,
// og det er DEN utgaven som gjelder.
//
// VIKTIGST: policyene er TILGANGSGRENSER. Et begrep som sniker seg inn
// der uten aa staa i koden er en kostnad butikksjefen ser uten at noen
// har bestemt det.
// =====================================================================

const SQL = join(process.cwd(), 'supabase', 'migrations', '0203_begrepet_ikke_koden.sql')

/** Fila uten `--`-kommentarer. Et navn nevnt i en forklaring er ikke et filter. */
function renSql(): string {
  // `[^\n]` og ikke `.` fordi `.` ikke matcher `\r`, og fila sjekkes ut
  // med CRLF paa Windows - se crlf-notatet i AGENTS.md-sporet.
  return readFileSync(SQL, 'utf8')
    .split('\n')
    .map((l) => l.replace(/--[^\n]*$/, ''))
    .join('\n')
}

/** Navnene i hvert `array[...]`-uttrykk etter `begrep = any`. */
function begrepslister(): string[][] {
  const blokker = [...renSql().matchAll(/begrep\s*=\s*any\s*\(\s*array\[([\s\S]*?)\]/gi)]
  if (blokker.length === 0) throw new Error('fant ingen begrep-lister i 0203')
  return blokker.map((m) => [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]))
}

describe('begrepslistene i 0203 og i regnskap-tilgang.ts', () => {
  it('BEGGE policyene har den samme lista, i samme rekkefoelge', () => {
    // `bilagssum` og `regnskapslinjer`. Skiller de to lag, ser
    // butikksjefen ulike kostnader avhengig av om tallet kom fra
    // bilagene eller fra rapportlinja - og ingen av dem ser feil ut.
    for (const liste of begrepslister()) {
      expect(liste).toEqual([...BUTIKKSJEF_BEGREP])
    }
  })

  it('KANARI: uttrekket finner faktisk BEGGE listene', () => {
    // En regex som slutter aa treffe gir tom liste mot tom liste, og da
    // maaler testen over ingenting. Samme felle som CRLF-en tok tre
    // ganger i dette prosjektet. Og finner den bare EN liste, staar den
    // andre policyen uvoktet.
    const lister = begrepslister()
    expect(lister.length, 'fant ikke begge begrep-listene i 0203').toBe(2)
    for (const l of lister) {
      expect(l.length).toBeGreaterThanOrEqual(15)
      expect(l).toContain('renhold')
    }
  })

  it('KANARI: «leie_driftsmidler» staar ikke i noen av dem', () => {
    // Det er det 628 betydde foer februar 2026. Slipper den inn, ser
    // butikksjefen leasingkostnaden paa enhver rad fra den epoken - og
    // etter 0203 importeres nettopp slike rader.
    for (const l of begrepslister()) expect(l).not.toContain('leie_driftsmidler')
  })

  it('KANARI: den sammenslaatte renholdslinja ER med', () => {
    // `renhold_og_renovasjon` er 627 fra foer februar 2026, siden
    // splittet i 627 Renhold og 628 Renovasjon. Begge delene er
    // butikksjefens. Utelates unionen, forsvinner hele renholdskostnaden
    // for hver maaned foer skiftet - og en kostnad som mangler ser ut som
    // en kostnad som er null.
    for (const l of begrepslister()) expect(l).toContain('renhold_og_renovasjon')
  })

  it('begge policyene krever at begrep ikke er null', () => {
    // NULL = vi kjente ikke igjen paret (kode, navn), eller raden ble
    // skrevet foer 0203. Ukjent skal bety SKJULT, ikke synlig.
    //
    // Maalt INNE I hver policykropp, ikke paa fila: etterfyllingen og
    // kvitteringen nevner ogsaa `begrep`, og en telling over hele fila
    // ville blitt groenn av feil grunn.
    const kropper = [...renSql().matchAll(/create policy[\s\S]*?;/gi)]
      .map((m) => m[0])
      .filter((k) => /begrep\s*=\s*any/i.test(k))
    expect(kropper.length, 'fant ikke begge policykroppene').toBe(2)
    for (const k of kropper) {
      expect(k, 'en policy godtar begrep = null').toMatch(/begrep\s+is\s+not\s+null/i)
    }
  })

  it('KANARI: kroppsuttrekket ville sett en policy uten null-sjekken', () => {
    // Uten denne kunne filteret over gitt tom liste, og loekka ikke
    // sjekket noe som helst.
    const falsk = "create policy p on t using (begrep = any (array['renhold']));"
    const kropper = [...falsk.matchAll(/create policy[\s\S]*?;/gi)].map((m) => m[0])
    expect(kropper.length).toBe(1)
    expect(kropper[0]).not.toMatch(/begrep\s+is\s+not\s+null/i)
  })
})
