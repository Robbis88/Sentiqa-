import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { svinnbilde, vareomradeAv, type Budsjettlinje, type Svinnbilde } from './mot-budsjett'

// =====================================================================
// Henter alt svinnbildet trenger, og setter det sammen.
//
// Tre kilder, og de svarer på hver sin del av spørsmålet:
//
//   kastbudsjett            hva St1 sier vi har lov til
//   regnskap_usynlig_svinn  hva som FAKTISK ble kastet, i avlagte måneder
//   synlig_svinn            hva vi har registrert selv, i åpne måneder
//
// Den siste er den vi laster opp hver dag. Den er verdt å styre etter,
// men de ansatte fører på terminalen og de fører feil — så når måneden
// er avlagt, er det regnskapet som gjelder. Valget gjøres i `velgKilde`.
//
// ---------------------------------------------------------------------
// SALGET ER NEVNEREN, OG DEN MÅ VÆRE MATSALG
//
// Kravet er en prosent av omsetning. Nevneren må derfor være salget i
// SAMME vareområde — bakeriets kastbudsjett måles mot bakeriets salg,
// ikke mot butikkens.
// =====================================================================

type Klient = SupabaseClient

/** `2026-08-01` eller `2026-08-13` → `2026-08`. */
const tilMaaned = (d: string) => d.slice(0, 7)

/** Legger `kr` inn i `kode → måned → sum`. */
function leggTil(kart: Map<string, Map<string, number>>, kode: string, maaned: string, kr: number) {
  const per = kart.get(kode) ?? new Map<string, number>()
  per.set(maaned, (per.get(maaned) ?? 0) + kr)
  kart.set(kode, per)
}

export async function hentSvinnbudsjett(
  supabase: Klient,
  stasjonId: string,
  ar: number,
): Promise<Svinnbilde | null> {
  const fra = `${ar}-01-01`
  const til = `${ar}-12-31`

  const [budsjett, regnskap, varer, salg] = await Promise.all([
    supabase.from('kastbudsjett')
      .select('nivaa, kode, navn, kast_pst_av_salg, kast_budsjett_kr')
      .eq('stasjon_id', stasjonId).eq('ar', ar)
      .overrideTypes<{
        nivaa: string; kode: string; navn: string | null
        kast_pst_av_salg: number; kast_budsjett_kr: number
      }[]>(),
    // FASITEN. `kast` kom i `0050` og er regnskapets egen svinnføring.
    supabase.from('regnskap_usynlig_svinn')
      .select('periode, kode, kast')
      .eq('stasjon_id', stasjonId).gte('periode', fra).lte('periode', til)
      .is('slettet_tid', null)
      .overrideTypes<{ periode: string; kode: string | null; kast: number | null }[]>(),
    // Hva vi har registrert selv, per vare. `synlig_svinn` har bare
    // `ean`, så vareområdet må komme fra hierarkiet.
    supabase.from('synlig_svinn')
      .select('dato, ean, nettopris_total')
      .eq('stasjon_id', stasjonId).gte('dato', fra).lte('dato', til)
      .is('slettet_tid', null).limit(50000)
      .overrideTypes<{ dato: string | null; ean: string | null; nettopris_total: number | null }[]>(),
    // ÉN spoerring, to formaal: salget per omraade OG kartet fra ean til
    // omraade. Samme rader svarer paa begge, og to kall mot samme tabell
    // kan i tillegg gi to ulike svar hvis en import lander imellom.
    supabase.from('v_butikksalg')
      .select('dato, ean, vareomrade_kode, avdeling_kode, omsetning_eks_mva')
      .eq('stasjon_id', stasjonId).gte('dato', fra).lte('dato', til).limit(50000)
      .overrideTypes<{
        dato: string; ean: string | null; vareomrade_kode: string | null
        avdeling_kode: string | null; omsetning_eks_mva: number | null
      }[]>(),
  ])

  const linjer: Budsjettlinje[] = (budsjett.data ?? []).map((b) => ({
    kode: b.kode, navn: b.navn ?? b.kode,
    kastPstAvSalg: b.kast_pst_av_salg, kastBudsjettKr: b.kast_budsjett_kr,
  }))
  if (linjer.length === 0) return null

  // AVDELINGSNIVÅ ELLER VAREOMRÅDE — aldri begge. Finnes undergruppene,
  // er de de gjeldende; de summerer til totalen uansett, og å bruke
  // begge ville telt hver krone to ganger.
  const paaVareomrade = (budsjett.data ?? []).some((b) => b.nivaa === 'vareomrade')
  const brukte = paaVareomrade
    ? linjer.filter((_, i) => (budsjett.data ?? [])[i].nivaa === 'vareomrade')
    : linjer

  const kastRegnskap = new Map<string, Map<string, number>>()
  for (const r of regnskap.data ?? []) {
    if (r.kast == null) continue
    const omr = vareomradeAv(r.kode)
    const kode = paaVareomrade ? omr : (r.kode?.slice(0, 3) ?? null)
    if (!kode) continue
    leggTil(kastRegnskap, kode, tilMaaned(r.periode), r.kast)
  }

  // EAN → område. Salget er den eneste kilden som kjenner hierarkiet;
  // `synlig_svinn` bærer bare EAN-en.
  const salgRader = salg.data ?? []
  const omradeFor = new Map<string, string>()
  for (const v of salgRader) {
    if (!v.ean) continue
    const kode = paaVareomrade ? v.vareomrade_kode : v.avdeling_kode
    if (kode) omradeFor.set(v.ean, kode)
  }

  const kastDaglig = new Map<string, Map<string, number>>()
  for (const s of varer.data ?? []) {
    if (!s.dato || !s.ean || s.nettopris_total == null) continue
    const kode = omradeFor.get(s.ean)
    // Varer uten hierarki er de «ikke koblede» — pant, emballasje, bulk.
    // De hører ikke til noe kastbudsjett og skal ikke måles mot ett.
    if (!kode) continue
    leggTil(kastDaglig, kode, tilMaaned(s.dato), s.nettopris_total)
  }

  const salgKart = new Map<string, Map<string, number>>()
  for (const v of salgRader) {
    const kode = paaVareomrade ? v.vareomrade_kode : v.avdeling_kode
    if (!kode || v.omsetning_eks_mva == null) continue
    leggTil(salgKart, kode, tilMaaned(v.dato), v.omsetning_eks_mva)
  }

  return svinnbilde({ budsjett: brukte, kastRegnskap, kastDaglig, salg: salgKart })
}
