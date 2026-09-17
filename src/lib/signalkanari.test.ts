import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { klyngebilde, rangerSignaler, type RaaSignal, type Signal } from './signaler'
import { filtrerLukkede, treffSignaler, utsolgtSignaler } from './signalkilder'
import { hentRegnskapVarsler, sammeSak, type RegnskapVarsel } from './regnskap-varsler'
import { byggFenomener, utbredelse, type Stasjonsvarsel } from './fenomen'
import { poengFor } from './signaler'

// =====================================================================
// PRODUKSJONSKANARIFUGL — OPPMERKSOMHETSVEKTOREN
// =====================================================================
//
// `/oversikt` melder «14 ting å se på». Vi vet fra koden AT alt vises —
// `Oppmerksomhet` gjør `signaler.map(...)` uten kutt — men ikke HVA de
// fjorten er. Uten det kan ingen utvalgsregel velges.
//
// Den kaller `rangerSignaler` og kildene slik `/oversikt` gjør det, og
// endrer ingen poeng, ingen terskel og ingen sortering. Utvalgsreglene
// A, B og C simuleres PÅ UTSIDEN.
//
// ---------------------------------------------------------------------
// 3A MÅLES HER: VEKTOREN SKAL VÆRE UENDRET
// ---------------------------------------------------------------------
//
// `sak` bevarer struktur motoren allerede kjente og kastet. Den skal
// ikke flytte ett eneste tall. Kjøres denne før og etter 3A, skal den
// rangerte vektoren være identisk — samme antall, samme poeng, samme
// rekkefølge. Det eneste nye er at saken kan TELLES.
//
// ---------------------------------------------------------------------
// HVA DEN IKKE KAN MÅLE
// ---------------------------------------------------------------------
//
// Butikksjefens forside bygger sine signaler inne i
// `butikksjef-dashbord.tsx` av data den henter selv. Den koden er ikke
// eksportert, så den kan ikke kalles herfra uten å duplisere den — og en
// kopi ville målt kopien. Det som måles er eierens kilder.
//
// KREVER KANARI_EPOST og KANARI_PASSORD.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD
const kjor = EPOST && PASSORD ? it : it.skip

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

/**
 * Drift eller system?
 *
 * KLASSIFISERING PÅ `merke`, SOM ALLEREDE FINNES. Hvert `RaaSignal`
 * bærer opphavet sitt. Her leses det bare; ingenting settes.
 *
 * `Regnskap` er den vanskelige: den kan være et ekte driftsavvik (lønn
 * over budsjett) og et datakvalitetsproblem i samme merke. Derfor
 * `uavklart`, ikke en gjetning.
 */
const KLASSE: Record<string, 'drift' | 'system' | 'uavklart'> = {
  Salg: 'drift',
  Marked: 'drift',
  Stasjon: 'drift',
  Oppgaver: 'drift',
  Tilbakemelding: 'drift',
  Bemanning: 'drift',
  'Mulig utsolgt': 'drift',
  Treffsikkerhet: 'drift',
  Varer: 'drift',
  Sjekkpunkt: 'drift',
  Ansatte: 'drift',
  Systemet: 'system',
  Regnskap: 'uavklart',
}

const klasse = (m: string) => KLASSE[m] ?? 'uavklart'

