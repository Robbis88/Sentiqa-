import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { forventetSalg, MODELLER, type Modell, type Salgsrad } from './motor'
import { leggTilDager, type Vaerdag, type VaerKoeff } from '@/lib/produksjonsplan'
import { hentVaerKoeff } from '@/lib/vaerprofil'

// =====================================================================
// BACKTEST — HVA VILLE MOTOREN SAGT, MED BARE DET SOM FANTES DA?
// =====================================================================
//
// Dette er portens acceptance gate. Uten den kan ingen si «86 Coca-Cola
// neste uke» og mene noe med det.
//
// For hver historisk måldato D får motoren bare rader med `dato < D` —
// og den grensen håndheves inne i `forventetSalg`, ikke her. Kallstedet
// kan ikke betros med den.
//
// ---------------------------------------------------------------------
// DEKNING OG TREFFSIKKERHET RAPPORTERES HVER FOR SEG
// ---------------------------------------------------------------------
//
// En motor som bare tør å svare på de letteste 20 % av varene kan se
// fantastisk ut. Derfor står «hvor ofte turte den» ved siden av «hvor
// nær traff den», alltid.
//
// ---------------------------------------------------------------------
// RELATIV FEIL MED EN NEVNER SOM BETYR NOE
// ---------------------------------------------------------------------
//
// MAPE (|feil| / faktisk) sprenger når faktisk er 1 og motoren sa 3 —
// 200 % feil på to enheter. På lavvolumsvarer blir snittet meningsløst.
//
// Derfor rapporteres begge:
//
//   MAE     gjennomsnittlig |feil| i ANTALL. Alltid meningsfull.
//   wMAPE   sum|feil| / sum(faktisk). Nevneren er totalvolumet, så en
//           dag med 1 solgt drar ikke snittet.
//
// Og medianfeilen ved siden av snittet, fordi én kampanjedag ellers
// bestemmer hele bildet.
//
// ---------------------------------------------------------------------
// INGEN MODELL ER UTPEKT
// ---------------------------------------------------------------------
//
// Alle fire kjøres på identisk grunnlag. Fila rangerer dem ikke i
// koden; tallene står ved siden av hverandre.
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

const iso = (d: Date) => d.toISOString().slice(0, 10)
const minus = (n: number) => {
  const d = new Date()
  d.setUTCDate(d.getUTCDate() - n)
  return iso(d)
}
const n0 = (n: number) => Math.round(n).toLocaleString('nb-NO')
const n1 = (n: number) => n.toFixed(1)

/** Coca-Cola 0,5L — 181/182 dager, 5/5 stasjoner, 15 980 stk. */
const KANARI = '5000112636833'

/** Dekningsnivaaer vi VET fordelingen for. Ingen av dem er valgt. */
const TERSKLER = [10, 30, 60, 120]

type Rad = {
  stasjon_id: string; dato: string; ean: string
  varenavn: string | null; varegruppe_kode: string | null
  varegruppe_navn: string | null; antall: number | null
}

type Treff = { forventet: number; faktisk: number }

function maal(treff: Treff[]) {
  if (treff.length === 0) return null
  const feil = treff.map((t) => Math.abs(t.forventet - t.faktisk))
  const sumFeil = feil.reduce((a, b) => a + b, 0)
  const sumFaktisk = treff.reduce((a, t) => a + t.faktisk, 0)
  const sortert = [...feil].sort((a, b) => a - b)
  const bias = treff.reduce((a, t) => a + (t.forventet - t.faktisk), 0) / treff.length
  return {
    n: treff.length,
    mae: sumFeil / treff.length,
    medianFeil: sortert[Math.floor(sortert.length / 2)],
    wmape: sumFaktisk > 0 ? (sumFeil / sumFaktisk) * 100 : null,
    // SYSTEMATISK SKJEVHET. En motor som treffer i snitt men alltid
    // ligger for lavt, er noe annet enn en som bommer tilfeldig.
    bias,
    sumFaktisk,
  }
}

