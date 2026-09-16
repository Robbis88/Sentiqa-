import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { Arbeidsstedsblokk } from '@/app/(beskyttet)/lonnskost/arbeidsstedsblokk'
import { hentA1Maaneder } from './a1-maaneder'
import { hentKilder } from './kilder'
import { hentAvtaler } from './avtale'
import { a1ForStasjonsmaaned } from './a1'
import { tilA1Kort } from './a1-kort'

// =====================================================================
// PRODUKSJONSKANARIFUGL - B2e.1, Boenes 2026-08
//
// Kjoerer NOEYAKTIG kjeden fra src/app/(beskyttet)/lonnskost/page.tsx
// linje 459-466, mot ekte produksjonsdata, som en ekte paalogget bruker.
//
// Eneste forskjell fra sida: sida kaster motorresultatet etter mapping.
// Her holdes det, fordi det er DE raa tallene som skal sammenlignes.
//
// Ingen kodeendring i B2e.1. Denne fila kaller - den endrer ingenting.
//
// KREVER at brukeren selv setter KANARI_EPOST og KANARI_PASSORD.
// Passordet skal aldri staa i en fil og aldri i git.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD
const STASJONSNAVN = process.env.KANARI_STASJON ?? 'St1 Bønes'
const MAANED = process.env.KANARI_MAANED ?? '2026-08'

// =====================================================================
// TO LAASTE FASITER, OG MENNESKET VELGER HVILKEN
//
// `KANARI_FASE=etter` naar (Boenes, 1004, fastlonn) ER skrevet.
// Standard er `foer`.
//
// Fasen er en PARAMETER, ikke noe som utledes av dataene. Leste
// kanarifuglen `ansatt_avtale` for aa avgjoere hvilken fasit som
// gjelder, ville den bekreftet seg selv: enhver tilstand ville vaert
// «riktig», og beviset hadde vaert verdiloest.
//
// BEGGE er skrevet ned FOER rettingen ble bygget. Ingen krone flytter
// seg mellom dem - bare klassifiseringen av 4 080 minutter.
// =====================================================================
const FASE = process.env.KANARI_FASE === 'etter' ? 'etter' : 'foer'

const FELLES = {
  kroner: 143889.14,
  betalteMinutter: 41926,
  prisedeMinutter: 37846,
  innlaantKr: 4758.33,
  dubletter: 0,
  helligdagstimer1410: 0,
  /** Stigs ti vakter. Flytter seg mellom utfall, aldri i antall. */
  stig1004Minutter: 4080,
  stig1004Vakter: 10,
}

const FASIT = FASE === 'etter'
  ? {
    ...FELLES,
    status: 'komplett',
    forklarteMinutter: 4080,
    uprisedeMinutter: 0,
    /** Stigs vakter skal ha byttet utfall - aldri til `priset`. */
    stigSlag: 'forklart' as const,
  }
  : {
    ...FELLES,
    status: 'minimum',
    forklarteMinutter: 0,
    uprisedeMinutter: 4080,
    stigSlag: 'upriset' as const,
  }

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

type Kall = { slag: 'from' | 'rpc'; navn: string; ms: number }

/** Teller rundturer uten aa endre oppfoerselen. */
function tellende(k: SupabaseClient, logg: Kall[]): SupabaseClient {
  return new Proxy(k, {
    get(mål, felt, mottaker) {
      if (felt === 'from') {
        return (tabell: string) => {
          logg.push({ slag: 'from', navn: tabell, ms: performance.now() })
          return (mål.from as (t: string) => unknown)(tabell)
        }
      }
      if (felt === 'rpc') {
        return (navn: string, args: unknown) => {
          logg.push({ slag: 'rpc', navn, ms: performance.now() })
          return (mål.rpc as (n: string, a: unknown) => unknown)(navn, args)
        }
      }
      return Reflect.get(mål, felt, mottaker)
    },
  })
}

const kjor = EPOST && PASSORD ? it : it.skip

