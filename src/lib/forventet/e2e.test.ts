import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { leggTilDager } from '@/lib/produksjonsplan'
import { forventetSalg, MODELLER, type Salgsrad } from './motor'
import { maalTreff, tillit } from './treffsikkerhet'
import { slaaOpp, type Varerad } from './varesok'

// =====================================================================
// PRODUKSJONSFASIT FOR AI-2 — READ ONLY
// =====================================================================
//
// Kjører kjeden `slaaOpp → forventetSalg → maalTreff` mot ekte data, med
// nøyaktig de parametrene `ai/forventetverktoy.ts` bruker.
//
// Tallene her er FASITEN chatten skal matche. Sprikte parametrene, ville
// sammenligningen bevist ingenting — derfor leses modell, terskel og
// vinduer UT AV VERKTØYFILA og holdes mot dem som brukes her.
//
// ---------------------------------------------------------------------
// MÅLDATOEN ER KALENDERENS I MORGEN
// ---------------------------------------------------------------------
//
// Ikke «dagen etter siste salgsdag». `salg/forventet.ts` skrev ned
// hvorfor: importen ligger gjerne to dager bak, så siste salgsdag kan
// være den 15. mens i dag er den 17. Regnet vi fra siste salgsdag, ville
// vi tilbudt en «prognose» for den 16. — en dag som alt er forbi.
//
// Avstanden RAPPORTERES i stedet, så den er synlig.
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

const KANARI = '5000112636833'
const STASJONER = ['4185', '9467'] // Dale og Bønes
const SOEK = 'Coca-Cola 0,5L'

const MODELL = MODELLER.find((m) => m.navn === 'basis+trend')!
const MINST_DAGER = 60
const TREFF_DAGER = 28
const HISTORIKK_DAGER = 364 + 28 + 40
const SOEK_DAGER = 90

const n1 = (n: number) => n.toFixed(1)