describe('BACKTEST — forventet salg mot fasit', () => {
  kjor('uten fremtidslekkasje, per modell og dekningsnivaa', async () => {
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

    // ── VINDUET ─────────────────────────────────────────────────────────
    //
    // Historikken maa rekke bakover forbi fjoraarsvinduet for at
    // `fjorMedian` skal kunne finnes. 364 + 28 dager for foerste
    // maaldato, pluss testperioden.
    const TEST_DAGER = 28
    const forsteMaal = minus(TEST_DAGER + 2) // -2: importetterslep
    const fra = minus(TEST_DAGER + 2 + 364 + 30)
    const til = minus(2)

    const L: string[] = ['', '  BACKTEST — FORVENTET SALG', '']
    L.push(`  historikk fra ${fra}   maaldatoer ${forsteMaal} .. ${til}  (${TEST_DAGER} dager)`)
    L.push('  grensen `dato < maalDato` haandheves i motoren, ikke her.')

    const SIDE = 1000

    // ── UTVALGET: kanarien + et representativt sett ─────────────────────
    //
    // Kanarien foerst, saa et tverrsnitt: hoeyvolum og lavere volum,
    // MAT og KALD DRIKKE. Utvalget velges paa VOLUM, ikke paa navn.
    // HELE UNIVERSET, IKKE TOPP-N RADER.
    //
    // Foerste utgave hentet de 4 000 RADENE med hoeyest `antall`. De
    // klumper seg paa et faatall varer: utvalget ble 47 av 1 721, alle
    // fra toppen, og dekningskolonnen maalte fortsatt utvalget.
    //
    // Naa pagineres vinduet, og volumet aggregeres per EAN foerst.
    const univers: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: uf } = await supabase
        .from('v_butikksalg').select('ean, varenavn, varegruppe_kode, varegruppe_navn, antall')
        .gte('dato', minus(60)).lte('dato', til)
        .order('dato', { ascending: true }).order('ean', { ascending: true })
        .range(f, f + SIDE - 1).overrideTypes<Rad[]>()
      if (uf) throw new Error(`v_butikksalg (univers): ${uf.message}`)
      const side = data ?? []
      univers.push(...side)
      if (side.length < SIDE) break
    }
    const volumPerEan = new Map<string, { kr: number; navn: string; vg: string; vgk: string }>()
    for (const r of univers) {
      const v = volumPerEan.get(r.ean)
        ?? { kr: 0, navn: r.varenavn ?? '', vg: r.varegruppe_navn ?? '', vgk: r.varegruppe_kode ?? '' }
      v.kr += r.antall ?? 0
      volumPerEan.set(r.ean, v)
    }
    const sortert = [...volumPerEan.entries()].sort((a, b) => b[1].kr - a[1].kr)
    const valgte = new Set<string>([KANARI])
    // 8 hoeyvolum + 8 fra midten. Ingen fra bunnen: de har per
    // definisjon ikke dekning, og ville bare maalt at motoren tier.
    for (const [e] of sortert.slice(0, 8)) valgte.add(e)
    const midt = Math.floor(sortert.length / 2)
    for (const [e] of sortert.slice(midt, midt + 8)) valgte.add(e)

    // OG ET TILFELDIG TVERRSNITT AV HELE UNIVERSET.
    //
    // Foerste kjoering valgte bare hoeyvolum + midten, og rapporterte
    // 99,7 % dekning. Det tallet maalte utvalget, ikke motoren: halen
    // var utelatt med vilje. «En motor som bare toer aa prognostisere de
    // letteste 20 % av varene kan se fantastisk ut» - og da var
    // dekningskolonnen verre enn ingen kolonne.
    //
    // Trekket er DETERMINISTISK (hver n-te etter volum), ikke
    // `Math.random`: to kjoeringer av samme fila skal kunne
    // sammenlignes.
    const REPR = 40
    const steg = Math.max(1, Math.floor(sortert.length / REPR))
    const tverrsnitt = new Set<string>()
    for (let i = 0; i < sortert.length && tverrsnitt.size < REPR; i += steg) {
      tverrsnitt.add(sortert[i][0])
    }
    for (const e of tverrsnitt) valgte.add(e)

    L.push(`  varer i utvalget: ${valgte.size}   `
      + `(kanari + hoeyvolum + midten + ${tverrsnitt.size} i deterministisk tverrsnitt)`)
    L.push(`  varer totalt i vinduet: ${sortert.length}`)

    // ── HENT HISTORIKKEN FOR UTVALGET ───────────────────────────────────
    const eanListe = [...valgte]
    const rader: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg')
        .select('stasjon_id, dato, ean, varenavn, varegruppe_kode, varegruppe_navn, antall')
        .in('ean', eanListe).gte('dato', fra).lte('dato', til)
        .order('dato', { ascending: true }).range(f, f + SIDE - 1)
        .overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg: ${rf.message}`)
      const side = data ?? []
      rader.push(...side)
      if (side.length < SIDE) break
    }
    L.push(`  historiske rader lest: ${n0(rader.length)}`)
    expect(rader.length, 'ingen historikk hentet').toBeGreaterThan(0)

    // ── VAERET ──────────────────────────────────────────────────────────
    //
    // FOERSTE KJOERING SENDTE INGEN. `vaerMaal` og `vaerFjor` var
    // `undefined`, saa `vaerfaktor` ga 1 hver gang - og `basis+vaer` kom
    // ut IDENTISK med `basis` paa hver desimal, presentert som et
    // resultat. To av fire modeller ble aldri testet.
    //
    // Samme kilde som `produksjonsplan/page.tsx` og `backtest.ts`.
    const vaer = new Map<string, Vaerdag>() // `${stasjonId}|${dato}`
    for (let f = 0; ; f += SIDE) {
      const { data, error: vf } = await supabase
        .from('vaer').select('stasjon_id, dato, temp_maks, nedbor_mm')
        .gte('dato', fra).lte('dato', til)
        .order('dato', { ascending: true }).range(f, f + SIDE - 1)
        .overrideTypes<{ stasjon_id: string; dato: string; temp_maks: number | null; nedbor_mm: number | null }[]>()
      if (vf) throw new Error(`vaer: ${vf.message}`)
      const side = data ?? []
      for (const v of side) {
        vaer.set(`${v.stasjon_id}|${v.dato}`, { temp_maks: v.temp_maks, nedbor_mm: v.nedbor_mm })
      }
      if (side.length < SIDE) break
    }
    L.push(`  vaerdager lest: ${n0(vaer.size)}`)

    // KOEFFISIENTENE, PER STASJON OG VAREGRUPPE.
    //
    // Uten dem faller `vaerfaktor` til et regex-fallback som matcher
    // VAREGRUPPENAVNET mot `(drikke|is|salat|kald)`. Coca-Colas gruppe
    // heter «BRUS MEDIUM =0,4 - 0,6l» - ingen treff. Regexen er skrevet
    // for produksjonsplanens ordforraad (BAKERI, OPPVARMET), ikke for
    // hele vareuniverset. Foerste kjoering maalte derfor fallbacket, og
    // fikk en vaerarm som saa vidt rikket paa seg.
    const koeff = new Map<string, Map<string, VaerKoeff>>()
    for (const s2 of stasjoner) {
      koeff.set(s2.id, await hentVaerKoeff(supabase, s2.id, 'varegruppe'))
    }
    const medKoeff = [...koeff.values()].reduce((a4, m) => a4 + m.size, 0)
    L.push(`  vaerkoeffisienter lest: ${n0(medKoeff)} (stasjon x varegruppe)`)

    const salg: Salgsrad[] = rader.map((r) => ({
      stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
      varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn,
    }))

    // FASIT: faktisk salg per (stasjon, ean, dato). Manglende rad er
    // IKKE null salg - dagen hoppes over i stedet for aa telles som 0.
    const fasit = new Map<string, number>()
    for (const s of salg) fasit.set(`${s.stasjonId}|${s.ean}|${s.dato}`, s.antall)

    const maaldatoer: string[] = []
    for (let i = TEST_DAGER + 1; i >= 2; i--) maaldatoer.push(minus(i))

    // ── KJOERINGEN ──────────────────────────────────────────────────────
    // VOLUMET BAK DEKNINGEN, IKKE BARE ANTALL RADER.
    //
    // «77 % dekning» sier hvor ofte motoren turte. Det sier ikke hvor
    // mye av SALGET den turte paa - og det er nettopp det som avgjoer om
    // et hoeyere nivaa kan summeres fra varenivaa.
    //
    // Ligger 16 % av volumet i varer motoren tier om, blir varegruppen
    // systematisk for lav. Da er svaret B: hoeyere nivaa maa regnes
    // direkte paa aggregert historikk.
    type Bunt = {
      treff: Treff[]; forsokt: number; svart: number
      volumMed: number; volumUten: number
    }
    const resultat = new Map<string, Bunt>() // `${modell}|${terskel}`
    const perStasjonKanari = new Map<string, Treff[]>()
    const grunner = new Map<string, number>()

    for (const m of MODELLER) {
      for (const t of TERSKLER) {
        resultat.set(`${m.navn}|${t}`, {
          treff: [], forsokt: 0, svart: 0, volumMed: 0, volumUten: 0,
        })
      }
    }

    for (const d of maaldatoer) {
      for (const s of stasjoner) {
        for (const ean of eanListe) {
          const f = fasit.get(`${s.id}|${ean}|${d}`)
          // INGEN RAD = INGEN FASIT. Vi vet ikke om varen ikke ble solgt
          // eller ikke ble registrert, og en backtest som gjetter null
          // ville belonnet en motor som alltid sier lite.
          if (f === undefined) continue
          for (const m of MODELLER) {
            for (const t of TERSKLER) {
              const b = resultat.get(`${m.navn}|${t}`)!
              b.forsokt++
              const sv = forventetSalg({
                enhet: { stasjonId: s.id, ean }, maalDato: d, salg,
                modell: m as Modell, minstDagerMedSalg: t,
                vaerMaal: vaer.get(`${s.id}|${d}`) ?? null,
                vaerFjor: vaer.get(`${s.id}|${leggTilDager(d, -364)}`) ?? null,
                vaerfolsomhet: 0.5,
                vaerKoeff: koeff.get(s.id)?.get(
                  salg.find((x) => x.ean === ean)?.varegruppeKode ?? '') ?? null,
              })
              if (sv.slag !== 'beregnet') {
                // FASITEN TELLES SELV OM MOTOREN TIDE. Det er hele
                // poenget: hvor mye salg falt utenfor?
                b.volumUten += f
                if (m.navn === 'basis' && t === 30) {
                  grunner.set(sv.grunn, (grunner.get(sv.grunn) ?? 0) + 1)
                }
                continue
              }
              b.svart++
              b.volumMed += f
              b.treff.push({ forventet: sv.antall, faktisk: f })
              if (ean === KANARI && m.navn === 'basis+trend' && t === 30) {
                perStasjonKanari.set(s.id, [...(perStasjonKanari.get(s.id) ?? []),
                  { forventet: sv.antall, faktisk: f }])
              }
            }
          }
        }
      }
    }

    // ── RAPPORTEN ───────────────────────────────────────────────────────
    L.push('')
    L.push('  DEKNING OG TREFFSIKKERHET — HVER FOR SEG')
    L.push('    modell             terskel   dekning  volumdekn      n     MAE   median   wMAPE    bias')
    for (const m of MODELLER) {
      for (const t of TERSKLER) {
        const b = resultat.get(`${m.navn}|${t}`)!
        const k = maal(b.treff)
        const dek = b.forsokt > 0 ? `${((b.svart / b.forsokt) * 100).toFixed(1)} %` : '—'
        const volTot = b.volumMed + b.volumUten
        const vdek = volTot > 0 ? `${((b.volumMed / volTot) * 100).toFixed(1)} %` : '—'
        L.push(
          `    ${m.navn.padEnd(18)} ${String(t).padStart(5)}   ${dek.padStart(7)}  `
          + `${vdek.padStart(9)}  `
          + `${String(n0(k?.n ?? 0)).padStart(5)}  `
          + `${(k ? n1(k.mae) : '—').padStart(6)}  `
          + `${(k ? n1(k.medianFeil) : '—').padStart(6)}  `
          + `${(k?.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(7)}  `
          + `${(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—').padStart(6)}`,
        )
      }
    }

    L.push('')
    L.push('  HVORFOR MOTOREN TIDE (modell basis, terskel 30)')
    for (const [g, n] of [...grunner].sort((a, b) => b[1] - a[1])) {
      L.push(`    ${g.padEnd(18)} ${n0(n)}`)
    }

    L.push('')
    L.push(`  KANARIEN ${KANARI} «Coca-Cola 0.5L» — per stasjon (basis+trend, terskel 30)`)
    L.push('    stasjon                   n     MAE   median   wMAPE    bias   snitt faktisk')
    for (const s of stasjoner) {
      const t = perStasjonKanari.get(s.id)
      if (!t || t.length === 0) continue
      const k = maal(t)!
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(k.n).padStart(3)}  `
        + `${n1(k.mae).padStart(6)}  ${n1(k.medianFeil).padStart(6)}  `
        + `${(k.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(7)}  `
        + `${((k.bias >= 0 ? '+' : '') + n1(k.bias)).padStart(6)}  `
        + `${n1(k.sumFaktisk / k.n).padStart(13)}`,
      )
    }

    L.push('')
    L.push('  Ingen modell er utpekt her. Tallene staar ved siden av hverandre.')
    L.push('')
    console.log(L.join('\n'))

    // ── VAKTER ──────────────────────────────────────────────────────────
    // KANARIFUGL FOR VAERARMEN.
    //
    // Er `basis+vaer` identisk med `basis` paa hver eneste terskel, ble
    // vaeret aldri brukt - og to av fire rader i tabellen er ikke
    // resultater, de er den samme modellen skrevet to ganger. Foerste
    // kjoering saa noeyaktig slik ut og sa det ikke.
    const like = TERSKLER.every((t) => {
      const a1 = resultat.get(`basis|${t}`)!.treff
      const b1 = resultat.get(`basis+vaer|${t}`)!.treff
      return a1.length === b1.length
        && a1.every((x, i) => x.forventet === b1[i].forventet)
    })
    L.push('')
    L.push(`  VAERARMEN: ${like ? 'INGEN VIRKNING — vaerdata naadde ikke motoren' : 'aktiv'}`)
    expect(like, 'basis+vaer er identisk med basis — vaeret naadde aldri motoren').toBe(false)

    const noe = [...resultat.values()].reduce((a, b) => a + b.treff.length, 0)
    expect(noe, 'ingen forventning ble beregnet — maalte backtesten noe?').toBeGreaterThan(0)
    // Kanarien MAA ha dekning. Har den ikke det, er utvalget eller
    // vinduet feil, og hele rapporten maaler noe annet enn den sier.
    expect(
      [...perStasjonKanari.values()].reduce((a, b) => a + b.length, 0),
      'kanarien fikk ingen dekning — vinduet eller utvalget er feil',
    ).toBeGreaterThan(0)
  }, 900_000)
})
