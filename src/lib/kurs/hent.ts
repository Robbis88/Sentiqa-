import type { SupabaseClient } from '@supabase/supabase-js'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import type { Satser } from '@/lib/royalty'
import { DRIFT_BEGREP } from './loftestenger'
import { byggMaanedsplan, type Leverandorrad, type Maanedsplan, type Maanedstall } from './plan'
import type { Klasse } from './loftestenger'

// =====================================================================
// Tallene Kursen trenger, hentet fra det importene allerede skriver.
//
// Ingen ny kilde. Regnskapsimporten skriver `regnskapslinjer` og
// `regnskap_usynlig_svinn`; BP-importen skriver `royaltysats`;
// bilagsbufferen skriver `bilagssum`. Denne fila setter dem sammen.
//
// ---------------------------------------------------------------------
// TRE TING SOM ER VERDT Å VITE OM GRUNNLAGET
//
// RESULTATET leses fra arkets egen `RESULTAT`-linje, ikke utledet av
// brutto minus driftskostnader. Et utledet tall kan drive fra arkets, og
// da ville «medvind» hvilt på noe regnskapsføreren ikke kjenner igjen.
//
// MATKAST summeres fra produktradene med kode `12xxx`. Lagringen
// filtrerer bort utslag under 1 000 kroner (`lagreUsynligSvinn`), så
// summen er litt LAV — den mangler halen av små varegrupper. Det er en
// underdrivelse, ikke en overdrivelse, og retningen tåler den.
//
// USYNLIG PÅ «RESTEN» er alt utenom mat, vask og pant. Bilvask er
// strukturelt negativ og ville dratt hele tallet i pluss — se
// [[sentiqa-usynlig-fortegn]]. Pluss er manko, minus er overskudd.
// =====================================================================

type Klient = SupabaseClient

/** Hvor mange måneder Kursen ser bakover. Tolv gir et helt år uten at
    en sesongtopp blir til en retning. */
export const MAANEDER_BAKOVER = 12


/** Én rad fra `v_kurs_maanedstall` (0205). Alt er ferdig summert. */
type Maanedsrad = {
  stasjon_id: string
  maaned: string
  omsetning_kr: number | null
  omsetning_budsjett_kr: number | null
  brutto_kr: number | null
  matsalg_kr: number | null
  matkast_kr: number | null
  usynlig_rest_kr: number | null
  personal_kr: number | null
  personal_budsjett_kr: number | null
  paavirkbar_drift_kr: number | null
  paavirkbar_drift_budsjett_kr: number | null
  resultat_kr: number | null
}



type Bilagsrad = {
  stasjon_id: string | null
  periode: string
  begrep: string | null
  tekst: string
  belop_kr: number
  antall: number
}

const maanedNokkel = (iso: string) => `${iso.slice(0, 7)}-01`

// =====================================================================
// VAREGRUPPEFILTRENE LIGGER I BASEN NÅ (0205)
// =====================================================================
//
// Her sto `erMat` (12xxx), `erVask` (21xxx), `erPant` (250xx) og
// `utenfor` — sammen med hele summeringen.
//
// `SKJUL_OMS_KODER` holder drivstoff (10), pant (250) og «40 CR»
// utenfor. DRIVSTOFF ER ~68 % AV OMSETNINGEN og betjener seg selv på
// pumpa; det bidrar ikke til stasjonens P&L og skal aldri måles mot
// butikkens bemanning. «40 CR» er St1s egen total, som dobbelteller mot
// avdelingene. Se AGENTS.md.
//
// Reglene står nå i `v_kurs_maanedstall`, så konstanten importeres ikke
// lenger her. Den er fortsatt den ene kilden:
// `src/lib/kurs/viewliste.test.ts` leser `SKJUL_OMS_KODER` og krever at
// hver kode i den faktisk holdes utenfor i viewets SQL.

export type Stasjonsplan = { stasjonId: string; plan: Maanedsplan }

/**
 * Bygger månedsplanene for alle stasjonene i kjeden.
 *
 * `tilOgMed` er måneden planen gjelder, ISO første i måneden.
 */