describe('KANARIFUGL — oppmerksomhetsvektoren i produksjon', () => {
  kjor('rangerer som /oversikt, og simulerer tre utvalgsregler', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' })
      .format(new Date())

    const { data: stasjonsrader, error: sfeil } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    if (sfeil) throw new Error(`Stasjonene: ${sfeil.message}`)
    const stasjoner = (stasjonsrader ?? []) as
      { id: string; navn: string; butikknummer: string }[]
    expect(stasjoner.length, 'ingen stasjoner - da maales ingenting').toBeGreaterThan(0)

    const { data: prof } = await supabase
      .from('profiler').select('retailer_id').limit(1).maybeSingle<{ retailer_id: string }>()
    const retailerId = prof?.retailer_id ?? ''

    const L: string[] = ['', '  OPPMERKSOMHETSVEKTOREN — PRODUKSJON', '']
    const raa: RaaSignal[] = []

    // ---------------------------------------------------------------
    // 1 REGNSKAPSVARSLENE — én per ikke-grønn stasjon
    // ---------------------------------------------------------------
    const { data: sisteReg } = await supabase
      .from('regnskapslinjer').select('periode').is('stasjon_id', null)
      .order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
    const periode = sisteReg?.periode ?? null
    L.push(`  siste regnskapsperiode ... ${periode ?? 'INGEN'}`)

    const varselrader: { stasjon: string; varsel: RegnskapVarsel }[] = []
    const stasjonsvarsler: Stasjonsvarsel[] = []
    if (periode && retailerId) {
      const varsler = await hentRegnskapVarsler(supabase, retailerId, periode).catch(() => [])
      L.push(`  regnskapsvarsler totalt . ${varsler.length}`)
      for (const s of stasjoner) {
        const navn = `${s.butikknummer} ${s.navn}`
        const mine = varsler.filter((v) => v.omfang === navn)
        for (const v of mine) {
          varselrader.push({ stasjon: navn, varsel: v })
          stasjonsvarsler.push({ stasjonId: s.id, stasjonsnavn: navn, varsel: v })
        }
        const rod = mine.find((v) => v.nivaa === 'rod')
        const gul = mine.find((v) => v.nivaa === 'gul')
        if (!rod && !gul) continue
        raa.push({
          id: `drift-${navn}`, merke: 'Regnskap', tittel: navn,
          detalj: (rod ?? gul)!.tittel,
          niva: rod ? 'kritisk' : 'folg', lenke: '/regnskap',
        })
      }
    }

    // ---------------------------------------------------------------
    // 2 KLYNGEBILDET — det ene stedet dedupliseringen alt finnes
    // ---------------------------------------------------------------
    const { data: uker } = await supabase
      .from('uke_rapport').select('stasjon_id, omsetning, omsetning_ifjor')
      .order('uke', { ascending: false }).limit(60)
    const perStasjon = new Map<string, { omsetning: number; ifjor: number }>()
    for (const u of (uker ?? []) as
      { stasjon_id: string; omsetning: number; omsetning_ifjor: number }[]) {
      if (perStasjon.has(u.stasjon_id)) continue
      perStasjon.set(u.stasjon_id, {
        omsetning: Number(u.omsetning ?? 0), ifjor: Number(u.omsetning_ifjor ?? 0),
      })
    }
    const kb = klyngebilde(stasjoner
      .filter((s) => perStasjon.has(s.id))
      .map((s) => ({
        stasjonId: s.id, navn: `${s.butikknummer} ${s.navn}`,
        omsetning: perStasjon.get(s.id)!.omsetning,
        omsetningIfjor: perStasjon.get(s.id)!.ifjor,
      })))
    raa.push(...kb.signaler)
    L.push(`  klyngevekst ............. ${kb.vekstPst.toFixed(1)} %`
      + `  signaler ${kb.signaler.length}`)

    // ---------------------------------------------------------------
    // 3 UTSOLGT OG TREFFSIKKERHET — best effort, som paa forsiden
    // ---------------------------------------------------------------
    const [utsolgt, treff] = await Promise.all([
      utsolgtSignaler(supabase, stasjoner, idag).catch(() => []),
      treffSignaler(supabase, stasjoner, idag).catch(() => []),
    ])
    raa.push(...utsolgt, ...treff)
    L.push(`  mulig utsolgt ........... ${utsolgt.length}`)
    L.push(`  treffsikkerhet .......... ${treff.length}`)

    const rangert: Signal[] = await filtrerLukkede(supabase, rangerSignaler(raa), idag)
      .catch(() => rangerSignaler(raa))

    // ===============================================================
    // VEKTOREN — SKAL VAERE IDENTISK FOER OG ETTER 3A
    // ===============================================================
    L.push('')
    L.push(`  RANGERT VEKTOR — ${rangert.length} signaler`)
    L.push('  #   poeng  nivaa     klasse    merke              kr        dager  tittel')
    rangert.forEach((s, i) => {
      L.push(`  ${String(i + 1).padStart(2)}  ${String(s.poeng).padStart(5)}`
        + `  ${s.niva.padEnd(8)}  ${klasse(s.merke).padEnd(8)}`
        + `  ${s.merke.padEnd(17)}`
        + `  ${(s.konsekvensKr == null ? '—' : Math.round(s.konsekvensKr).toLocaleString('nb-NO')).padStart(9)}`
        + `  ${String(s.dager ?? '—').padStart(5)}`
        + `  ${s.tittel}`)
      L.push(`      handling: ${s.lenke}   id: ${s.id}`)
      L.push(`      detalj: ${s.detalj.slice(0, 150)}`)
    })

    // ===============================================================
    // A — BARE TOPP N
    // ===============================================================
    L.push('')
    L.push('  A — TOPP N')
    for (const n of [3, 5, 7]) {
      const valgt = rangert.slice(0, n)
      const tapt = rangert.slice(n)
      const tapteKritiske = tapt.filter((s) => s.niva === 'kritisk').length
      L.push(`    N=${n}: viser ${valgt.length}, skjuler ${tapt.length}`
        + `${tapteKritiske > 0 ? `  <- SKJULER ${tapteKritiske} KRITISKE` : ''}`)
      L.push(`      ${valgt.map((s) => `${s.merke}:${s.niva}`).join('  ') || '(ingen)'}`)
    }

    // ===============================================================
    // B — ALLE KRITISKE + HØYEST RANGERTE ØVRIGE
    // ===============================================================
    L.push('')
    L.push('  B — ALLE KRITISKE + HOEYEST RANGERTE OEVRIGE')
    const kritiske = rangert.filter((s) => s.niva === 'kritisk')
    const ovrige = rangert.filter((s) => s.niva !== 'kritisk')
    for (const m of [1, 2, 3]) {
      const valgt = [...kritiske, ...ovrige.slice(0, m)]
      L.push(`    kritiske ${kritiske.length} + ${m} oevrige = ${valgt.length} vist,`
        + ` ${rangert.length - valgt.length} under «Se alle»`)
    }

    // ===============================================================
    // C — NATURLIG KUTT I POENGSERIEN
    // ===============================================================
    L.push('')
    L.push('  C — POENGGAP')
    const gap = rangert.slice(0, -1).map((s, i) => ({
      etter: i + 1, fra: s.poeng, til: rangert[i + 1].poeng, gap: s.poeng - rangert[i + 1].poeng,
    })).sort((a, b) => b.gap - a.gap)
    if (gap.length === 0) {
      L.push('    for faa signaler til aa se et gap')
    } else {
      for (const g of gap.slice(0, 5)) {
        L.push(`    etter #${g.etter}: ${g.fra} -> ${g.til}   gap ${g.gap}`)
      }
      const snitt = gap.reduce((a, g) => a + g.gap, 0) / gap.length
      L.push(`    stoerste gap ${gap[0].gap}, snitt ${snitt.toFixed(1)},`
        + ` forhold ${(gap[0].gap / (snitt || 1)).toFixed(1)}x`)
    }

    // ===============================================================
    // SYSTEM MOT DRIFT
    // ===============================================================
    L.push('')
    L.push('  SYSTEM MOT DRIFT')
    for (const k of ['drift', 'system', 'uavklart'] as const) {
      const n = rangert.filter((s) => klasse(s.merke) === k)
      L.push(`    ${k.padEnd(9)} ${String(n.length).padStart(2)}`
        + `   ${[...new Set(n.map((s) => s.merke))].join(', ') || '—'}`)
    }

    // ===============================================================
    // 3A — SAKEN SOM NØKKEL
    // ===============================================================
    //
    // Den gamle nøkkelen `(gruppe, nivaa, tittel)` ga «1 stasjon» på
    // alle 59, fordi tittelen bærer stasjonens eget kronebeløp. `sak`
    // bærer strukturen motoren allerede kjente.
    //
    // MÅLES HER, GRUPPERES IKKE I PRODUKTET. Ingenting av dette finnes i
    // en flate — det er 3B sin jobb, på et lag over.
    L.push('')
    L.push('  3A — SAKEN SOM NOEKKEL')
    const saker: { sak: NonNullable<RegnskapVarsel['sak']>;
      stasjoner: string[]; nivaaer: string[]; kroner: number[] }[] = []
    let utenSak = 0
    for (const { stasjon, varsel } of varselrader) {
      if (!varsel.sak) { utenSak++; continue }
      const f = saker.find((x) => sammeSak(x.sak, varsel.sak))
      if (f) { f.stasjoner.push(stasjon); f.nivaaer.push(varsel.nivaa); f.kroner.push(varsel.vekt) }
      else {
        saker.push({
          sak: varsel.sak, stasjoner: [stasjon],
          nivaaer: [varsel.nivaa], kroner: [varsel.vekt],
        })
      }
    }
    L.push(`    varsler ${varselrader.length}`
      + `   uten sak (kode mangler) ${utenSak}`
      + `   distinkte saker ${saker.length}`)
    for (const s of [...saker].sort((a, b) => b.stasjoner.length - a.stasjoner.length)) {
      if (s.stasjoner.length < 2) continue
      const v = 'vare' in s.sak ? s.sak.vare : null
      const id = v
        ? (v.form === 'varegruppe'
          ? `${v.form} ${v.kode} «${v.navn}»`
          : `${v.form} ${v.avdeling} «${v.navn}»`)
        : ''
      L.push(`    ${s.stasjoner.length} av ${stasjoner.length}: ${s.sak.slag}  ${id}`)
      // KRONER PER STASJON, ALDRI SUMMERT. Se 3B-kontrakten: en kjedesum
      // ville vaert et nytt oekonomisk tall ingen motor eier.
      L.push(`      nivaa ${[...new Set(s.nivaaer)].join('/')}`
        + `   kroner per stasjon: ${s.kroner.map((k) => Math.round(k).toLocaleString('nb-NO')).join(' · ')}`)
      L.push(`      ${s.stasjoner.join(', ')}`)
    }

    // ===============================================================
    // DEN GAMLE NØKKELEN, TIL SAMMENLIGNING
    // ===============================================================
    // ===============================================================
    // 3B — KANDIDATVEKTOREN AV FENOMENER
    // ===============================================================
    //
    // MAALT, IKKE RANGERT. Ingen ny poengformel. For hvert fenomen
    // skrives det eksisterende rangeringskontrakten VILLE gitt, slik at
    // vi kan se om den i det hele tatt kan skille to fenomener fra
    // hverandre foer vi lager enda en motor.
    //
    // `poengFor` er `signaler.ts` sin. `nivaa`, utbredelse og de
    // underliggende beloepene staar som SEPARATE kolonner - de forenes
    // ikke, og utbredelse gjoeres ikke om til alvor.
    const fenomener = byggFenomener(stasjonsvarsler, stasjoner.length)
    L.push('')
    L.push(`  3B — FENOMENER: ${fenomener.length} av ${stasjonsvarsler.length} varsler`)
    L.push('  nivaa  poeng  utbredelse   hoeyeste vekt   sak')
    // SORTERT BARE FOR LESBARHET I DENNE UTSKRIFTEN. `byggFenomener`
    // rangerer ingenting; rekkefoelgen her er ikke en kontrakt.
    const lesbar = [...fenomener].sort((a, b) =>
      (a.nivaa === b.nivaa ? 0 : a.nivaa === 'rod' ? -1 : 1)
      || b.stasjoner.length - a.stasjoner.length)
    for (const f of lesbar) {
      const poeng = poengFor({
        id: 'x', merke: 'Regnskap', tittel: 'x', detalj: 'x',
        niva: f.nivaa === 'rod' ? 'kritisk' : 'folg', lenke: '/regnskap',
      })
      const vekt = Math.max(...f.underliggende.map((v) => Math.abs(v.vekt)))
      const v = f.sak && 'vare' in f.sak ? f.sak.vare : null
      const id = v
        ? (v.form === 'varegruppe' ? `${v.kode} «${v.navn}»` : `motpost ${v.avdeling} «${v.navn}»`)
        : ''
      L.push(`  ${f.nivaa.padEnd(5)}  ${String(poeng).padStart(5)}`
        + `  ${(utbredelse(f) ?? '—').padEnd(11)}`
        + `  ${Math.round(vekt).toLocaleString('nb-NO').padStart(13)}`
        + `   ${f.sak?.slag ?? 'UTEN SAK'}  ${id}`)
      L.push(`         ${f.stasjoner.map((x) => `${x.stasjonsnavn}:${x.nivaa}`).join('  ')}`)
    }
    // HVA KONTRAKTEN FAKTISK KAN SKILLE.
    const poengsett = new Set(lesbar.map((f) => (f.nivaa === 'rod' ? 1000 : 300)))
    L.push('')
    L.push(`    distinkte poengverdier blant ${fenomener.length} fenomener: ${poengsett.size}`
      + `   (${[...poengsett].join(', ')})`)
    L.push('    konsekvens og varighet: INGEN regnskapsvarsler baerer dem')

    L.push('')
    L.push('  TIL SAMMENLIGNING — den gamle noekkelen (gruppe, nivaa, tittel)')
    const gammel = new Map<string, number>()
    for (const { varsel } of varselrader) {
      const n = `gruppe=${varsel.gruppe} · ${varsel.nivaa} · ${varsel.tittel}`
      gammel.set(n, (gammel.get(n) ?? 0) + 1)
    }
    const flere = [...gammel.values()].filter((n) => n > 1).length
    L.push(`    distinkte noekler ${gammel.size} av ${varselrader.length} varsler`
      + `   med mer enn én stasjon: ${flere}`)

    L.push('')
    console.log(L.join('\n'))

    // KANARIFUGL FOR KANARIFUGLEN.
    expect(rangert.length, 'ingen signaler - da er ingenting maalt').toBeGreaterThan(0)
    for (let i = 1; i < rangert.length; i++) {
      expect(rangert[i - 1].poeng, 'vektoren er ikke sortert synkende')
        .toBeGreaterThanOrEqual(rangert[i].poeng)
    }
    // 3A SKAL BEVARE, IKKE FINNE PAA. Hvert varsel med en varegruppekode
    // maa ha faatt en sak; er `utenSak` lik antallet, er feltet dodt.
    expect(varselrader.length, 'ingen varsler aa klassifisere').toBeGreaterThan(0)
    expect(utenSak, 'INGEN varsler fikk en sak - feltet er dodt')
      .toBeLessThan(varselrader.length)
  }, 180_000)
})
