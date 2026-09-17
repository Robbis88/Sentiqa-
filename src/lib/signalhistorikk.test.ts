import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { hentRegnskapVarsler, sammeSak, type Signalsak } from './regnskap-varsler'
import { byggFenomener, type Fenomen, type Stasjonsvarsel } from './fenomen'

// =====================================================================
// BESLUTNINGSKANARI — ER «5 AV 5» ET FUNN ELLER EN NORMALTILSTAND?
// =====================================================================
//
// Juli 2026 ga elleve røde fenomener, og åtte av dem var
// `usynlig_manko` på hver sin varegruppe, på to til fem stasjoner.
//
// Det kan bety to helt forskjellige ting:
//
//   1  noe skjedde i juli                → dagens viktigste kort
//   2  slik ser den målingen alltid ut   → åtte av elleve er støy
//
// Ingenting i koden vet hvilken. Tersklene `T.mankoGul` og `T.mankoRod`
// ble satt for å vurdere ÉN stasjon, ikke for å avgjøre om et
// kjededekkende mønster er uvanlig.
//
// Historikken kan svare, og den trenger ingen ny regel for å gjøre det.
//
// ---------------------------------------------------------------------
// REN OBSERVASJON
// ---------------------------------------------------------------------
//
// Ingen trendmotor, ingen terskel, ingen dom. Fila skriver ut hva som
// ble observert i hver måned og lar sekvensen stå. Ordene «normalt»,
// «trend» og «forverring» finnes ikke her — de ville vært vurderinger
// ingen motor eier.
//
// ---------------------------------------------------------------------
// MANGLENDE DATA ER IKKE FRAVÆR AV PROBLEM
// ---------------------------------------------------------------------
//
// `avTotalt` er stasjonene som FAKTISK har regnskapsgrunnlag i måneden,
// ikke fem. Har bare tre stasjoner tall i mai, er «3 av 3» det sanne
// utsagnet — og «3 av 5» ville vært en påstand om to stasjoner vi ikke
// har målt.
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

const MAANEDER = ['2026-05-01', '2026-06-01', '2026-07-01']
const navnPaa = (p: string) => ({ '05': 'mai', '06': 'juni', '07': 'juli' })[p.slice(5, 7)] ?? p

const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')

/** Etikett for utskrift. IDENTITETEN er `sammeSak`, aldri denne strengen. */
function etikett(s: Signalsak): string {
  if (!('vare' in s)) return s.slag
  const v = s.vare
  return v.form === 'varegruppe'
    ? `${s.slag}  ${v.kode} «${v.navn}»`
    : `${s.slag}  motpost ${v.avdeling} «${v.navn}»`
}

type Maanedsbilde = {
  periode: string
  medGrunnlag: string[]
  utenGrunnlag: string[]
  antallVarsler: number
  antallMedSak: number
  fenomener: Fenomen[]
}

