import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  ALLE_ANALYSER, FORBEHOLD, forbehold, forbeholdForPeriode, kanVises,
} from './forbehold'
import { PARSERVERSJON, kjennerNivaamodellen, parsergrunnlag } from '@/lib/import/parserversjon'

// =====================================================================
// JUNI SKAL IKKE SPERRES GLOBALT
// =====================================================================
// De 48 kontrollerte stasjonsfeltene er identiske mellom de to
// juniversjonene. Forskjellen ligger i pant, linje 741 og samlet
// resultat — altså i klyngen og kjederesultatet, ikke i stasjonene.
// =====================================================================

const JUNI = '2026-06-01'

describe('juni 2026', () => {
  it('stasjonsnivå er OK — bevist identisk', () => {
    for (const a of ['stasjonsanalyse', 'mat_svinn_stasjon',
      'personalkost_stasjon', 'resultat_stasjon'] as const) {
      expect(forbehold(JUNI, a).status, a).toBe('ok')
      expect(kanVises(JUNI, a), a).toBe(true)
    }
  })

  it('klynge og kjederesultat er blokkert, med årsak', () => {
    for (const a of ['klyngeanalyse', 'kjederesultat'] as const) {
      const f = forbehold(JUNI, a)
      expect(f.status, a).toBe('blokkert')
      expect(f.aarsak).toMatch(/pant/)
      expect(f.aarsak).toMatch(/741/)
      expect(f.aarsak).toMatch(/13 101,49/)
      expect(kanVises(JUNI, a), a).toBe(false)
    }
  })

  it('KANARI: forbeholdet må ikke smitte til hele perioden', () => {
    // Den lette feilen er «juni er usikker» og sperr måneden. Da mister
    // butikksjefen sin egen stasjonsanalyse for en konflikt på
    // klyngearket hun ikke eier.
    const alle = forbeholdForPeriode(JUNI)
    const blokkerte = ALLE_ANALYSER.filter((a) => alle[a].status === 'blokkert')
    expect(blokkerte).toEqual(['klyngeanalyse', 'kjederesultat'])
  })

  it('andre perioder er urørt', () => {
    for (const a of ALLE_ANALYSER) {
      expect(forbehold('2026-07-01', a).status, a).toBe('ok')
      expect(forbehold('2026-05-01', a).status, a).toBe('ok')
    }
  })
})

describe('forbehold som datasett', () => {
  it('hver post har en årsak OG en utvei', () => {
    // Et forbehold uten utvei blir stående for alltid, og da slutter
    // folk å tro på dem.
    for (const p of FORBEHOLD) {
      expect(p.aarsak.length, p.periode).toBeGreaterThan(30)
      expect(p.loeses_av.length, p.periode).toBeGreaterThan(20)
      expect(p.gjelder.length, p.periode).toBeGreaterThan(0)
    }
  })

  it('ukjent periode og ukjent analyse er OK, ikke tvil', () => {
    expect(forbehold('2030-01-01', 'kjederesultat').status).toBe('ok')
    expect(forbehold(JUNI, 'stasjonsanalyse').aarsak).toBe('')
  })
})

describe('parserversjon', () => {
  it('er et navn, ikke et tidspunkt eller en hash', () => {
    expect(PARSERVERSJON).toBe('svinn-nivaa-1')
    // Et tidsstempel eller en hash ville endret seg uten at parseren
    // gjorde det, og «hvilke jobber har den nye modellen?» ville blitt
    // uleselig.
    expect(PARSERVERSJON).not.toMatch(/\d{4}-\d{2}-\d{2}/)
    expect(PARSERVERSJON).not.toMatch(/^[0-9a-f]{8,}$/)
  })

  it('gamle jobber er «eldre parsergrunnlag», ikke ukjente', () => {
    expect(parsergrunnlag(null)).toBe('eldre parsergrunnlag')
    expect(parsergrunnlag(PARSERVERSJON)).toBe(PARSERVERSJON)
    expect(kjennerNivaamodellen(null)).toBe(false)
    expect(kjennerNivaamodellen(PARSERVERSJON)).toBe(true)
  })

  it('importen skriver versjonen på jobben', () => {
    const kjerne = readFileSync(
      join(process.cwd(), 'src', 'lib', 'import', 'kjerne.ts'), 'utf8')
    expect(kjerne).toContain('parserversjon: PARSERVERSJON')
    expect(kjerne).toContain('avstemt_tid:')
    expect(kjerne).toContain('avviksantall:')
  })

  it('KANARI: aktivering krever bevis, ikke bare «parset»', () => {
    const sql = readFileSync(join(process.cwd(), 'supabase', 'migrations',
      '0211_aktivering_krever_bevis.sql'), 'utf8')
    // Fem porter. Faller én ut, kan en uavstemt jobb bli synlig.
    expect(sql).toContain('mangler parserversjon')
    expect(sql).toContain('er ikke avstemt')
    expect(sql).toContain('avviksantall = %')
    expect(sql).toContain('ingen grupperader')
    expect(sql).toContain('kontrollen av usynlig svinn')
    // Gamle aktive jobber skal IKKE miste flagget av at dette kjøres.
    expect(sql).not.toMatch(/update public\.import_jobber\s+set aktiv = false/)
  })
})