describe('AI-2 PRODUKSJONSFASIT', () => {
  kjor('slaaOpp -> forventetSalg -> maalTreff paa ekte data', async () => {
    // ── PARAMETRENE MAA VAERE VERKTOEYETS ────────────────────────────────
    const VERKTOY = readFileSync('src/lib/ai/forventetverktoy.ts', 'utf8')
    expect(VERKTOY, 'modellen spriker mot verktoeyet').toContain("m.navn === 'basis+trend'")
    expect(VERKTOY, 'terskelen spriker').toContain(`MINST_DAGER = ${MINST_DAGER}`)
    expect(VERKTOY, 'treffvinduet spriker').toContain(`TREFF_DAGER = ${TREFF_DAGER}`)
    expect(VERKTOY, 'historikkvinduet spriker').toContain('HISTORIKK_DAGER = 364 + 28 + 40')
    expect(VERKTOY, 'maaldatoen spriker').toContain('leggTilDager(idag, 1)')

    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    // Samme tidssone som verktoeyet (`idagOslo`).
    const idag = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Oslo', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date())
    const maalDato = leggTilDager(idag, 1)

    const { data: srader } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    const alle = (srader ?? []) as { id: string; navn: string; butikknummer: string }[]
    const valgte = alle.filter((s) => STASJONER.includes(s.butikknummer))
    expect(valgte.length, `fant ikke ${STASJONER.join(' og ')}`).toBe(STASJONER.length)

    const L: string[] = ['', '  AI-2 PRODUKSJONSFASIT — READ ONLY', '']
    L.push(`  i dag (Oslo) ${idag}   maaldato ${maalDato}   horisont +1`)
    L.push(`  modell ${MODELL.navn}   terskel ${MINST_DAGER} salgsdager   `
      + `treffvindu ${TREFF_DAGER} dager`)
    L.push('  parametrene er lest ut av ai/forventetverktoy.ts og stemmer.')

    // ── RESOLVEREN, SAMME VINDU SOM VERKTOEYET ──────────────────────────
    const { data: sokRader } = await supabase
      .from('v_butikksalg')
      .select('ean, varenavn, varegruppe_kode, varegruppe_navn, avdeling_navn, antall, dato, stasjon_id')
      .in('stasjon_id', valgte.map((s) => s.id))
      .gte('dato', leggTilDager(idag, -SOEK_DAGER)).lte('dato', idag)
      .limit(20_000).overrideTypes<Varerad[]>()

    const oppslag = slaaOpp(sokRader ?? [], SOEK)
    L.push('')
    L.push(`  RESOLVER  «${SOEK}»  ->  ${oppslag.slag}`)
    if (oppslag.slag !== 'entydig') {
      if (oppslag.slag === 'flere') {
        for (const k of oppslag.kandidater.slice(0, 8)) {
          L.push(`    ${k.ean}  «${k.navn}»  ${k.varegruppeNavn ?? ''}`)
        }
      }
      console.log(L.join('\n'))
      throw new Error(`resolveren ga «${oppslag.slag}» for «${SOEK}» — forventet entydig`)
    }
    const vare = oppslag.vare
    L.push(`    EAN ${vare.ean}   «${vare.navn}»   ${vare.varegruppeKode} ${vare.varegruppeNavn}`)
    L.push(`    avdeling ${vare.avdelingNavn}   navn varen har baaret: `
      + vare.navnHistorikk.map((n) => `«${n}»`).join('  '))
    expect(vare.ean, 'resolveren fant en annen vare enn kanarien').toBe(KANARI)

    // ── HISTORIKKEN ─────────────────────────────────────────────────────
    const salg: Salgsrad[] = []
    const SIDE = 1000
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg')
        .select('stasjon_id, dato, ean, antall, varegruppe_kode, varegruppe_navn')
        .eq('ean', vare.ean).in('stasjon_id', valgte.map((s) => s.id))
        .gte('dato', leggTilDager(idag, -HISTORIKK_DAGER)).lte('dato', idag)
        .order('dato', { ascending: true }).range(f, f + SIDE - 1)
        .overrideTypes<{
          stasjon_id: string; dato: string; ean: string; antall: number | null
          varegruppe_kode: string | null; varegruppe_navn: string | null
        }[]>()
      if (rf) throw new Error(`v_butikksalg: ${rf.message}`)
      const side = data ?? []
      for (const r of side) {
        salg.push({
          stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
          varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn,
        })
      }
      if (side.length < SIDE) break
    }
    const sisteSalg = salg.reduce((m, r) => (r.dato > m ? r.dato : m), '')
    const etterslep = Math.round(
      (Date.parse(`${idag}T12:00:00Z`) - Date.parse(`${sisteSalg}T12:00:00Z`)) / 86400000)
    L.push('')
    L.push(`  HISTORIKK  ${salg.length} rader   siste salgsdag ${sisteSalg}   `
      + `${etterslep} dag(er) etterslep`)
    L.push('  Maaldatoen er kalenderens i morgen, ikke dagen etter siste salgsdag.')

    const maaldatoer: string[] = []
    for (let i = TREFF_DAGER; i >= 1; i--) maaldatoer.push(leggTilDager(idag, -i))

    // ── FASITEN, PER STASJON ────────────────────────────────────────────
    for (const s of valgte) {
      const enhet = { stasjonId: s.id, ean: vare.ean }
      const f = forventetSalg({
        enhet, maalDato, salg, modell: MODELL, minstDagerMedSalg: MINST_DAGER,
      })
      const m = maalTreff({
        enhet, salg, maaldatoer, modell: MODELL, minstDagerMedSalg: MINST_DAGER,
      })
      L.push('')
      L.push(`  ${s.butikknummer} ${s.navn}`)
      L.push(`    autorisert            ja (retailer_admin, egen kjede)`)
      L.push(`    vareidentitet         ${vare.ean}`)
      L.push(`    visningsnavn          «${vare.navn}»`)
      L.push(`    maaldato              ${maalDato}  (+1)`)
      L.push(`    motorstatus           ${f.slag}`)
      if (f.slag === 'beregnet') {
        L.push(`    FORVENTET ANTALL      ${f.antall}`)
        L.push(`    grunnlag              basis ${f.grunnlag.basis}   `
          + `trendfaktor ${f.grunnlag.trendfaktor}   `
          + `fjormedian ${f.grunnlag.fjorMedian ?? '—'}   `
          + `nylig snitt ${f.grunnlag.nyligSnitt ?? '—'}`)
        L.push(`    dager med salg        ${f.grunnlag.dagerMedSalg}  (terskel ${MINST_DAGER})`)
      } else {
        L.push(`    FORVENTET ANTALL      — (${f.grunn})`)
        L.push(`    dager med salg        ${f.dagerMedSalg}  (terskel ${MINST_DAGER})`)
      }
      if (m) {
        L.push(`    historisk treffsikkerhet  ${m.wmape != null ? `${n1(m.wmape)} %` : '—'} `
          + `relativ feil   tillit «${tillit(m)}»`)
        L.push(`    historisk bias        ${m.bias >= 0 ? '+' : ''}${n1(m.bias)} stk/dag`)
        L.push(`    maalegrunnlag         ${m.dager} dager med baade fasit og dekning, `
          + `av ${TREFF_DAGER} maalte`)
        L.push(`                          snitt faktisk ${n1(m.snittFaktisk)} stk/dag   `
          + `MAE ${n1(m.mae)}   median ${n1(m.medianFeil)}`)
      } else {
        L.push('    historisk treffsikkerhet  — ingen dag hadde baade fasit og dekning')
      }
    }

    L.push('')
    L.push('  Ingen rad er endret. Ingen fremtidig dato utover +1 er beregnet.')
    L.push('')
    console.log(L.join('\n'))

    // Kanarifugl: gir ingen av stasjonene et tall, maaler resten ingenting.
    const noen = valgte.some((s) => forventetSalg({
      enhet: { stasjonId: s.id, ean: vare.ean }, maalDato, salg,
      modell: MODELL, minstDagerMedSalg: MINST_DAGER,
    }).slag === 'beregnet')
    expect(noen, 'ingen av stasjonene fikk en forventning — fasiten er tom').toBe(true)
  }, 300_000)
})