describe('BESLUTNINGSKANARI — fenomenene over tre måneder', () => {
  kjor('mai, juni og juli med samme motor', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const { data: stasjonsrader, error: sfeil } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    if (sfeil) throw new Error(`Stasjonene: ${sfeil.message}`)
    const stasjoner = (stasjonsrader ?? []) as
      { id: string; navn: string; butikknummer: string }[]
    const navnFor = new Map(stasjoner.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
    expect(stasjoner.length, 'ingen stasjoner').toBeGreaterThan(0)

    const { data: prof } = await supabase
      .from('profiler').select('retailer_id').limit(1).maybeSingle<{ retailer_id: string }>()
    const retailerId = prof?.retailer_id ?? ''

    const L: string[] = ['', '  FENOMENENE OVER TRE MAANEDER — PRODUKSJON', '']

    // =================================================================
    // 1 DEKNING — HVILKE STASJONER KAN I DET HELE TATT MAALES?
    // =================================================================
    const bilder: Maanedsbilde[] = []
    for (const periode of MAANEDER) {
      // STASJONER MED REGNSKAPSGRUNNLAG I MAANEDEN. Ikke fem; de som
      // faktisk har rader. En stasjon uten grunnlag er ikke en stasjon
      // uten problem - den er umaalt.
      const { data: linjer, error: lfeil } = await supabase
        .from('regnskapslinjer').select('stasjon_id')
        .eq('periode', periode).not('stasjon_id', 'is', null).limit(5000)
      if (lfeil) throw new Error(`Grunnlaget for ${periode}: ${lfeil.message}`)
      const medId = new Set(((linjer ?? []) as { stasjon_id: string }[])
        .map((r) => r.stasjon_id))
      const medGrunnlag = stasjoner.filter((s) => medId.has(s.id))
      const utenGrunnlag = stasjoner.filter((s) => !medId.has(s.id))

      const varsler = retailerId
        ? await hentRegnskapVarsler(supabase, retailerId, periode).catch(() => [])
        : []
      const sv: Stasjonsvarsel[] = []
      for (const s of medGrunnlag) {
        const navn = navnFor.get(s.id)!
        for (const v of varsler.filter((x) => x.omfang === navn)) {
          sv.push({ stasjonId: s.id, stasjonsnavn: navn, varsel: v })
        }
      }
      bilder.push({
        periode,
        medGrunnlag: medGrunnlag.map((s) => navnFor.get(s.id)!),
        utenGrunnlag: utenGrunnlag.map((s) => navnFor.get(s.id)!),
        antallVarsler: sv.length,
        antallMedSak: sv.filter((x) => x.varsel.sak !== null).length,
        // POPULASJONEN ER DE MAALTE. Se toppkommentaren.
        fenomener: byggFenomener(sv, medGrunnlag.length),
      })
    }

    L.push('  DEKNING')
    for (const b of bilder) {
      L.push(`    ${navnPaa(b.periode).padEnd(5)} stasjoner med grunnlag ${b.medGrunnlag.length}`
        + `   uten ${b.utenGrunnlag.length}`
        + `   stasjonsvarsler ${b.antallVarsler}`
        + `   med sak ${b.antallMedSak}`
        + `   fenomener ${b.fenomener.length}`)
      if (b.utenGrunnlag.length > 0) {
        L.push(`          UTEN GRUNNLAG: ${b.utenGrunnlag.join(', ')}`)
      }
    }
    const sammenlignbare = new Set(bilder.map((b) => b.medGrunnlag.length)).size === 1
    L.push(`    populasjonen er ${sammenlignbare ? 'DEN SAMME' : 'ULIK'} i de tre maanedene`)

    // =================================================================
    // 2 STABILITETSMATRISEN
    // =================================================================
    //
    // Sakene samles paa tvers av maanedene med `sammeSak` - den samme
    // sammenligningen aggregatet bruker. Ingen tekstnoekkel.
    const rader: { sak: Signalsak; per: (Fenomen | null)[] }[] = []
    for (const [i, b] of bilder.entries()) {
      for (const f of b.fenomener) {
        if (f.sak === null) continue
        let r = rader.find((x) => sammeSak(x.sak, f.sak))
        if (!r) { r = { sak: f.sak, per: MAANEDER.map(() => null) }; rader.push(r) }
        r.per[i] = f
      }
    }

    const vis = (f: Fenomen | null) =>
      (f === null ? '  —  ' : `${f.stasjoner.length}/${f.avTotalt}${f.nivaa === 'rod' ? 'R' : 'g'}`)

    const SVINN = ['usynlig_manko', 'usynlig_overskudd', 'synlig_kast']
    const OKONOMI = [
      'omsetning_mot_budsjett', 'lonn_over_budsjett',
      'lonn_brukt_brutto_under', 'negativt_resultat',
    ]

    const skrivMatrise = (tittel: string, slag: string[]) => {
      L.push('')
      L.push(`  ${tittel}`)
      L.push('    mai    juni   juli    sak')
      const mine = rader.filter((r) => slag.includes(r.sak.slag))
      // Sortert for lesbarhet: flest maaneder foerst, saa flest stasjoner
      // i juli. INGEN RANGERING - dette er en utskrift.
      mine.sort((a, b) =>
        b.per.filter(Boolean).length - a.per.filter(Boolean).length
        || (b.per[2]?.stasjoner.length ?? 0) - (a.per[2]?.stasjoner.length ?? 0))
      for (const r of mine) {
        L.push(`    ${r.per.map(vis).map((s) => s.padEnd(6)).join(' ')} ${etikett(r.sak)}`)
      }
      if (mine.length === 0) L.push('    (ingen)')
    }

    skrivMatrise('SVINN — R = rodt fenomen, g = gult', SVINN)
    skrivMatrise('OEKONOMI PER STASJON', OKONOMI)

    // =================================================================
    // 3 MEKANISKE UTVALG — kriteriet staar skrevet, ingen dom
    // =================================================================
    const finnesAlle = rader.filter((r) => r.per.every(Boolean))
    const bareJuli = rader.filter((r) => r.per[2] && !r.per[0] && !r.per[1])
    const spenn = (r: typeof rader[number]) => {
      const n = r.per.filter(Boolean).map((f) => f!.stasjoner.length)
      return n.length < 2 ? 0 : Math.max(...n) - Math.min(...n)
    }
    const nivaaskifte = rader.filter((r) => {
      const n = new Set(r.per.filter(Boolean).map((f) => f!.nivaa))
      return n.size > 1
    })

    L.push('')
    L.push('  MEKANISKE UTVALG (kriteriet staar, ingen vurdering)')
    L.push(`    finnes i ALLE TRE maaneder ......... ${finnesAlle.length}`)
    for (const r of finnesAlle) {
      L.push(`      ${r.per.map(vis).map((s) => s.padEnd(6)).join(' ')} ${etikett(r.sak)}`)
    }
    L.push(`    finnes BARE i juli ................ ${bareJuli.length}`)
    for (const r of bareJuli) L.push(`      ${etikett(r.sak)}`)

    const stoerstSpenn = [...rader].filter((r) => spenn(r) > 0)
      .sort((a, b) => spenn(b) - spenn(a))
    L.push(`    utbredelsen varierer mellom maanedene (max−min berorte):`)
    for (const r of stoerstSpenn.slice(0, 10)) {
      L.push(`      ${String(spenn(r)).padStart(2)}   ${r.per.map(vis).map((s) => s.padEnd(6)).join(' ')} ${etikett(r.sak)}`)
    }
    if (stoerstSpenn.length === 0) L.push('      (ingen varierer)')

    L.push(`    nivaaet er ikke det samme i alle maanedene: ${nivaaskifte.length}`)
    for (const r of nivaaskifte) {
      L.push(`      ${r.per.map(vis).map((s) => s.padEnd(6)).join(' ')} ${etikett(r.sak)}`)
    }

    // =================================================================
    // 3b OEKONOMISAKENE, PER STASJON
    // =================================================================
    //
    // Aggregatet sier «1 av 5» og «4 av 5». Det holder ikke for aa se om
    // Dales loenn er den samme stasjonen hver maaned, eller om den
    // flytter seg. Her staar hver stasjon med sitt eget nivaa og sitt
    // eget beloep. Ingen sum.
    L.push('')
    L.push('  OEKONOMISAKENE — STASJON FOR STASJON')
    for (const slag of OKONOMI) {
      const r = rader.find((x) => x.sak.slag === slag)
      L.push('')
      L.push(`    ${slag}`)
      if (!r) { L.push('      ikke observert i noen maaned'); continue }
      for (const [i, f] of r.per.entries()) {
        const m = navnPaa(MAANEDER[i])
        if (!f) { L.push(`      ${m.padEnd(5)} ikke observert`); continue }
        L.push(`      ${m.padEnd(5)} ${f.stasjoner.length} av ${f.avTotalt}   fenomennivaa ${f.nivaa}`)
        for (const [j, st] of f.stasjoner.entries()) {
          L.push(`            ${st.stasjonsnavn.padEnd(24)} ${st.nivaa.padEnd(4)}`
            + ` ${kr(Math.abs(f.underliggende[j].vekt)).padStart(9)} kr`)
        }
      }
    }

    // =================================================================
    // 3c TRETILSTANDS-HISTORIKK — observert / ikke observert / UKJENT
    // =================================================================
    //
    // MANGLENDE DEKNING ER IKKE FRAVAER. Forrige maaned kan bare sies aa
    // ha «ikke observert» et fenomen dersom den maalte DE SAMME
    // stasjonene. Maalte den faerre, kunne fenomenet ligget paa en
    // stasjon ingen saa - og da er svaret `ukjent`, ikke `false`.
    //
    // Regelen er konservativ med vilje: identisk maalt populasjon, ellers
    // ukjent. Ingen vurdering, ingen ord om bedre eller verre.
    const sammeP = (a2: Maanedsbilde, b2: Maanedsbilde) =>
      a2.medGrunnlag.length === b2.medGrunnlag.length
      && a2.medGrunnlag.every((n) => b2.medGrunnlag.includes(n))

    L.push('')
    L.push('  TRETILSTANDS-HISTORIKK — juli maalt mot juni')
    const juni = bilder[1]
    const juli = bilder[2]
    const sammenlignbar = sammeP(juni, juli)
    L.push(`    juni og juli maalte samme stasjoner: ${sammenlignbar ? 'JA' : 'NEI'}`)
    if (!sammenlignbar) {
      L.push('    -> hvert fenomen er UKJENT bakover; ingen kan kalles nytt')
    }
    const nye: string[] = []
    const vedvarer: string[] = []
    const borte: string[] = []
    const ukjent: string[] = []
    for (const r of rader) {
      const naa = r.per[2]
      const forr = r.per[1]
      const merke = `${naa ? `${naa.stasjoner.length}/${naa.avTotalt}${naa.nivaa === 'rod' ? 'R' : 'g'}` : '—'}  ${etikett(r.sak)}`
      if (!sammenlignbar) { ukjent.push(merke); continue }
      if (naa && !forr) nye.push(merke)
      else if (naa && forr) vedvarer.push(merke)
      else if (!naa && forr) borte.push(merke)
    }
    L.push(`    NY (naa=true, forrige=false) ............ ${nye.length}`)
    for (const x of nye) L.push(`      ${x}`)
    L.push(`    VEDVARER (naa=true, forrige=true) ....... ${vedvarer.length}`)
    for (const x of vedvarer) L.push(`      ${x}`)
    L.push(`    IKKE LENGER OBSERVERT ................... ${borte.length}`)
    for (const x of borte) L.push(`      ${x}`)
    L.push(`    UKJENT (manglende sammenlignbar dekning)  ${ukjent.length}`)
    for (const x of ukjent) L.push(`      ${x}`)

    // SAMMENHENGENDE MAANEDER OBSERVERT, per fenomen i juli.
    L.push('')
    L.push('  SAMMENHENGENDE MAANEDER OBSERVERT (bakover fra juli)')
    for (const r of rader) {
      if (!r.per[2]) continue
      let n = 0
      for (let i = 2; i >= 0 && r.per[i]; i--) n++
      L.push(`    ${n} mnd   ${r.per.map(vis).map((x) => x.padEnd(6)).join(' ')} ${etikett(r.sak)}`)
    }

    // =================================================================
    // 4 KIOSKVARER I DETALJ — spoersmaalet som utloeste maalingen
    // =================================================================
    L.push('')
    L.push('  160 KIOSKVARER · usynlig_manko — MAANED FOR MAANED')
    const kiosk = rader.find((r) => r.sak.slag === 'usynlig_manko'
      && 'vare' in r.sak && r.sak.vare.form === 'varegruppe' && r.sak.vare.kode === '160')
    if (!kiosk) L.push('    finnes ikke i noen av maanedene')
    else {
      for (const [i, f] of kiosk.per.entries()) {
        if (!f) { L.push(`    ${navnPaa(MAANEDER[i]).padEnd(5)} ikke observert`); continue }
        L.push(`    ${navnPaa(MAANEDER[i]).padEnd(5)} ${f.stasjoner.length} av ${f.avTotalt}`
          + `   fenomennivaa ${f.nivaa}`)
        for (const [j, s] of f.stasjoner.entries()) {
          L.push(`          ${s.stasjonsnavn.padEnd(24)} ${s.nivaa.padEnd(4)}`
            + ` ${kr(Math.abs(f.underliggende[j].vekt)).padStart(9)} kr`)
        }
      }
    }

    // =================================================================
    // 5 DE AATTE ROEDE MANKO-FENOMENENE FRA JULI, BAKOVER
    // =================================================================
    L.push('')
    L.push('  JULIS ROEDE MANKO-FENOMENER, BAKOVER')
    const juliRodManko = (bilder[2]?.fenomener ?? [])
      .filter((f) => f.nivaa === 'rod' && f.sak?.slag === 'usynlig_manko')
    for (const f of juliRodManko) {
      const r = rader.find((x) => sammeSak(x.sak, f.sak))!
      L.push(`    ${r.per.map(vis).map((s) => s.padEnd(6)).join(' ')} ${etikett(f.sak!)}`)
    }
    if (juliRodManko.length === 0) L.push('    (ingen)')

    // =================================================================
    // 6 STASJONENE — hvor ofte er hver med i et fenomen?
    // =================================================================
    L.push('')
    L.push('  STASJONER — antall fenomener stasjonen er med i, per maaned')
    for (const s of stasjoner) {
      const navn = navnFor.get(s.id)!
      const tall = bilder.map((b) => {
        if (!b.medGrunnlag.includes(navn)) return '  — '
        const n = b.fenomener.filter((f) => f.stasjoner.some((x) => x.stasjonId === s.id))
        const rod = n.filter((f) => f.stasjoner
          .find((x) => x.stasjonId === s.id)!.nivaa === 'rod').length
        return `${String(n.length).padStart(2)}/${rod}`
      })
      L.push(`    ${navn.padEnd(24)} ${tall.map((t) => t.padEnd(6)).join(' ')}  (totalt/roede)`)
    }

    L.push('')
    console.log(L.join('\n'))

    // KANARIFUGL FOR KANARIFUGLEN.
    expect(bilder.some((b) => b.fenomener.length > 0),
      'ingen fenomener i noen maaned - da er ingenting maalt').toBe(true)
    expect(rader.length, 'ingen saker aa sammenligne').toBeGreaterThan(0)
    // POPULASJONEN MAA VAERE OBSERVERT, IKKE ANTATT.
    for (const b of bilder) {
      for (const f of b.fenomener) {
        expect(f.avTotalt, `${b.periode}: avTotalt er ikke de maalte stasjonene`)
          .toBe(b.medGrunnlag.length)
        expect(f.stasjoner.length, `${b.periode}: flere beroerte enn maalte`)
          .toBeLessThanOrEqual(f.avTotalt)
      }
    }
  }, 300_000)
})
