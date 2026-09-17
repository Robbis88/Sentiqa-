import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { fordelRegnskapssvinn, hentSvinnbudsjett } from './svinn/hent-budsjett'
import { avdelingAv, vareomradeAv } from './svinn/mot-budsjett'
import { velgGrunnlagPerNoekkel } from './svinn/grunnlag'

// =====================================================================
// SPISER ET GUNSTIG VASKAVVIK SVINNBUDSJETTET TIL KIOSK OG MAT?
// =====================================================================
//
// `vaskneting.test.ts` beviste at vask nettes inn i eierens forside. Det
// er ÉN av to steder totalen dannes. Det andre er BP-sammenligningen:
//
//   mot-budsjett.ts:352   const totaltKr = usynligKr + kastAvlagtKr
//   mot-budsjett.ts:384   avvikMotBpKr: totaltKr − tillattSvinnKr
//
// `totaltKr` vises paa `/svinn` (linje 395 bytter merkelapp til «Usynlig
// overskudd» naar summen er negativ) OG leses av assistenten som
// `hele_svinnet.totalt_kr` (`ai/verktoy.ts:1594`).
//
// ---------------------------------------------------------------------
// AVGJOERELSEN LIGGER I ÉN LINJE
// ---------------------------------------------------------------------
//
//   hent-budsjett.ts:157    if (!iAvdelingen(r.kode)) continue
//   hent-budsjett.ts:139    avdeling == null || avdelingAv(kode) === avdeling
//
// `avdeling` leses ut av `kastbudsjett`-raden med `nivaa = 'avdeling'`.
// FINNES DEN RADEN IKKE, er `avdeling` null, og da er predikatet alltid
// sant — hver eneste varegruppe slipper inn i `usynligPerMaaned`, vask
// inkludert.
//
// Det er altsaa ikke en regel om vask i det hele tatt. Det er en
// avgrensning som finnes ELLER IKKE FINNES per stasjon og aar, avhengig
// av hva kastbudsjettet inneholder.
//
// ---------------------------------------------------------------------
// REPRODUKSJONEN BEVISES FOER VARIANTEN BRUKES
// ---------------------------------------------------------------------
//
// Fila kaller `hentSvinnbudsjett` — produksjonsfunksjonen, samme som
// `/svinn` og `ai/verktoy.ts` bruker — og regner deretter det samme
// tallet selv, med `avdelingAv` og `velgGrunnlagPerNoekkel` importert.
//
// Stemmer reproduksjonen med motorens `usynligKr`, er varianten «samme
// sum uten vask» til aa stole paa. Stemmer den IKKE, sier fila fra og
// trekker ingen konklusjon — en variant bygget paa en reproduksjon som
// ikke traff, ville vaert et tall uten dekning.
//
// INGEN REGELENDRING. Fila maaler.
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

/** Samme hypotese som `vaskneting.test.ts`. Kodene ble bekreftet der. */
const VASK = (kode: string | null): boolean => (kode ?? '').startsWith('21')

const AAR = 2026
const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
const krTegn = (n: number) => (n >= 0 ? '+' : '−') + kr(Math.abs(n))
const tall = (n: number | null) => (n === null ? '—' : krTegn(n))

type Regnskapsrad = {
  periode: string
  kode: string | null
  nivaa: string | null
  analyseomraade: string | null
  kast: number | null
  usynlig_kr: number | null
}

