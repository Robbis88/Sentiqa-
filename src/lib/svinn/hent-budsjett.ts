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
//   v_salg_omraade_maaned   salget, og det vi har registrert selv
//
// Den siste er den vi laster opp hver dag. Den er verdt å styre etter,
// men de ansatte fører på terminalen og de fører feil — så når måneden
// er avlagt, er det regnskapet som gjelder. Valget gjøres i `velgKilde`.
//
// ---------------------------------------------------------------------
// SUMMENE KOMMER FERDIGE FRA BASEN, OG DET ER IKKE EN OPTIMALISERING
//
// Første utgave leste `v_butikksalg` og `synlig_svinn` RAD FOR RAD — én
// rad per dag per EAN — og summerte i TypeScript. PostgREST svarer med
// sitt eget radtak, og over det taket kommer det ingen feil: bare færre
// rader.
//
//     MAT-salget for Bønes 2026:   1 220 436 kr
//     det siden fikk se:              21 950 kr
//
// Kortet viste 778,6 % kast av omsetning. Telleren var riktig hele
// tiden — `regnskap_usynlig_svinn` har én rad per kode per måned og
// ligger under ethvert tak — så bare den ene siden av brøken krympet.
//
// **En avkortet spørring ser ut som en liten stasjon.** Ingenting
// feiler; tallet blir bare mindre. Se `0175`.
// =====================================================================

type Klient = SupabaseClient

/** `2026-08-01` → `2026-08`. */
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

  const [budsjett, regnskap, omraade] = await Promise.all([
    supabase.from('kastbudsjett')
      .select('nivaa, kode, navn, kast_pst_av_salg, kast_budsjett_kr')
      .eq('stasjon_id', stasjonId).eq('ar', ar)
      .overrideTypes<{
        nivaa: string; kode: string; navn: string | null
        kast_pst_av_salg: number; kast_budsjett_kr: number
      }[]>(),
    // FASITEN. `kast` kom i `0050` og er regnskapets egen svinnføring.
    // Én rad per kode per måned — rundt 55 i året, aldri i nærheten av
    // noe radtak.
    supabase.from('regnskap_usynlig_svinn')
      .select('periode, kode, kast')
      .eq('stasjon_id', stasjonId).gte('periode', fra).lte('periode', til)
      .is('slettet_tid', null)
      .overrideTypes<{ periode: string; kode: string | null; kast: number | null }[]>(),
    // SALGET OG DET DAGLIGE SVINNET, FERDIG SUMMERT I BASEN (`0175`).
    // Rundt tolv måneder × et titalls områder — små nok til at ingen
    // grense kan røre dem, og de to sidene kan ikke lenger hentes med
    // hvert sitt utvalg.
    supabase.from('v_salg_omraade_maaned')
      .select('maned, avdeling_kode, vareomrade_kode, omsetning_kr, svinn_kr')
      .eq('stasjon_id', stasjonId).gte('maned', fra).lte('maned', til)
      .overrideTypes<{
        maned: string; avdeling_kode: string | null; vareomrade_kode: string | null
        omsetning_kr: number | null; svinn_kr: number | null
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

  // ÉN LØKKE FOR BEGGE SIDENE AV BRØKEN. De kommer fra samme rad, så de
  // kan ikke lenger komme fra hvert sitt utvalg — det var nettopp det
  // som gjorde at telleren var hel mens nevneren var kuttet.
  const kastDaglig = new Map<string, Map<string, number>>()
  const salgKart = new Map<string, Map<string, number>>()
  for (const r of omraade.data ?? []) {
    const kode = paaVareomrade ? r.vareomrade_kode : r.avdeling_kode
    // Rader uten hierarki er de «ikke koblede» — pant, emballasje, bulk.
    // De hører ikke til noe kastbudsjett og skal ikke måles mot ett.
    if (!kode) continue
    const maaned = tilMaaned(r.maned)
    if (r.omsetning_kr != null) leggTil(salgKart, kode, maaned, r.omsetning_kr)
    if (r.svinn_kr != null) leggTil(kastDaglig, kode, maaned, r.svinn_kr)
  }

  return svinnbilde({ budsjett: brukte, kastRegnskap, kastDaglig, salg: salgKart })
}
