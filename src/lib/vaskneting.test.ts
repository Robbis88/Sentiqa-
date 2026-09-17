import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { svinnPerStasjon, stasjonsmaaned, type Stasjonsrad } from './svinn/aggreger'
import { velgGrunnlagPerNoekkel } from './svinn/grunnlag'

// =====================================================================
// NETTER VASK BORT AVVIK I ØVRIG BUTIKKDRIFT?
// =====================================================================
//
// Robert, 2026-09-17: «har du −21 000 i brutto på kiosk, mat, kaffe og
// pluss 21 000 på vask bør den ikke flagges 0». Vask har annen økonomisk
// mekanikk og er lite påvirkbar av daglig drift; et gunstig vaskavvik
// skal ikke fungere som motregning mot et problem lederen kan gjøre noe
// med.
//
// ---------------------------------------------------------------------
// C REGNES IKKE PÅ NYTT HER
// ---------------------------------------------------------------------
//
// `svinnPerStasjon` IMPORTERES fra `svinn/aggreger.ts`. Det er samme
// funksjon `admin-dashbord.tsx:151` bruker, og tallet den gir er det
// `stasjonsrangering.tsx:74` sorterer eierens stasjonsliste på:
//
//   linjer = rader.map((r) => ({ ..., verdi: Math.round(r.usynlig) }))
//     .sort((a, b) => a.verdi - b.verdi)   // lavest manko = best øverst
//
// Skrev jeg summen av igjen her, ville fila bevist at min egen kode er
// enig med seg selv. Den skal bevise noe om PRODUKSJONSKODEN.
//
// Nivåvalget (gruppe kontra produkt) hentes fra `velgGrunnlagPerNoekkel`
// av samme grunn — en rå sum over alle rader ville tatt både «120 Mat»
// og «12010» og gitt omtrent det dobbelte.
//
// ---------------------------------------------------------------------
// DEN ENE ANTAKELSEN, OG DEN ER MERKET
// ---------------------------------------------------------------------
//
// Hvilke koder som ER vask er ikke avledet strukturelt fra en mapping —
// den mappingen finnes ikke. `MOTPOSTER` kjenner `210`, og `211` er målt
// som naboen. `VASK` under er derfor en HYPOTESE, og fila skriver ut
// hver distinkte kode den fant, slik at listen kan bekreftes eller
// avvises på tall.
//
// 130 Varm drikke er IKKE med. Den står i `MOTPOSTER`, men av en annen
// grunn: kaffe motposteres av kaffelojalitet. Fire av fem stasjoner har
// POSITIV netto på 130 og får varsel — den undertrykker ingenting.
// Å legge den på vasksiden fordi begge er motposter ville vært å slutte
// fra mekanisme til betydning.
//
// ---------------------------------------------------------------------
// INGEN REGELENDRING, INGEN TERSKEL, INGEN NY SORTERING
// ---------------------------------------------------------------------
//
// Fila viser A, B og C side om side og beviser `A + B = C`. Den viser
// også hva rekkefølgen på eierens liste VILLE vært sortert på A i stedet
// for C — som en måling av forskjellen, ikke som et forslag.
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

/** HYPOTESE, ikke en mapping. Se toppen. */
const VASK = (kode: string | null): boolean => (kode ?? '').startsWith('21')

const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
const krTegn = (n: number) => (n >= 0 ? '+' : '−') + kr(Math.abs(n))

type Rad = Stasjonsrad & { kode: string | null; navn: string | null }

