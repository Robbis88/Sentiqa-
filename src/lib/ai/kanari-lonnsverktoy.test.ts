import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { hentLonnskostVerktoy, hentLonnsromVerktoy } from './lonnsverktoy'

// =====================================================================
// PRODUKSJONSKANARIFUGL — VERKTØYENE MOT MOTORENS EGNE TALL
//
// Enhetstestene beviser at kartleggingen bærer semantikken. Denne
// beviser at verktøyet gir SAMME TALL som A1-motoren ga i #304-porten:
// 143 889,14 kr for Bønes august, med 68 forklarte timer.
//
// Et velformulert svar med feil tall er rødt.
//
// KREVER KANARI_EPOST og KANARI_PASSORD. Passordet skal aldri i git.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD

/** Låst i #304, bevist fire ganger mot produksjon. */
const FASIT = {
  stasjon: '9467 St1 Bønes',
  maaned: '2026-08',
  sikkerhet: 'beregnet',
  kroner: 143889.14,
  forklarte_timer: 68,
  uprisede_timer: 0,
  innlaant_kr: 4758.33,
}

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

const kjor = EPOST && PASSORD ? it : it.skip

describe('KANARIFUGL — AI-verktøyene mot produksjon', () => {
  kjor('hent_lonnskost gir motorens egne tall', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)
    const bruker = { rolle: 'retailer_admin' } as never

    const a1 = await hentLonnskostVerktoy.kjor(
      { maaned: FASIT.maaned }, { supabase, bruker },
    ) as {
      status: string; komplett: boolean; kilder: string[]
      scope: { besvart: string[]; uten_registrering: string[] }
      data: Record<string, unknown>[]
    }

    const rom = await hentLonnsromVerktoy.kjor(
      { stasjoner: ['9467'], maaned: FASIT.maaned }, { supabase, bruker },
    ) as { status: string; data: Record<string, unknown>[] }

    const L = ['', '  KANARIFUGL — AI-VERKTØYENE', '']
    L.push(`  hent_lonnskost   status=${a1.status}  rader=${a1.data.length}`)
    L.push(`  kilder ......... ${JSON.stringify(a1.kilder)}`)
    L.push(`  besvart ........ ${JSON.stringify(a1.scope.besvart)}`)
    L.push(`  uten registr. .. ${JSON.stringify(a1.scope.uten_registrering)}`)
    for (const r of a1.data) L.push(`    ${JSON.stringify(r)}`)
    L.push('')
    L.push(`  hent_lonnsrom    status=${rom.status}  rader=${rom.data.length}`)
    for (const r of rom.data) L.push(`    ${JSON.stringify(r)}`)
    L.push('')
    console.log(L.join('\n'))

    const bones = a1.data.find((r) => r.stasjon === FASIT.stasjon)
    if (!bones) throw new Error('Bønes mangler i svaret — se loggen')

    expect(bones.sikkerhet).toBe(FASIT.sikkerhet)
    expect(bones.kroner).toBe(FASIT.kroner)
    expect(bones.forklarte_timer).toBe(FASIT.forklarte_timer)
    expect(bones.uprisede_timer).toBe(FASIT.uprisede_timer)
    expect(bones.innlaant_kr).toBe(FASIT.innlaant_kr)

    // EN STASJON UTEN GRUNNLAG BÆRER ALDRI EN KRONEVERDI.
    for (const r of a1.data) {
      if (r.sikkerhet === 'ingen_grunnlag') {
        expect(r.kroner, String(r.stasjon)).toBeNull()
        expect(r.mangler, String(r.stasjon)).toBeTruthy()
      }
    }
  }, 120000)
})
