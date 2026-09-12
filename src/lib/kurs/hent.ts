import type { SupabaseClient } from '@supabase/supabase-js'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'
import { BUTIKKSJEF_PERSONAL_KODER } from '@/lib/regnskap-tilgang'
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

type Linje = {
  stasjon_id: string
  periode: string
  seksjon: string
  kode: string | null
  post: string
  regnskap: number | null
  budsjett: number | null
}

type Svinnrad = {
  stasjon_id: string
  periode: string
  kode: string | null
  kast: number | null
  usynlig_kr: number | null
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

/** Mat er varegruppe 12xxx. Vask 21xxx, pant 250xx. */
const erMat = (kode: string | null) => !!kode && kode.startsWith('12')
const erVask = (kode: string | null) => !!kode && kode.startsWith('21')
const erPant = (kode: string | null) => !!kode && kode.startsWith('250')

/**
 * Koder som ikke er butikkens omsetning.
 *
 * `SKJUL_OMS_KODER` holder drivstoff (10), pant (250) og «40 CR» utenfor.
 * DRIVSTOFF ER ~68 % AV OMSETNINGEN og betjener seg selv paa pumpa - det
 * bidrar ikke til stasjonens P&L og skal aldri maales mot butikkens
 * bemanning. `40 CR` er St1s egen total, som dobbelteller mot
 * avdelingene. Se AGENTS.md.
 *
 * Delt konstant og ikke en egen liste her: to lister som skal vaere like
 * driver fra hverandre.
 */
const utenfor = (kode: string | null) =>
  !kode || SKJUL_OMS_KODER.has(kode) || erPant(kode)

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

  // GRENSENE ER SATT AV FORMEN, IKKE GJETTET. PostgREST kutter på sitt
  // eget tak UTEN å feile, og et avkortet svar ser ut som en liten
  // stasjon — se [[sentiqa-avkortet-nevner]].
  const takLinjer = stasjonIder.length * MAANEDER_BAKOVER * 120
  const takSvinn = stasjonIder.length * MAANEDER_BAKOVER * 80
  const takBilag = stasjonIder.length * 400

  const [linjer, svinn, bilag, satsrad] = await Promise.all([
    supabase.from('regnskapslinjer')
      .select('stasjon_id, periode, seksjon, kode, post, regnskap, budsjett')
      .eq('retailer_id', retailerId)
      .in('stasjon_id', stasjonIder)
      .gte('periode', fraIso).lte('periode', maanedNokkel(tilOgMed))
      .in('seksjon', ['omsetning', 'driftskostnader', 'resultat'])
      .limit(takLinjer),
    supabase.from('regnskap_usynlig_svinn')
      .select('stasjon_id, periode, kode, kast, usynlig_kr')
      .eq('retailer_id', retailerId)
      .in('stasjon_id', stasjonIder)
      .gte('periode', fraIso).lte('periode', maanedNokkel(tilOgMed))
      .is('slettet_tid', null)
      .limit(takSvinn),
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

  // SATSENE ER FRIVILLIGE, MEN FRAVÆRET SKAL SIES. `byggMaanedsplan`
  // viser ingen kroneverdier uten dem, og skriver en merknad om hvorfor.
  const sr = satsrad.data as { lav_sats: number; hoy_sats_vask: number; pant_sats: number } | null
  const satser: Satser | null = sr
    ? { lavSats: Number(sr.lav_sats), hoySatsVask: Number(sr.hoy_sats_vask), pantSats: Number(sr.pant_sats) }
    : null

  const perStasjon = grupper((linjer.data ?? []) as Linje[], (r) => r.stasjon_id)
  const svinnPer = grupper((svinn.data ?? []) as Svinnrad[], (r) => r.stasjon_id)
  const bilagPer = grupper((bilag.data ?? []) as Bilagsrad[], (r) => r.stasjon_id ?? '')

  const ut: Stasjonsplan[] = []
  for (const st of stasjoner) {
    const historikk = byggHistorikk(perStasjon.get(st.id) ?? [], svinnPer.get(st.id) ?? [])
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

const PERSONAL = BUTIKKSJEF_PERSONAL_KODER
/** Påvirkbare driftskoder, i 2026-skjemaet. Se `kontoregister.ts`. */
const DRIFT_KODER = new Set(['627', '628', '629', '632', '633', '636', '638', '746'])

export function byggHistorikk(
  linjer: readonly Linje[],
  svinn: readonly Svinnrad[],
): Maanedstall[] {
  const perMaaned = new Map<string, Maanedstall>()
  const tom = (maaned: string): Maanedstall => ({
    maaned,
    omsetningKr: 0, omsetningBudsjettKr: 0, bruttoKr: 0,
    matsalgKr: 0, matkastKr: 0, usynligRestKr: 0,
    personalKr: 0, personalBudsjettKr: 0,
    paavirkbarDriftKr: 0, paavirkbarDriftBudsjettKr: 0,
    resultatKr: 0,
  })
  const hent = (iso: string) => {
    const k = maanedNokkel(iso)
    let m = perMaaned.get(k)
    if (!m) { m = tom(k); perMaaned.set(k, m) }
    return m
  }

  for (const l of linjer) {
    const m = hent(l.periode)
    const reg = Number(l.regnskap ?? 0)
    const bud = Number(l.budsjett ?? 0)
    if (l.seksjon === 'resultat') { m.resultatKr = reg; continue }
    if (l.seksjon === 'omsetning') {
      // KUN AVDELINGSROLLUPENE. Parseren skriver bare dem i denne
      // seksjonen, men drivstoff, pant og «40 CR» hoerer ikke til
      // butikkens tall - se `utenfor`.
      if (utenfor(l.kode)) continue
      m.omsetningKr += reg
      m.omsetningBudsjettKr += bud
      if (erMat(l.kode)) m.matsalgKr += reg
      continue
    }
    // driftskostnader
    if (!l.kode) continue
    if (PERSONAL.has(l.kode)) { m.personalKr += reg; m.personalBudsjettKr += bud; continue }
    if (DRIFT_KODER.has(l.kode)) {
      m.paavirkbarDriftKr += reg
      m.paavirkbarDriftBudsjettKr += bud
    }
  }

  for (const s of svinn) {
    const m = hent(s.periode)
    if (erMat(s.kode)) m.matkastKr += Number(s.kast ?? 0)
    // USYNLIG PÅ «RESTEN»: alt utenom mat, vask og pant. Bilvask er
    // strukturelt negativ og ville dratt hele tallet i pluss.
    if (!erMat(s.kode) && !erVask(s.kode) && !erPant(s.kode)) {
      m.usynligRestKr += Number(s.usynlig_kr ?? 0)
    }
  }

  // BRUTTO KAN IKKE LESES HER. `regnskapslinjer` for stasjonen bærer
  // salg og budsjett i omsetningsseksjonen, ikke bruttofortjeneste.
  // `byggMaanedsplan` bruker brutto bare til å verdsette omsetningsvekst,
  // og faller tilbake på 50 % når den er 0 — et anslag som er merket i
  // koden framfor et tall som later som det er målt.
  return [...perMaaned.values()].sort((a, b) => a.maaned.localeCompare(b.maaned))
}
