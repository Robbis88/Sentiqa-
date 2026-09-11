import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { BUTIKKSJEF_BEGREP } from '@/lib/regnskap-tilgang'

// =====================================================================
// LISTA I POLICYEN OG LISTA I KODEN SKAL VAERE DEN SAMME
// =====================================================================
//
// `0199` har begrepene inline i policyen fordi en policy ikke kan
// importere en TypeScript-modul. Da finnes lista to steder, og to lister
// som skal vaere like driver fra hverandre - det skjedde mellom
// `rls_vakthund.sql` og `rls_funn.sql` i august, og den lesbare utgaven
// loey om tabeller som var i orden i maanedsvis.
//
// Denne testen er billig og deterministisk, og gjoer at lista i praksis
// bare finnes ett sted: endrer du den ene, maa du endre den andre.
//
// VIKTIGST: policyen er en TILGANGSGRENSE. Et begrep som sniker seg inn
// der uten aa staa i koden er en kostnad butikksjefen ser uten at noen
// har bestemt det.
// =====================================================================

const SQL = join(process.cwd(), 'supabase', 'migrations', '0199_bilagssum.sql')

/** Navnene i `array[...]`-uttrykket etter `begrep = any`. */
function begrepIPolicy(): string[] {
  // `--`-kommentarer strippes foerst. Uten det teller navn nevnt i en
  // forklaring. `[^\n]` og ikke `.` fordi `.` ikke matcher `\r`, og fila
  // sjekkes ut med CRLF paa Windows - se crlf-notatet i AGENTS.md-sporet.
  const sql = readFileSync(SQL, 'utf8')
    .split('\n')
    .map((l) => l.replace(/--[^\n]*$/, ''))
    .join('\n')
  const m = /begrep\s*=\s*any\s*\(\s*array\[([\s\S]*?)\]/i.exec(sql)
  if (!m) throw new Error('fant ikke begrep-lista i 0199')
  return [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1])
}

describe('begrepslista i 0199 og i regnskap-tilgang.ts', () => {
  it('er den samme, i samme rekkefoelge', () => {
    expect(begrepIPolicy()).toEqual([...BUTIKKSJEF_BEGREP])
  })

  it('KANARI: uttrekket finner faktisk noe', () => {
    // En regex som slutter aa treffe gir tom liste mot tom liste, og da
    // maaler testen over ingenting. Samme felle som CRLF-en tok tre
    // ganger i dette prosjektet.
    expect(begrepIPolicy().length).toBeGreaterThanOrEqual(15)
    expect(begrepIPolicy()).toContain('renhold')
  })

  it('KANARI: «leie_driftsmidler» staar ikke i policyen', () => {
    // Det er det 628 betydde foer februar 2026. Slipper den inn, ser
    // butikksjefen leasingkostnaden paa enhver rad fra den epoken.
    expect(begrepIPolicy()).not.toContain('leie_driftsmidler')
  })

  it('policyen krever at begrep ikke er null', () => {
    // NULL = vi kjente ikke igjen paret (kode, navn), typisk en rad fra
    // det gamle skjemaet. Ukjent skal bety SKJULT, ikke synlig.
    const sql = readFileSync(SQL, 'utf8')
    expect(sql).toMatch(/begrep\s+is\s+not\s+null/i)
  })
})