describe('KANARIFUGL — Boenes 2026-08 gjennom den faktiske B2e.1-kjeden', () => {
  kjor('motorens raa tall er identiske med den laaste fasiten', async () => {
    const raa = createClient(env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'))
    const { error: innloggingsfeil } = await raa.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (innloggingsfeil) throw new Error(`Innlogging feilet: ${innloggingsfeil.message}`)

    const logg: Kall[] = []
    const supabase = tellende(raa, logg)

    // Stasjonen slaas opp slik sida gjoer det: gjennom RLS, paa navn.
    const { data: stasjoner, error: sfeil } = await supabase
      .from('stasjoner').select('id, navn').is('slettet_tid', null)
    if (sfeil) throw new Error(`stasjoner feilet: ${sfeil.message}`)
    const stasjon = (stasjoner ?? []).find((s) => s.navn === STASJONSNAVN)
    if (!stasjon) {
      throw new Error(
        `Fant ikke «${STASJONSNAVN}». RLS ga: ${JSON.stringify((stasjoner ?? []).map((s) => s.navn))}`,
      )
    }

    // ===== KJEDEN, ORDRETT FRA page.tsx 459-466 =====
    const t0 = performance.now()
    const a1Maaneder = await hentA1Maaneder(supabase, stasjon.id)
    const a1Avtale = a1Maaneder.length > 0
      ? await hentAvtaler(supabase, [stasjon.id])
      : null

    const treff = a1Maaneder.filter((m) => m === MAANED)
    const kilder = await hentKilder(supabase, stasjon.id, MAANED)
    const tMotor = performance.now()
    const res = a1ForStasjonsmaaned(kilder, a1Avtale!)
    const motortid = performance.now() - tMotor
    const kort = tilA1Kort(res)
    const total = performance.now() - t0
    // ================================================

    const L: string[] = ['', `  KANARIFUGL  ${STASJONSNAVN}  ${MAANED}`, '']
    L.push(`  hentA1Maaneder .............. ${JSON.stringify(a1Maaneder)}`)
    L.push(`  kildestatus ................. ${kilder.status}`)
    L.push('')

    if (res.status === 'kildemangel') {
      L.push(`  STATUS = kildemangel (${res.kilde.status}) — ingen tall aa sammenligne`)
      console.log(L.join('\n'))
      throw new Error('kildemangel — se loggen over')
    }

    // KRONENE, uansett status. `minimum503Kr` og `konto503Kr` er samme
    // tall under to navn; at de er like er selve poenget med porten.
    const kroner = res.status === 'minimum' ? res.minimum503Kr : res.konto503Kr

    // `1004` er Stigs ANSATTNUMMER, ikke en loennsart. Han bevises
    // gjennom sine egne rader, aldri gjennom perArt.
    const art1410 = res.perArt['1410']
    const stigs = res.rader.filter((v) => v.rad.ansattNr === '1004')
    const stigMinutter = stigs.reduce((s, v) => s + v.rad.minutter, 0)
    const stigSlag = [...new Set(stigs.map((v) => v.utfall.slag))]

    const rad = (navn: string, forventet: unknown, faktisk: unknown) => {
      const lik = JSON.stringify(forventet) === JSON.stringify(faktisk)
      const diff = typeof forventet === 'number' && typeof faktisk === 'number'
        ? (faktisk - forventet).toFixed(10).replace(/0+$/, '0')
        : (lik ? '-' : 'ULIK')
      L.push(
        `  ${navn.padEnd(24)}${String(forventet).padStart(14)}`
        + `${String(faktisk).padStart(16)}   ${lik ? 'OK' : `AVVIK ${diff}`}`,
      )
      return lik
    }

    L.push('  felt                        forventet         faktisk   ')
    L.push('  ' + '-'.repeat(66))
    const ok: boolean[] = []
    ok.push(rad('status', FASIT.status, res.status))
    ok.push(rad('kroner (503)', FASIT.kroner, kroner))
    ok.push(rad('betalteMinutter', FASIT.betalteMinutter, res.betalteMinutter))
    ok.push(rad('prisedeMinutter', FASIT.prisedeMinutter, res.prisedeMinutter))
    ok.push(rad('forklarteMinutter', FASIT.forklarteMinutter, res.forklarteMinutter))
    ok.push(rad('uprisedeMinutter', FASIT.uprisedeMinutter, res.uprisedeMinutter))
    ok.push(rad('innlaantKr', FASIT.innlaantKr, res.innlaantKr))
    ok.push(rad('dubletter', FASIT.dubletter, res.dubletter))
    ok.push(rad('1004 minutter', FASIT.stig1004Minutter, stigMinutter))
    ok.push(rad('1004 vakter', FASIT.stig1004Vakter, stigs.length))
    ok.push(rad('1004 utfall', [FASIT.stigSlag], stigSlag))
    ok.push(rad('1410 timer', FASIT.helligdagstimer1410, art1410?.timer ?? 0))
    L.push('  ' + '-'.repeat(66))

    const sum = res.prisedeMinutter + res.forklarteMinutter + res.uprisedeMinutter
    L.push(`  BEVARING  ${res.prisedeMinutter} + ${res.forklarteMinutter} `
      + `+ ${res.uprisedeMinutter} = ${sum}  (betalte: ${res.betalteMinutter})`
      + `  ${sum === res.betalteMinutter ? 'OK' : 'BRUDD'}`)
    L.push('')
    L.push(`  innlaanteNr ................. ${JSON.stringify(res.innlaanteNr)}`)

    // ===== 1410: FRAVAER SKAL VAERE OBSERVERBART =====
    // `art1410?.timer ?? 0` er groenn bade naar 1410 mangler OG naar hele
    // perArt er tom. Her skrives HELE strukturen ut, og noekkelen sjekkes
    // eksplisitt, saa de to kan skilles. Ingen 1410-post konstrueres.
    const noekler = Object.keys(res.perArt).sort()
    L.push('')
    L.push(`  perArt noekler .............. ${JSON.stringify(noekler)}`)
    L.push(`  perArt (hele) ............... ${JSON.stringify(res.perArt, null, 2)
      .split('\n').join('\n                                ')}`)
    L.push(`  '1410' finnes i perArt ...... ${Object.hasOwn(res.perArt, '1410')}`)
    L.push(`  prisede minutter > 0 ........ ${res.prisedeMinutter > 0}`)
    L.push(`  forbehold ................... ${JSON.stringify(res.forbehold)}`)
    L.push('')
    L.push('  KORTET (mapperen):')
    L.push(`    ${JSON.stringify(kort, null, 2).split('\n').join('\n    ')}`)
    L.push('')
    L.push(`  rundturer ................... ${logg.length}`)
    for (const c of logg) L.push(`    ${c.slag.padEnd(5)} ${c.navn}`)
    // ===== B: RENDERING MED DET EKTE KORTET =====
    // Ikke et avskrevet kort - objektet fra kjeden over, rett inn i den
    // faktiske komponenten sida bruker.
    const html = renderToStaticMarkup(
      createElement(Arbeidsstedsblokk, { kort: [kort], stasjonId: stasjon.id }),
    )
    const tekst = html
      .replace(/<[^>]+>/g, '').replace(/+/g, ' | ')
      .replace(/ /g, ' ').replace(/&#x27;/g, "'").trim()
    const lenker = [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1].replace(/&amp;/g, '&'))

    L.push('')
    L.push('  ===== B: FAKTISK RENDERING =====')
    L.push(`  ${tekst}`)
    L.push(`  lenker: ${JSON.stringify(lenker)}`)
    L.push('')
    L.push(`  motor ....................... ${motortid.toFixed(2)} ms`)
    L.push(`  hele A1-blokka .............. ${total.toFixed(2)} ms  (ekte I/O)`)
    L.push('')

    // ===== DRILLDOWN-DATAENE: 1004 sine faktiske vakter =====
    L.push(`  ===== DRILLDOWN: ansatt 1004 (${FASE}) =====`)
    for (const v of stigs) {
      L.push(`    ${v.rad.dato}  ${v.rad.fraTid}-${v.rad.tilTid}  ${v.rad.minutter} min`)
    }
    L.push(`  sum: ${stigs.length} vakter, ${stigs.reduce((s, v) => s + v.rad.minutter, 0)} min`)
    L.push('')

    console.log(L.join('\n'))

    // ---- A ----
    expect(treff, `${MAANED} var ikke blant A1-maanedene`).toEqual([MAANED])
    expect(ok.every(Boolean), 'minst ett raatt tall avviker — se tabellen over').toBe(true)
    expect(sum).toBe(res.betalteMinutter)

    // 1410: fravaer skal vaere ET FRAVAER, ikke en tom perArt. Er det
    // priset tid, MAA perArt ha minst en art - ellers er det kontrakten
    // som er brutt, ikke helligdagene som mangler.
    expect(res.prisedeMinutter).toBeGreaterThan(0)
    expect(noekler.length, 'perArt er tom selv om noe ble priset').toBeGreaterThan(0)
    expect(Object.hasOwn(res.perArt, '1410')).toBe(false)

    // ---- B: positivt ----
    // DEKNINGEN OG INNLAANT ER LIKE I BEGGE FASER. Det er hele poenget:
    // ingen krone og ingen priset time flytter seg.
    for (const s of [
      '630,8 av 698,8 betalte timer priset (90,3 %)',
      '4 758 kr av beløpet gjelder 2 ansatte med sats hentet fra en annen stasjon',
    ]) expect(tekst, `manglet i renderingen: ${s}`).toContain(s)
    expect(tekst).toContain('Overtid')

    if (FASE === 'etter') {
      expect(tekst).toContain('Beregnet 143 889 kr')
      expect(tekst).toContain('68,0 timer er forklart og ikke timepriset')
      // MANGELEN SKAL VAERE BORTE. Staar den igjen, paastaar skjermen
      // fortsatt at 503 er hoeyere enn den er.
      expect(tekst).not.toContain('mangler satsgrunnlag')
      expect(tekst).not.toContain('Minst 143 889 kr')
    } else {
      expect(tekst).toContain('Minst 143 889 kr')
      expect(tekst).toContain('68,0 timer mangler satsgrunnlag')
      expect(tekst).toContain('· 1 ansatt')
    }

    // ---- B: negativt ----
    expect(tekst.toLowerCase()).not.toContain('komplett')
    for (const enumverdi of [
      'ukjent_nummer', 'maanedslonn', 'fastlonn_klassifisert', 'dublett',
      'avvist_rad', 'kildemangel', 'mangler_register', 'mangler_arbeidstid',
      'Vurdertrad', 'Uprisetgrunn', 'a1_registeroppslag',
    ]) expect(tekst, `intern verdi lekket: ${enumverdi}`).not.toContain(enumverdi)
    expect(tekst).not.toContain('Bokført')

    // REVISJONSLENKA FØLGER ARBEIDET, IKKE STATUSEN.
    // Min forrige utgave krevde lenka i begge faser og var derfor roed
    // i `etter` - den motsa B2e.1s egen regel. Kontrakten er nå:
    // upriset > 0 ELLER forklart > 0 gir lenke. Boenes har 4 080
    // minutter i den ene eller den andre baasen i BEGGE faser, saa den
    // skal finnes begge ganger - men av to forskjellige grunner.
    const skalHaLenke = res.uprisedeMinutter > 0 || res.forklarteMinutter > 0
    expect(skalHaLenke, 'Boenes skal ha upriset eller forklart arbeid').toBe(true)
    expect(lenker).toContain(`/lonnskost/arbeidssted?stasjon=${stasjon.id}&maned=${MAANED}`)

    // ---- drilldown-dataene ----
    expect(stigs.length, '1004 skal ha 10 vakter').toBe(10)
    expect(stigs.reduce((s, v) => s + v.rad.minutter, 0)).toBe(4080)
    // ALDRI `priset`. Fastlonn skal forklares, ikke timeprises.
    for (const v of stigs) expect(v.utfall.slag).not.toBe('priset')
  }, 120000)
})