export async function byggPlanerForRetailer(opts: {
  supabase: Klient
  retailerId: string
  tilOgMed: string
}): Promise<Stasjonsplan[]> {
  const { supabase, retailerId, tilOgMed } = opts

  // STASJONENE SLAAS OPP HER, IKKE SENDES INN.
  //
  // Importen kjoerer med TJENESTENOEKKELEN, og dens stasjonsoppslag
  // dekker HELE basen - alle kjeder. Ble lista sendt inn, ville en
  // uforsiktig kaller bygget maanedsplaner for en annen retailers
  // stasjoner, og RLS ville ikke stoppet det: tjenestenoekkelen ser forbi.
  //
  // Tenantfilteret hoerer derfor sammen med spoerringen, ikke hos den som
  // kaller. Se [[sentiqa-filtrer-som-flaten]].
  const { data: stasjonsrader } = await supabase
    .from('stasjoner')
    .select('id, navn')
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)
    .limit(200)
  const stasjoner = (stasjonsrader ?? []) as { id: string; navn: string }[]
  if (stasjoner.length === 0) return []

  const fra = new Date(`${maanedNokkel(tilOgMed)}T00:00:00Z`)
  fra.setUTCMonth(fra.getUTCMonth() - (MAANEDER_BAKOVER - 1))
  const fraIso = fra.toISOString().slice(0, 10)
  const stasjonIder = stasjoner.map((s) => s.id)

  // MÅNEDEN SUMMERES I BASEN (0205). Én rad per stasjon per måned.
  //
  // Her sto en raa henting av `regnskapslinjer` med `.limit(7200)`. Den
  // spurte om 1 563 rader for Kelsar, fikk 1 000, og juli - som nettopp
  // var skrevet og derfor ligger fysisk bakerst - falt utenfor.
  // Maanedsplanene sto med 0 kroner paa hver stasjon mens tallene laa i
  // basen.
  //
  // Et `.limit()` hoeyere enn serverens tak er en loegn om hva vi faar.
  //
  // TAKET MAA VAERE STOERRE ENN DET LOVLIGE MAKSIMUM. `maaVaereHele`
  // kaster naar svaret TREFFER taket, fordi det da kan vaere avkortet -
  // og fem stasjoner x tolv maaneder er 60 lovlige rader. Var taket 60,
  // ville et helt korrekt svar kastet.
  //
  // Og det maa vaere under tusen: `max_rows = 1000` i config.toml gjoer
  // at en hoeyere `.limit()` ikke er en grense, bare en kommentar. Det
  // var nettopp feilen - `.limit(7200)` kunne aldri utloese noe.
  const takMaaneder = stasjonIder.length * (MAANEDER_BAKOVER + 1)
  const takBilag = stasjonIder.length * 150

  const [maanedstall, bilag, satsrad] = await Promise.all([
    supabase.from('v_kurs_maanedstall')
      .select('stasjon_id, maaned, omsetning_kr, omsetning_budsjett_kr, brutto_kr, matsalg_kr, matkast_kr, usynlig_rest_kr, personal_kr, personal_budsjett_kr, paavirkbar_drift_kr, paavirkbar_drift_budsjett_kr, resultat_kr')
      .eq('retailer_id', retailerId)
      .in('stasjon_id', stasjonIder)
      .gte('maaned', fraIso).lte('maaned', maanedNokkel(tilOgMed))
      .order('maaned', { ascending: true })
      .limit(takMaaneder),
    supabase.from('bilagssum')
      .select('stasjon_id, periode, begrep, tekst, belop_kr, antall')
      .eq('retailer_id', retailerId)
      .in('stasjon_id', stasjonIder)
      .eq('periode', maanedNokkel(tilOgMed))
      .limit(takBilag),
    supabase.from('royaltysats')
      .select('lav_sats, hoy_sats_vask, pant_sats')
      .eq('retailer_id', retailerId)
      .eq('aar', Number(tilOgMed.slice(0, 4)))
      .maybeSingle(),
  ])

  // ET FULLT SVAR ER IKKE ET BEVIS PAA AT DET ER HELE SVARET.
  //
  // `maaVaereHele` er husets egen vakt for dette, og den klemmer taket
  // ned til de tusen PostgREST faktisk gir - en `.limit()` over det er
  // ikke en grense. Kaster, og `etterRegnskap` skriver grunnen paa
  // jobbraden.
  const maanedsrader = maaVaereHele(maanedstall, 'maanedstall for Kursen', takMaaneder)
  const bilagsrader = maaVaereHele(bilag, 'bilagssummene for Kursen', takBilag)

  // SATSENE ER FRIVILLIGE, MEN FRAVÆRET SKAL SIES. `byggMaanedsplan`
  // viser ingen kroneverdier uten dem, og skriver en merknad om hvorfor.
  const sr = satsrad.data as { lav_sats: number; hoy_sats_vask: number; pant_sats: number } | null
  const satser: Satser | null = sr
    ? { lavSats: Number(sr.lav_sats), hoySatsVask: Number(sr.hoy_sats_vask), pantSats: Number(sr.pant_sats) }
    : null

  const perStasjon = grupper(maanedsrader as unknown as Maanedsrad[], (r) => r.stasjon_id)
  const bilagPer = grupper(bilagsrader as unknown as Bilagsrad[], (r) => r.stasjon_id ?? '')

  const ut: Stasjonsplan[] = []
  for (const st of stasjoner) {
    const historikk = byggHistorikk(perStasjon.get(st.id) ?? [])
    if (historikk.length === 0) continue
    const leverandorer = (bilagPer.get(st.id) ?? [])
      .filter((b) => b.begrep !== null && (DRIFT_BEGREP as readonly string[]).includes(b.begrep))
      .map((b): Leverandorrad => ({
        begrep: b.begrep, tekst: b.tekst,
        belopKr: Number(b.belop_kr), antall: b.antall,
      }))
    ut.push({
      stasjonId: st.id,
      plan: byggMaanedsplan(
        { stasjonNavn: st.navn, historikk, leverandorer, satser },
        { klasseFor: klasseFor },
      ),
    })
  }
  return ut
}