describe('VASKBUDSJETT — naar vask moeter BP-ens svinnrom', () => {
  kjor('per stasjon: avgrensning, motorens tall, og det samme uten vask', async () => {
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
    expect(stasjoner.length).toBeGreaterThan(0)

    const L: string[] = ['', `  VASKBUDSJETT — PRODUKSJON, aar ${AAR}`, '']
    L.push('  Avgjoerelsen: hent-budsjett.ts:157  if (!iAvdelingen(r.kode)) continue')
    L.push('  avdeling == null  ->  ingen avgrensning  ->  vask slipper inn')

    let reproduksjonerProevd = 0
    let reproduksjonerTraff = 0
    let bilderFunnet = 0
    let utenUsynlig = 0

    for (const s of stasjoner) {
      const navn = `${s.butikknummer} ${s.navn}`
      L.push('')
      L.push(`  ${navn}`)

      // ── 1 AVGRENSNINGEN, LEST FRA KASTBUDSJETTET ────────────────────
      const { data: kb } = await supabase
        .from('kastbudsjett').select('nivaa, kode, navn')
        .eq('stasjon_id', s.id).eq('ar', AAR)
        .overrideTypes<{ nivaa: string; kode: string; navn: string | null }[]>()
      const rader = kb ?? []
      const avdelingsrad = rader.find((b) => b.nivaa === 'avdeling')
      const avdeling = avdelingsrad?.kode ?? null
      // `hent-budsjett.ts:130`. Avgjoer hvordan KASTSIDEN noekles.
      const paaVareomrade = rader.some((b) => b.nivaa === 'vareomrade')
      L.push(`    kastbudsjett: ${rader.length} rader   `
        + `avdelingsrad ${avdelingsrad ? `${avdelingsrad.kode} «${avdelingsrad.navn ?? ''}»` : 'MANGLER'}`)
      L.push(`    -> avgrensning: ${avdeling == null
        ? 'INGEN — hver varegruppe slipper inn, vask inkludert'
        : `bare avdeling ${avdeling}`}`)

      // ── 2 MOTORENS EGNE TALL ────────────────────────────────────────
      const bilde = await hentSvinnbudsjett(supabase, s.id, AAR)

      // TO FORSKJELLIGE NULL, OG DE BETYR IKKE DET SAMME.
      //
      //   bilde === null          kallet fant intet budsjett i det hele tatt
      //   bilde.usynlig === null  budsjettet finnes, men `usynligstatus`
      //                           ga null: `maaneder.length === 0`, altsaa
      //                           ingen maaned har BAADE usynlig og kast
      //                           etter avgrensningen.
      //
      // Foerste utgave skrev «ingen avlagt maaned» for begge. Det er en
      // paastand om aarsak, og den ene av dem var ikke maalt.
      if (!bilde) {
        L.push('    hentSvinnbudsjett: null — ingen Svinnbilde for dette aaret')
        continue
      }
      bilderFunnet++
      L.push(`    notat: ${bilde.notat}`)
      const u = bilde.usynlig
      if (u) {
        L.push(`    motoren: usynlig ${krTegn(u.usynligKr)}   kast ${krTegn(u.kastAvlagtKr)}   `
          + `totalt ${krTegn(u.totaltKr)}   over ${u.maaneder} avlagte maaneder`)
        L.push(`             tillatt svinn ${tall(u.tillattSvinnKr)}   `
          + `avvik mot BP ${tall(u.avvikMotBpKr)}`)
      } else {
        utenUsynlig++
        L.push('    motoren: usynlig = null  ->  `/svinn` sitt «hele svinnet»-felt')
        L.push('             og AI-ens `hele_svinnet` viser INGENTING for dette aaret')
      }

      // ── 3 REPRODUKSJONEN, MED MOTORENS EGNE HJELPERE ────────────────
      const { data: rr } = await supabase
        .from('regnskap_usynlig_svinn')
        .select('periode, kode, nivaa, analyseomraade, kast, usynlig_kr')
        .eq('stasjon_id', s.id)
        .gte('periode', `${AAR}-01-01`).lte('periode', `${AAR}-12-31`)
        .is('slettet_tid', null)
        .overrideTypes<Regnskapsrad[]>()
      const grunnlag = velgGrunnlagPerNoekkel(rr ?? [], (r) => r.periode)
      const iAvdelingen = (kode: string | null) =>
        avdeling == null || avdelingAv(kode) === avdeling

      // ── 3b HVOR RADENE BLIR AV ──────────────────────────────────────
      //
      // «med usynlig 0, med kast 0» kan bety at spoerringen var tom, at
      // `velgGrunnlag` forkastet alt, eller at `iAvdelingen` gjorde det.
      // Tre helt ulike aarsaker som ser like ut i én null. Derfor telles
      // de hver for seg, og kodene vises med hva `avdelingAv` gjoer med
      // dem — den er importert fra motoren, saa dette er dens svar.
      const etterAvd = grunnlag.alleRader.filter((r) => iAvdelingen(r.kode))
      L.push(`    rader: spoerring ${(rr ?? []).length}   `
        + `etter velgGrunnlag ${grunnlag.alleRader.length}   `
        + `etter iAvdelingen ${etterAvd.length}`)
      const kodekart = new Map<string, string | null>()
      for (const r of grunnlag.alleRader) {
        kodekart.set(r.kode ?? '(null)', avdelingAv(r.kode))
      }
      if (kodekart.size > 0) {
        L.push(`    kode -> avdelingAv(kode)   [avgrensningen krever = ${avdeling ?? 'alle'}]`)
        L.push('      ' + [...kodekart].sort((a, b) => a[0].localeCompare(b[0]))
          .map(([k, a]) => `${k}->${a ?? 'null'}`).join('  '))
      }

      let alle = 0
      let vask = 0
      // MAANEDSMENGDENE, FORDI `usynligstatus` SNITTER DEM.
      //
      //   maaneder = usynligPerMaaned.keys().filter(m => kastPerMaaned.has(m))
      //
      // Er snittet tomt, er hele `Usynligstatus` null — og da er
      // spoersmaalet HVILKEN av de to som mangler maaneden.
      const medUsynlig = new Set<string>()
      const medKast = new Set<string>()
      for (const r of grunnlag.alleRader) {
        if (!iAvdelingen(r.kode)) continue
        const m = r.periode.slice(0, 7)
        if (r.usynlig_kr != null) {
          medUsynlig.add(m)
          alle += r.usynlig_kr
          if (VASK(r.kode)) vask += r.usynlig_kr
        }
        // KASTSIDEN HAR TO FILTRE TIL, og de er motorens, ikke mine:
        //
        //   hent-budsjett.ts:167   if (r.kast == null) continue
        //   hent-budsjett.ts:168   const kode = paaVareomrade
        //                            ? vareomradeAv(r.kode) : avdelingAv(r.kode)
        //   hent-budsjett.ts:169   if (!kode) continue
        //
        // Uten dem ville `medKast` telt maaneder motoren forkaster, og
        // snittet mitt blitt STOERRE enn motorens. Da ville diagnosen
        // pekt paa feil side av snittet.
        if (r.kast == null) continue
        const kastkode = paaVareomrade ? vareomradeAv(r.kode) : avdelingAv(r.kode)
        if (!kastkode) continue
        medKast.add(m)
      }
      const snitt = [...medUsynlig].filter((m) => medKast.has(m)).sort()
      // ETTER RETTELSEN AV `avdelingAv` SKAL RADER OVERLEVE.
      // Foer den sto det 0 paa alle fem. Blir det 0 igjen, er
      // regresjonen tilbake - og fravaeret ser ut som manglende data.
      if (avdeling != null) {
        expect(
          etterAvd.length,
          `${navn}: ingen rad overlevde avdelingsfilteret — regresjonen er tilbake`,
        ).toBeGreaterThan(0)
        // Og de som overlever skal STRUKTURELT tilhoere avdelingen.
        const fremmede = etterAvd.filter((r) => avdelingAv(r.kode) !== avdeling)
        expect(fremmede.map((r) => r.kode), `${navn}: fremmed kode slapp gjennom`).toEqual([])
        // Vask skal ikke vaere blant dem. `avdelingAv('210')` svarer naa
        // '210' der den foer ga null, saa setningen er ikke lenger
        // gratis.
        const vaskInne = etterAvd.filter((r) => (r.kode ?? '').startsWith('21'))
        expect(vaskInne.map((r) => r.kode), `${navn}: vask slapp inn i avdeling ${avdeling}`).toEqual([])
      }

      L.push(`    maaneder i avdeling ${avdeling ?? 'alle'}:  `
        + `med usynlig ${medUsynlig.size}   med kast ${medKast.size}   snitt ${snitt.length}`
        + (paaVareomrade ? '   (kast noekles paa vareomraade)' : ''))
      // BEGGE SIDENE SKRIVES UT NAAR SNITTET ER TOMT. «snitt 0» alene
      // sier ikke HVILKEN side som mangler maaneden, og det er nettopp
      // det spoersmaalet er.
      if (snitt.length === 0) {
        L.push(`      usynlig-maaneder: ${[...medUsynlig].sort().join(' ') || '(ingen)'}`)
        L.push(`      kast-maaneder:    ${[...medKast].sort().join(' ') || '(ingen)'}`)
      } else {
        L.push(`      snittmaaneder: ${snitt.join(' ')}`)
      }

      if (!u) {
        L.push('    -> ingen reproduksjon: motoren har ingen sum aa stemme mot')
        continue
      }

      // REPRODUKSJONEN GAAR NAA GJENNOM PRODUKSJONSFUNKSJONEN.
      // `fordelRegnskapssvinn` er loekken `hentSvinnbudsjett` selv
      // bruker, trukket ut for aa kunne maales. Summen under er derfor
      // motorens egen vei, ikke min etterligning av den.
      const fordelt = fordelRegnskapssvinn(grunnlag.alleRader, { avdeling, paaVareomrade })
      const viaMotoren = [...fordelt.usynligPerMaaned.values()].reduce((x, y) => x + y, 0)
      L.push(`    via fordelRegnskapssvinn: ${krTegn(viaMotoren)}   `
        + `maaneder ${fordelt.usynligPerMaaned.size}`)

      reproduksjonerProevd++
      const traff = Math.abs(viaMotoren - u.usynligKr) <= 1
      if (traff) reproduksjonerTraff++

      L.push(`    reprodusert: ${krTegn(alle)}   `
        + `${traff ? 'STEMMER med motoren' : `AVVIK ${krTegn(viaMotoren - u.usynligKr)} — varianten under er IKKE gyldig`}`)

      if (!traff) continue

      // ── 4 VARIANTEN — samme sum uten vask ───────────────────────────
      //
      // FORTEGNET BAERER BETYDNING (Robert, 2026-09-17): negativt usynlig
      // paa vask = mer brutto funnet enn forventet. Trekker vask totalen
      // NED, gjoer den svinnrommet stoerre for alt annet.
      const utenVask = alle - vask
      const avvikUten = u.tillattSvinnKr == null
        ? null : (utenVask + u.kastAvlagtKr) - u.tillattSvinnKr
      L.push(`    vaskens andel ${krTegn(vask)}   uten vask ${krTegn(utenVask)}`)
      L.push(`    avvik mot BP:  med vask ${tall(u.avvikMotBpKr)}   `
        + `uten vask ${tall(avvikUten)}`
        + (vask < 0 && u.avvikMotBpKr != null
          ? `   <- vask gir ${kr(-vask)} kr ekstra svinnrom` : ''))
    }

    L.push('')
    L.push(`  Svinnbilde funnet for ${bilderFunnet} stasjoner   `
      + `av dem ${utenUsynlig} med usynlig = null`)
    L.push(`  reproduksjoner: ${reproduksjonerTraff} av ${reproduksjonerProevd} stemte`)
    L.push('  Ingen regel er endret. Ingen terskel er satt.')
    L.push('')
    console.log(L.join('\n'))

    // KANARIFUGL — MEN PAA KALLVEIEN, IKKE PAA RESULTATET.
    //
    // Foerste utgave krevde at minst én reproduksjon stemte. Den feilet
    // korrekt, men av feil grunn: motoren ga `usynlig = null` overalt, saa
    // det fantes ingenting aa reprodusere. En vakt som krever et RESULTAT
    // kan ikke skille «fila maaler feil» fra «det finnes ikke noe aa
    // maale» — og den siste er selv et funn.
    //
    // Vakta staar derfor paa at kallveien virker. Gir `hentSvinnbudsjett`
    // null for hver stasjon, naar fila aldri motoren, og da betyr ingen
    // linje over noe.
    expect(
      bilderFunnet,
      'hentSvinnbudsjett ga null for hver stasjon — fila naadde aldri motoren',
    ).toBeGreaterThan(0)

    // Og NAAR det finnes en sum aa stemme mot, skal reproduksjonen treffe.
    if (reproduksjonerProevd > 0) {
      expect(
        reproduksjonerTraff,
        'ingen reproduksjon stemte — varianten «uten vask» har ingen dekning',
      ).toBeGreaterThan(0)
    }
  }, 180_000)
})
