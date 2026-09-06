import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import {
  svinnbilde, vareomradeAv, avdelingAv,
  type Budsjettlinje, type Svinnbilde,
} from './mot-budsjett'

// =====================================================================
// Henter alt svinnbildet trenger, og setter det sammen.
//
// Tre kilder, og de svarer på hver sin del av spørsmålet:
//
//   kastbudsjett            hva St1 sier vi har lov til
//   regnskap_usynlig_svinn  hva som FAKTISK ble kastet, i avlagte måneder
//                           — og hva som forsvant uten at noen så det
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
// Kortet viste 778,6 % kast av omsetning. Se `0175`.
//
// ---------------------------------------------------------------------
// ALT AVGRENSES TIL AVDELINGEN BUDSJETTET GJELDER
//
// Vareområdet alene er IKKE entydig. Elleve regnskapskoder i produksjon
// ender på `10`: 12010 BAKERI, men også 13010 KAFFE, 14010 BRUS, 16010
// SJOKOLADE, 18010 SIGARETTER, 25010 PANT … Nøkles kastet på `10` alene,
// får BAKERI med seg alle sammen, og tallet ser ut som et bakeriproblem.
//
// Avdelingen leses ut av budsjettet selv — `nivaa = 'avdeling'`-raden
// bærer den (`120` MAT) — og aldri av en litteral i koden. Hvilken kode
// en kjede bruker er retailer-data. Se AGENTS.md.
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
      .select('nivaa, kode, navn, kast_pst_av_salg, kast_budsjett_kr, usynlig_budsjett_kr')
      .eq('stasjon_id', stasjonId).eq('ar', ar)
      .overrideTypes<{
        nivaa: string; kode: string; navn: string | null
        kast_pst_av_salg: number; kast_budsjett_kr: number
        usynlig_budsjett_kr: number | null
      }[]>(),
    // FASITEN. `kast` kom i `0050` og er regnskapets egen svinnføring;
    // `usynlig_kr` er resten av differansen mot teoretisk brutto.
    // Én rad per kode per måned — rundt 55 i året, aldri i nærheten av
    // noe radtak.
    supabase.from('regnskap_usynlig_svinn')
      .select('periode, kode, kast, usynlig_kr')
      .eq('stasjon_id', stasjonId).gte('periode', fra).lte('periode', til)
      .is('slettet_tid', null)
      .overrideTypes<{
        periode: string; kode: string | null
        kast: number | null; usynlig_kr: number | null
      }[]>(),
    // SALGET OG DET DAGLIGE SVINNET, FERDIG SUMMERT I BASEN (`0175`).
    // De to sidene av brøken kommer fra samme rad og kan derfor ikke
    // hentes med hvert sitt utvalg.
    supabase.from('v_salg_omraade_maaned')
      .select('maned, avdeling_kode, vareomrade_kode, omsetning_kr, svinn_kr')
      .eq('stasjon_id', stasjonId).gte('maned', fra).lte('maned', til)
      .overrideTypes<{
        maned: string; avdeling_kode: string | null; vareomrade_kode: string | null
        omsetning_kr: number | null; svinn_kr: number | null
      }[]>(),
  ])

  const rader = budsjett.data ?? []
  const linjer: Budsjettlinje[] = rader.map((b) => ({
    kode: b.kode, navn: b.navn ?? b.kode,
    kastPstAvSalg: b.kast_pst_av_salg, kastBudsjettKr: b.kast_budsjett_kr,
  }))
  if (linjer.length === 0) return null

  // AVDELINGSNIVÅ ELLER VAREOMRÅDE — aldri begge. Finnes undergruppene,
  // er de de gjeldende; de summerer til totalen uansett, og å bruke
  // begge ville telt hver krone to ganger.
  const paaVareomrade = rader.some((b) => b.nivaa === 'vareomrade')
  const brukte = paaVareomrade
    ? linjer.filter((_, i) => rader[i].nivaa === 'vareomrade')
    : linjer

  // AVDELINGEN, LEST UT AV BUDSJETTET. Avdelingsraden finnes i begge
  // filvariantene — 2025-fila har Mat-arket ved siden av undergruppene —
  // så den trenger ingen litteral. Mangler den, gjøres ingen avgrensning,
  // og oppførselen er som før.
  const avdelingsrad = rader.find((b) => b.nivaa === 'avdeling')
  const avdeling = avdelingsrad?.kode ?? null
  const iAvdelingen = (kode: string | null) =>
    avdeling == null || avdelingAv(kode) === avdeling

  const kastRegnskap = new Map<string, Map<string, number>>()
  const usynligPerMaaned = new Map<string, number>()
  for (const r of regnskap.data ?? []) {
    if (!iAvdelingen(r.kode)) continue
    const maaned = tilMaaned(r.periode)
    // FORTEGNET STÅR SOM DET STÅR: + er manko, − er overskudd. En
    // telling kan finne mer enn forventet, og da skal summen gå ned.
    if (r.usynlig_kr != null) {
      usynligPerMaaned.set(maaned, (usynligPerMaaned.get(maaned) ?? 0) + r.usynlig_kr)
    }
    if (r.kast == null) continue
    const kode = paaVareomrade ? vareomradeAv(r.kode) : avdelingAv(r.kode)
    if (!kode) continue
    leggTil(kastRegnskap, kode, maaned, r.kast)
  }

  // ÉN LØKKE FOR BEGGE SIDENE AV BRØKEN. De kommer fra samme rad, så de
  // kan ikke lenger komme fra hvert sitt utvalg — det var nettopp det
  // som gjorde at telleren var hel mens nevneren var kuttet.
  const kastDaglig = new Map<string, Map<string, number>>()
  const salgKart = new Map<string, Map<string, number>>()
  for (const r of omraade.data ?? []) {
    if (avdeling != null && r.avdeling_kode !== avdeling) continue
    const kode = paaVareomrade ? r.vareomrade_kode : r.avdeling_kode
    // Rader uten hierarki er de «ikke koblede» — pant, emballasje, bulk.
    // De hører ikke til noe kastbudsjett og skal ikke måles mot ett.
    if (!kode) continue
    const maaned = tilMaaned(r.maned)
    if (r.omsetning_kr != null) leggTil(salgKart, kode, maaned, r.omsetning_kr)
    if (r.svinn_kr != null) leggTil(kastDaglig, kode, maaned, r.svinn_kr)
  }

  return svinnbilde({
    budsjett: brukte,
    kastRegnskap,
    kastDaglig,
    salg: salgKart,
    usynligPerMaaned,
    // ÅRSBUDSJETTET STÅR BARE PÅ AVDELINGSRADEN. Usynlig svinn kan per
    // definisjon ikke fordeles på undergruppe — ingen vet hvor det ble
    // av — så det finnes ikke noe å hente på vareområdenivå.
    usynligArsbudsjettKr: avdelingsrad?.usynlig_budsjett_kr ?? null,
  })
}