/**
 * Hvilken klasse en leverandør hører til.
 *
 * EN KODE ER IKKE EN SPAK ELLER EN FØLGE — EN LEVERANDØR ER DET. `634
 * Rep & vedlikehold` er 82 % WashTec på stasjonene med vask, altså
 * maskinen og ikke butikksjefens valg. På Dale, som ikke har vask, er
 * den null WashTec: der er den kjøl og bygg, og dermed en spak.
 *
 * Lista er navn vi har sett i Kelsars egne bilag. En leverandør vi ikke
 * kjenner regnes som SPAK — det er den som gir et tiltak, og et tiltak
 * som viser seg å være en maskin blir korrigert av et menneske. Motsatt
 * vei ville en ukjent leverandør blitt usynlig for alltid.
 */
const MASKINLEVERANDORER = ['washtec', 'epta', 'wennstrom', 'nilfisk']

export function klasseFor(r: { tekst: string }): Klasse {
  const t = r.tekst.toLowerCase()
  return MASKINLEVERANDORER.some((m) => t.includes(m)) ? 'folge' : 'spak'
}

function grupper<T>(rader: readonly T[], noekkel: (r: T) => string): Map<string, T[]> {
  const m = new Map<string, T[]>()
  for (const r of rader) {
    const k = noekkel(r)
    const f = m.get(k)
    if (f) f.push(r)
    else m.set(k, [r])
  }
  return m
}

// `PERSONAL` og `DRIFT_KODER` sto her som to sett av RAAKODER.
//
// Begge er borte: summeringen skjer i `v_kurs_maanedstall` (0205), og
// der filtreres det paa `begrep`. Kodelistene var feil paa to maater -
// `DRIFT_KODER` manglet `634` uten at noe sted sa hvorfor, og etter
// `0203` betyr `634` «Pengehaandtering» paa en maaned fra foer februar
// 2026. Regelen er skrevet i `regnskap-tilgang.ts`: filtrerer du paa noe
// i 6xx, bruk begrep.

export function byggHistorikk(rader: readonly Maanedsrad[]): Maanedstall[] {
  return [...rader]
    .sort((a, b) => a.maaned.localeCompare(b.maaned))
    .map((r) => ({
      maaned: maanedNokkel(r.maaned),
      omsetningKr: Number(r.omsetning_kr ?? 0),
      omsetningBudsjettKr: Number(r.omsetning_budsjett_kr ?? 0),
      bruttoKr: Number(r.brutto_kr ?? 0),
      matsalgKr: Number(r.matsalg_kr ?? 0),
      matkastKr: Number(r.matkast_kr ?? 0),
      usynligRestKr: Number(r.usynlig_rest_kr ?? 0),
      personalKr: Number(r.personal_kr ?? 0),
      personalBudsjettKr: Number(r.personal_budsjett_kr ?? 0),
      paavirkbarDriftKr: Number(r.paavirkbar_drift_kr ?? 0),
      paavirkbarDriftBudsjettKr: Number(r.paavirkbar_drift_budsjett_kr ?? 0),
      resultatKr: Number(r.resultat_kr ?? 0),
    }))
}
