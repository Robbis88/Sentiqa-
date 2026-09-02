import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { DUBLETT } from '@/lib/db-koder'

// =====================================================================
// EN KVITTERING SKAL SI HVA SOM FAKTISK SKJEDDE
//
// `bekreftLest` svarte «Takk - registrert» ogsaa naar innsettingen ble
// avvist som dublett. Paa nettbrettet var det ikke et kanttilfelle, men
// det NORMALE: lesepolicyen i `0147` slipper ikke nettbrettet til paa
// sine egne rader - den matcher `bruker_id`, nettbrettet skriver
// `ansatt_id` - saa sida spoer hver gang, og fikk «registrert» hver gang
// uten at noe ble skrevet.
//
// Se [[sentiqa-handling-kvitterer]]. Her er formen speilvendt: ikke en
// handling som lykkes uten aa si fra, men en som sier fra om noe den
// ikke gjorde.
//
// LESER KILDEN. Handlingen kaller `hentInnloggetBruker` og Supabase, og
// kan ikke kjoeres i vitest uten aa bygge halve appen. Det som maa
// vaktes er ikke rundskrivet, men de to valgene: at dubletten kjennes
// paa KODEN og at den faar sin egen kvittering.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'mine-opplysninger', 'handlinger.ts'),
  'utf8',
)

/** Uten kommentarene - de omtaler nettopp det vi leter etter. */
const kode = KILDE.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '')

describe('bekreftLest kvitterer ærlig', () => {
  test('KANARIFUGL: kilden lar seg lese, og kommentarene er strippet', () => {
    // Treffer ikke strippingen, leser hver paastand under prosaen i stedet
    // for koden - og da beviser de ingenting.
    expect(kode.length).toBeGreaterThan(400)
    expect(kode).toContain('bekreftLest')
    expect(kode, 'kommentarene ble ikke fjernet').not.toContain('KVITTERING')
  })

  test('dubletten kjennes på feilkoden, ikke på meldingsteksten', () => {
    // `error.message.includes('duplicate')` sto her. Det er engelsk
    // PostgREST-prosa som kan endres uten varsel, og blir den det, faar
    // den ansatte en raa databasefeil paa en helt normal handling.
    expect(DUBLETT).toBe('23505')
    expect(kode, 'leser fortsatt meldingsteksten').not.toMatch(/message\.includes\(['"]duplicate/)
    expect(kode, 'sammenligner ikke mot feilkoden').toMatch(/error\.code\s*!==\s*DUBLETT/)
  })

  test('en dublett og en ny rad gir IKKE samme svar', () => {
    // Selve saken. To ulike utfall skal ikke kvitteres likt.
    const svar = [...kode.matchAll(/ok:\s*'([^']+)'/g)].map((m) => m[1])
    expect(svar.length, 'fant ikke begge kvitteringene').toBeGreaterThanOrEqual(2)
    expect(new Set(svar).size, 'de to utfallene gir samme tekst').toBe(svar.length)
  })

  test('en ekte feil returneres fortsatt som feil', () => {
    // Dubletten skal ikke ha gjort hele feilhaandteringen mild.
    expect(kode).toMatch(/return \{ feil: error\.message \}/)
  })
})
