import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { Kjedestripe } from '@/app/(beskyttet)/lonnskost/kjedestripe'
import { hentKjede, type Stasjonsrad } from './a1-kjede'

// =====================================================================
// PRODUKSJONSKANARIFUGL — B2e.2 KJEDESTRIPE
//
// Kjoerer den faktiske kjeden mot ekte data som en ekte paalogget
// bruker, og rendrer den faktiske komponenten med resultatet.
//
// KREVER at brukeren selv setter KANARI_EPOST og KANARI_PASSORD.
// Passordet skal aldri staa i en fil og aldri i git.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD

/** Det vi vet om produksjon per 2026-09-16, etter Stig-klassifiseringen. */
const FASIT = {
  maaned: '2026-08',
  bonesKroner: 143889.14,
  bonesForklarteTimer: 68,
  bonesUprisete: 0,
}

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

const kjor = EPOST && PASSORD ? it : it.skip

describe('KANARIFUGL — kjedestripa mot produksjon', () => {
  kjor('hele stripa, med maaling', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    // RLS avgjoer settet. Samme spoerring som sida gjoer.
    const { data, error: sfeil } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer')
    if (sfeil) throw new Error(`stasjoner feilet: ${sfeil.message}`)
    const stasjoner = (data ?? []) as Stasjonsrad[]

    const kjede = await hentKjede(supabase, stasjoner)

    const html = renderToStaticMarkup(createElement(Kjedestripe, { kjede }))
    const tekst = html
      .replace(/<[^>]+>/g, '').replace(/+/g, ' | ')
      .replace(/ /g, ' ').replace(/&#x27;/g, "'").trim()

    const L = ['', '  KANARIFUGL — KJEDESTRIPE', '']
    L.push(`  autoriserte stasjoner ...... ${stasjoner.length}`)
    L.push(`  valgt maaned ............... ${kjede.maaned}`)
    L.push(`  sum ........................ ${JSON.stringify(kjede.sum)}`)
    L.push('')
    L.push('  RADER (i visningsrekkefolge):')
    for (const r of kjede.rader) {
      const k = r.kort
      L.push(
        `    ${r.butikknummer} ${r.navn.padEnd(14)}`
        + (k.status === 'kildemangel'
          ? `mangler: ${k.mangler}`
          : `${k.status}  ${k.kroner} kr  upriset ${k.upriseteTimer} t  forklart ${k.forklarteTimer} t`),
      )
    }
    L.push('')
    L.push('  RENDRET:')
    L.push(`  ${tekst}`)
    L.push('')
    L.push('  MAALING:')
    L.push(`    N stasjoner ............ ${kjede.maaling.stasjoner}`)
    L.push(`    rundturer .............. ${kjede.maaling.rundturer}  (5N+1 = ${5 * kjede.maaling.stasjoner + 1})`)
    L.push(`    motortid ............... ${kjede.maaling.motorMs} ms`)
    L.push(`    total stripetid ........ ${kjede.maaling.totaltMs} ms  (ekte I/O)`)
    L.push('')
    console.log(L.join('\n'))

    // ---- kontrakten ----
    expect(kjede.maaned).toBe(FASIT.maaned)

    const bones = kjede.rader.find((r) => r.navn.includes('Bønes'))
    if (!bones || bones.kort.status === 'kildemangel') {
      throw new Error('Boenes mangler eller har kildemangel — se loggen')
    }
    expect(bones.kort.kroner).toBe(FASIT.bonesKroner)
    expect(bones.kort.forklarteTimer).toBe(FASIT.bonesForklarteTimer)
    expect(bones.kort.upriseteTimer).toBe(FASIT.bonesUprisete)

    // Ingen stasjon er utelatt.
    expect(kjede.rader).toHaveLength(stasjoner.length)

    // Rekkefolgen: mangler foerst, ferdige sist.
    const grupper = kjede.rader.map((r) =>
      r.kort.status === 'kildemangel' ? 1 : r.kort.upriseteTimer > 0 ? 2 : 3)
    expect([...grupper].sort()).toEqual(grupper)

    // Ingen intern verdi lekker.
    for (const v of [
      'komplett', 'minimum', 'kildemangel', 'hele_kjeden', 'delvis',
      'ingen_grunnlag', 'ukjent_nummer', 'fastlonn_uten_register',
      'Vurdertrad', 'Uprisetgrunn', 'a1_registeroppslag',
    ]) expect(tekst.toLowerCase(), v).not.toContain(v.toLowerCase())

    expect(tekst.toLowerCase()).not.toContain('total lønnskost')
    expect(tekst).not.toContain('stasjon=alle')
    // Maalingen skal stemme med formelen.
    expect(kjede.maaling.rundturer).toBeLessThanOrEqual(5 * stasjoner.length + 1)
  }, 120000)
})