describe('VASKNETING — A + B = C paa eierens forside', () => {
  kjor('paavirkbart uten vask, vask separat, og dagens total', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const { data: srader } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    const stasjoner = (srader ?? []) as { id: string; navn: string; butikknummer: string }[]
    const navnFor = new Map(stasjoner.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

    // SAMME PERIODEVALG SOM DASHBORDET (`admin-dashbord.tsx:87`).
    const { data: sisteReg } = await supabase
      .from('regnskapslinjer').select('periode').is('stasjon_id', null)
      .order('periode', { ascending: false }).limit(1)
      .maybeSingle<{ periode: string }>()
    const periode = sisteReg?.periode
    if (!periode) throw new Error('fant ingen periode — samme oppslag som dashbordet gjoer')

    // SAMME SPOERRING, pluss `kode`/`navn` som dashbordet ikke henter.
    // Det er nettopp poenget: `svinnPerStasjon` KAN ikke skille vask ut,
    // fordi koden ikke foelger med inn i den.
    const { data: rdata, error: rfeil } = await supabase
      .from('regnskap_usynlig_svinn')
      .select('stasjon_id, periode, nivaa, analyseomraade, kode, navn, kast, usynlig_kr')
      .eq('periode', periode).is('slettet_tid', null)
      .overrideTypes<Rad[]>()
    if (rfeil) throw new Error(`regnskap_usynlig_svinn: ${rfeil.message}`)
    const rader = (rdata ?? []) as Rad[]

    const L: string[] = ['', '  VASKNETING — PRODUKSJON', '']
    L.push(`  periode ${periode}   rader ${rader.length}   `
      + `(samme spoerring som admin-dashbord.tsx:95, pluss kode/navn)`)
    L.push('  C kommer fra svinnPerStasjon() — IMPORTERT, ikke gjenskapt.')

    // =================================================================
    // 1 HVILKE KODER FINNES — saa VASK-hypotesen kan bekreftes
    // =================================================================
    const { perNoekkel } = velgGrunnlagPerNoekkel(rader, stasjonsmaaned)
    const valgte: Rad[] = []
    for (const [noekkel, valg] of perNoekkel) {
      if (noekkel.split('|')[0] === 'uten') continue
      valgte.push(...valg.rader)
    }

    const koder = new Map<string, string>()
    for (const r of valgte) koder.set(r.kode ?? '(uten kode)', r.navn ?? '')
    L.push('')
    L.push(`  KODER I GRUNNLAGET (${koder.size} distinkte) — B-siden er merket`)
    for (const [k, n] of [...koder].sort((a, b) => a[0].localeCompare(b[0]))) {
      L.push(`    ${VASK(k) === true ? 'B ' : '  '} ${k.padEnd(8)} ${n}`)
    }

    // Kanarifugl: treffer hypotesen ingenting, maaler fila ingenting —
    // og «A + B = C med B = 0» ville bestaatt uten aa bety noe.
    expect(
      valgte.filter((r) => VASK(r.kode)).length,
      'VASK-hypotesen traff ingen rader — da beviser A + B = C ingenting',
    ).toBeGreaterThan(0)

    // =================================================================
    // 2 A, B OG C PER STASJON
    // =================================================================
    // MOTORENS EGEN SPLITT, ved siden av min uavhengige.
    //
    // `svinnPerStasjon` baerer naa `utenVaskKr` og `vaskKr` selv. Fila
    // regner fortsatt sin egen — ikke av vantro, men fordi de to er
    // UAVHENGIGE veier til samme tall: min leser radene rett, motorens
    // gaar gjennom `erVask`. Er de enige, er splitten bevist mot en
    // maaling som ble gjort FOER den fantes.
    const motor = new Map(svinnPerStasjon(rader).map((s) => [s.stasjonId, s]))
    const cPer = new Map([...motor].map(([id, s]) => [id, s.usynligKr]))
    const aPer = new Map<string, number>()
    const bPer = new Map<string, number>()
    for (const r of valgte) {
      const id = r.stasjon_id
      if (!id) continue
      const v = r.usynlig_kr ?? 0
      const m = VASK(r.kode) ? bPer : aPer
      m.set(id, (m.get(id) ?? 0) + v)
    }

    L.push('')
    L.push('  A + B = C PER STASJON')
    L.push('    stasjon                  A oevrig      B vask        C i dag       A+B−C')
    let maksAvvik = 0
    for (const s of stasjoner) {
      const c = cPer.get(s.id)
      if (c === undefined) continue
      const a = aPer.get(s.id) ?? 0
      const b = bPer.get(s.id) ?? 0
      const d = a + b - c
      maksAvvik = Math.max(maksAvvik, Math.abs(d))
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${krTegn(a).padStart(11)}  `
        + `${krTegn(b).padStart(11)}  ${krTegn(c).padStart(11)}  ${krTegn(d).padStart(9)}`,
      )
    }
    L.push(`    stoerste avvik ${kr(maksAvvik)} kr`)

    // =================================================================
    // 2b MOTORENS SPLITT MOT DEN UAVHENGIGE, OG MOT FASITEN
    // =================================================================
    //
    // FASITEN ER MAALT, IKKE VALGT. Tallene under er juli 2026 slik de
    // sto FOER porten, lest av denne fila da `svinnPerStasjon` ennaa bare
    // hadde én sum. Avviker produksjonen, er det et FUNN — ikke noe som
    // skal rettes bort ved aa flytte fasiten.
    const FASIT: Record<string, { utenVask: number; vask: number; total: number }> = {
      '4177': { utenVask: 37_684, vask: 0, total: 19_075 },
      '4185': { utenVask: 39_919, vask: 0, total: 39_919 },
      '9038': { utenVask: 37_035, vask: 0, total: 17_905 },
      '9145': { utenVask: 14_696, vask: 0, total: -13_926 },
      '9467': { utenVask: 12_196, vask: 0, total: -2_516 },
    }
    // Vask UTLEDES av de to andre: `vask = total − utenVask`. Begge er
    // avrundede kroner, saa den utledede kan bomme med ±1 mot motorens
    // faktiske sum. Derfor asserteres den IKKE - bare `utenVask` og
    // raatotalen, som begge er lest direkte. Kolonnen er merket i
    // utskriften saa den ikke leses som et avvik.
    for (const f of Object.values(FASIT)) f.vask = f.total - f.utenVask

    L.push('')
    L.push('  MOTORENS SPLITT MOT FASIT (juli 2026, maalt foer porten)')
    L.push('    stasjon                  motor utenVask   fasit         motor vask    fasit (utledet, ±1)')
    const avvikene: string[] = []
    for (const s of stasjoner) {
      const m = motor.get(s.id)
      if (!m) continue
      const f = FASIT[s.butikknummer]
      // Den uavhengige splitten og motorens maa vaere enige, uansett fasit.
      const egen = aPer.get(s.id) ?? 0
      if (Math.round(egen) !== Math.round(m.utenVaskKr)) {
        avvikene.push(`${navnFor.get(s.id)}: uavhengig ${kr(egen)} mot motorens ${kr(m.utenVaskKr)}`)
      }
      if (f && Math.round(m.utenVaskKr) !== f.utenVask) {
        avvikene.push(`${navnFor.get(s.id)} utenVask: forventet ${kr(f.utenVask)}, faktisk ${kr(m.utenVaskKr)}`)
      }
      if (f && Math.round(m.usynligKr) !== f.total) {
        avvikene.push(`${navnFor.get(s.id)} raatotal: forventet ${kr(f.total)}, faktisk ${kr(m.usynligKr)}`)
      }
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${krTegn(m.utenVaskKr).padStart(14)}  `
        + `${(f ? krTegn(f.utenVask) : '—').padStart(11)}  `
        + `${krTegn(m.vaskKr).padStart(12)}  ${(f ? krTegn(f.vask) : '—').padStart(11)}`,
      )
    }
    if (avvikene.length > 0) {
      L.push('    AVVIK:')
      for (const a of avvikene) L.push(`      ${a}`)
    }

    // RAATOTALEN SKAL VAERE UENDRET. Porten la splitten VED SIDEN AV;
    // trakk den noe fra `usynligKr`, ville hver eksisterende leser av
    // det tallet ha flyttet seg i stillhet.
    for (const [, m] of motor) {
      expect(Math.round(m.utenVaskKr + m.vaskKr)).toBe(Math.round(m.usynligKr))
    }
    expect(avvikene, `produksjonen avviker fra fasiten:\n  ${avvikene.join('\n  ')}`)
      .toEqual([])

    // IDENTITETEN BEVISES, IKKE FORUTSETTES. Holder den ikke, ligger det
    // en rad i C som ikke er i A eller B — og da er splitten ufullstendig
    // og alt under er ugyldig.
    expect(
      Math.round(maksAvvik),
      'A + B != C — splitten dekker ikke alle radene svinnPerStasjon summerer',
    ).toBeLessThanOrEqual(1)

    // =================================================================
    // 3 HVA REKKEFOELGEN PAA EIERENS LISTE AVHENGER AV
    // =================================================================
    //
    // `stasjonsrangering.tsx:74` sorterer stigende paa C: lavest oeverst.
    // Her vises samme sortering paa A, side om side. INGEN ANBEFALING —
    // bare forskjellen, i rekkefoelge.
    const rang = (m: Map<string, number>) => [...m.entries()]
      .filter(([id]) => navnFor.has(id))
      .sort((x, y) => x[1] - y[1])
      .map(([id, v], i) => `${i + 1}. ${navnFor.get(id)} ${krTegn(v)}`)

    L.push('')
    L.push('  REKKEFOELGE — «lavest oeverst», slik stasjonsrangering.tsx sorterer')
    L.push('    paa raatotalen (FOER porten):')
    for (const l of rang(cPer)) L.push(`      ${l}`)
    L.push('    paa utenVask (ETTER porten — det rangeringen naa bruker):')
    for (const l of rang(new Map([...motor].map(([id, m]) => [id, m.utenVaskKr])))) {
      L.push(`      ${l}`)
    }

    // =================================================================
    // 4 STASJONENS EGET BILDE — hvor mye av C er vask
    // =================================================================
    L.push('')
    L.push('  VASKENS ANDEL AV DAGENS TOTAL')
    for (const s of stasjoner) {
      const c = cPer.get(s.id)
      if (c === undefined) continue
      const a = aPer.get(s.id) ?? 0
      const b = bPer.get(s.id) ?? 0
      // FORTEGNET BAERER BETYDNING. Robert: negativt usynlig = mer brutto
      // funnet enn forventet. Et «A positiv, B negativ»-par er nettopp
      // tilfellet der vask maskerer oevrig drift.
      const maskerer = a > 0 && b < 0
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} `
        + `oevrig ${krTegn(a).padStart(11)}   vask ${krTegn(b).padStart(11)}   `
        + `total ${krTegn(c).padStart(11)}`
        + (maskerer ? `   <- vask trekker ${kr(Math.min(a, -b))} kr av oevrig ned` : ''),
      )
    }

    L.push('')
    L.push('  Ingen regel er endret. Ingen terskel er satt. Ingen sortering er byttet.')
    L.push('')
    console.log(L.join('\n'))
  }, 120_000)
})
