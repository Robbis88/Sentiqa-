import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { UTELAT_KODER, SKJUL_OMS_KODER } from '@/lib/avdelinger'
import { BUTIKKSJEF_PERSONAL_KODER } from '@/lib/regnskap-tilgang'

// Tung eier-regnskapsanalyse → Opus, der kvalitet teller (PROSJEKT.md §8).
const MODELL = 'claude-opus-4-8'

export const AnalyseSchema = z.object({
  sammendrag: z.string(),
  perStasjon: z.array(
    z.object({
      stasjon: z.string(),
      status: z.enum(['gronn', 'gul', 'rod']),
      kommentar: z.string(),
    }),
  ),
  systemfeil: z.array(z.string()), // kryss-stasjon-mønstre / registreringsfeil
  rodeFlagg: z.array(z.string()),
  muligheter: z.array(z.string()),
  tiltak: z.array(z.object({ tekst: z.string(), prioritet: z.enum(['hoy', 'medium', 'lav']) })),
  endringer: z.array(z.string()), // vs forrige periode/versjon
})
export type Analyse = z.infer<typeof AnalyseSchema>

type Klient = SupabaseClient
type Resultat = { ok: true; periode: string; hoppet?: boolean } | { ok: false; grunn: string }

type Linje = { seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }
type Usynlig = { stasjon_id: string; navn: string; salg: number | null; brf_pst: number | null; usynlig_kr: number | null; usynlig_pst: number | null }

const SYSTEM_PROMPT =
  'Du er eierens FASTE REGNSKAPSFØRER for en servicehandel-kjede (bensinstasjoner). Norsk bokmål. ' +
  'Vær DIREKTE og handlingsorientert — skriv «betyr at», ikke «kan tyde på». ALDRI finn på tall; bruk kun tallene du får. Vær konkret med kroner og prosent.\n' +
  'FORTEGNS-REGEL på usynlig svinn: positivt tall = MANKO (penger forsvinner = tap). Negativt tall = OVERSKUDD på lager (som regel feilslag/registreringsfeil på kassa). Si ALLTID «manko» eller «overskudd», aldri bare «svinn».\n' +
  'Let etter MØNSTRE PÅ TVERS av stasjoner = systemfeil, ikke enkeltstasjon. Eksempler: KAFFE-manko + KAFFELOJALITET-overskudd = lojalitetskaffe registreres feil; MASKINVASK APP-overskudd = app-betalinger lekker og MASKERER ekte manko. Slike funn skal i «systemfeil».\n' +
  'Bruk RESULTAT EX 9900 (uten admin-stasjon 9900) mot budsjett for driftsvurderingen, og total-RESULTAT for bunnlinja.\n' +
  'LØNN måles MOT LØNNSBUDSJETTET (St1 setter budsjettet) — ALDRI mot omsetning eller bruttofortjeneste. To viktige poeng per stasjon: (a) bruker stasjonen MER lønn enn budsjett → si tydelig fra at de må skjerpe bemanning/vaktplan; (b) bruker de (nær) hele lønnsbudsjettet MEN brutto ligger under budsjett → bemanningen leverer ikke nok salg/brutto. Drivstoff og pant er holdt utenfor alle tall.\n' +
  'Status per stasjon: gronn (på/over budsjett, lite reell manko, lønn i rute), gul (litt under), rod (klart under / reell manko / lønn klart over budsjett). 2–4 setninger med konkrete tall per stasjon.\n' +
  'Tiltak: 3–5 konkrete handlinger med prioritet (hoy/medium/lav) — «sjekk vaktplan på Lone man–ons», ikke «vurder bemanning». Maks 5 røde flagg.'

// Felles Opus-kall + lagring (omfang skiller måned fra hittil i år).
async function kjorOpusOgLagre(supabase: Klient, retailerId: string, periode: string, omfang: 'maaned' | 'hittil', brukerMelding: string): Promise<Resultat> {
  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 8192,
    thinking: { type: 'adaptive' },
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: brukerMelding }],
    output_config: { format: zodOutputFormat(AnalyseSchema) },
  })
  const analyse = resp.parsed_output
  if (!analyse) return { ok: false, grunn: 'AI-en ga ikke et gyldig svar. Prøv igjen.' }
  await supabase.from('regnskapsanalyser').delete().eq('retailer_id', retailerId).eq('periode', periode).eq('omfang', omfang)
  const { error } = await supabase.from('regnskapsanalyser').insert({ retailer_id: retailerId, periode, omfang, rapport: analyse, modell: MODELL })
  if (error) return { ok: false, grunn: error.message }
  return { ok: true, periode }
}

// Kjernen — tar klient + retailer, så den kan kjøres både fra import (auto) og UI.
export async function kjorRegnskapsanalyse(supabase: Klient, retailerId: string): Promise<Resultat> {
  if (!env.ANTHROPIC_API_KEY) return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }

  const { data: siste } = await supabase
    .from('regnskapslinjer').select('periode').eq('retailer_id', retailerId).is('stasjon_id', null)
    .order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
  if (!siste) return { ok: false, grunn: 'Ingen regnskap ennå. Behandle en regnskapsfil først.' }
  const periode = siste.periode

  // Race-guard: ikke kjør på nytt innen 30 sek (auto + UI kan kollidere).
  const { data: nylig } = await supabase
    .from('regnskapsanalyser').select('opprettet_tid').eq('retailer_id', retailerId).eq('periode', periode)
    .order('opprettet_tid', { ascending: false }).limit(1).maybeSingle<{ opprettet_tid: string }>()
  if (nylig && Date.now() - new Date(nylig.opprettet_tid).getTime() < 30_000) {
    return { ok: true, periode, hoppet: true }
  }

  const [{ data: cluster }, { data: perRader }, { data: stasjoner }, { data: usynlig }, { data: forrige }] = await Promise.all([
    supabase.from('regnskapslinjer').select('seksjon, kode, post, regnskap, budsjett, avvik, index_pct').eq('retailer_id', retailerId).eq('periode', periode).is('stasjon_id', null).order('sortering').overrideTypes<Linje[]>(),
    supabase.from('regnskapslinjer').select('stasjon_id, seksjon, kode, regnskap, budsjett').eq('retailer_id', retailerId).eq('periode', periode).in('seksjon', ['omsetning', 'bruttofortjeneste', 'driftskostnader']).not('stasjon_id', 'is', null).overrideTypes<{ stasjon_id: string; seksjon: string; kode: string | null; regnskap: number | null; budsjett: number | null }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase.from('regnskap_usynlig_svinn').select('stasjon_id, navn, salg, brf_pst, usynlig_kr, usynlig_pst').eq('retailer_id', retailerId).eq('periode', periode).is('slettet_tid', null).overrideTypes<Usynlig[]>(),
    supabase.from('regnskapsanalyser').select('periode, rapport').eq('retailer_id', retailerId).lt('periode', periode).is('slettet_tid', null).order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string; rapport: Analyse }>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Cluster-P&L — drivstoff (10) og pant (250) utelates (ikke butikkdrift).
  const clusterTekst = (cluster ?? [])
    .filter((l) => !UTELAT_KODER.has(l.kode ?? ''))
    .map((l) => `[${l.seksjon}] ${l.post}: regnskap ${Math.round(l.regnskap ?? 0)} kr, budsjett ${Math.round(l.budsjett ?? 0)} kr, avvik ${Math.round(l.avvik ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} %)`)
    .join('\n')

  // Per stasjon: omsetning + brutto (basis-avd eks drivstoff/pant/CR) og lønn
  // mot LØNNSBUDSJETT (personalkoder). Avvik i %.
  type Tre = { oms: { r: number; b: number }; brf: { r: number; b: number }; lonn: { r: number; b: number } }
  const perStasjon = new Map<string, Tre>()
  for (const r of perRader ?? []) {
    const t = perStasjon.get(r.stasjon_id) ?? { oms: { r: 0, b: 0 }, brf: { r: 0, b: 0 }, lonn: { r: 0, b: 0 } }
    if (r.seksjon === 'omsetning' && !SKJUL_OMS_KODER.has(r.kode ?? '')) { t.oms.r += r.regnskap ?? 0; t.oms.b += r.budsjett ?? 0 }
    else if (r.seksjon === 'bruttofortjeneste' && !SKJUL_OMS_KODER.has(r.kode ?? '')) { t.brf.r += r.regnskap ?? 0; t.brf.b += r.budsjett ?? 0 }
    else if (r.seksjon === 'driftskostnader' && BUTIKKSJEF_PERSONAL_KODER.has(r.kode ?? '')) { t.lonn.r += r.regnskap ?? 0; t.lonn.b += r.budsjett ?? 0 }
    perStasjon.set(r.stasjon_id, t)
  }
  const avp = (x: { r: number; b: number }) => (x.b ? (((x.r - x.b) / x.b) * 100).toFixed(1) : '0')
  const stasjonTekst = [...perStasjon.entries()].filter(([id]) => navnFor.has(id))
    .map(([id, t]) => `${navnFor.get(id)}: omsetning ${Math.round(t.oms.r)} av budsjett ${Math.round(t.oms.b)} kr (${avp(t.oms)} %); brutto ${Math.round(t.brf.r)} av ${Math.round(t.brf.b)} kr (${avp(t.brf)} %); lønn ${Math.round(t.lonn.r)} mot lønnsbudsjett ${Math.round(t.lonn.b)} kr (${avp(t.lonn)} %)`)
    .join('\n')

  // Usynlig svinn pr stasjon (fortegn: + manko, - overskudd) + kryss-stasjon
  const perStasjonSvinn = new Map<string, Usynlig[]>()
  const kryss = new Map<string, { sum: number; manko: number; overskudd: number }>()
  for (const u of usynlig ?? []) {
    const l = perStasjonSvinn.get(u.stasjon_id) ?? []; l.push(u); perStasjonSvinn.set(u.stasjon_id, l)
    const k = kryss.get(u.navn) ?? { sum: 0, manko: 0, overskudd: 0 }
    const v = u.usynlig_kr ?? 0
    k.sum += v; if (v > 0) k.manko++; else if (v < 0) k.overskudd++
    kryss.set(u.navn, k)
  }
  const svinnTekst = [...perStasjonSvinn.entries()].filter(([id]) => navnFor.has(id)).map(([id, liste]) => {
    let manko = 0, overskudd = 0
    for (const u of liste) { const v = u.usynlig_kr ?? 0; if (v > 0) manko += v; else overskudd += v }
    const topp = [...liste].sort((a, b) => (b.usynlig_kr ?? 0) - (a.usynlig_kr ?? 0))
    const sett = (u: Usynlig) => `${u.navn} ${Math.round(u.usynlig_kr ?? 0)} kr (${Math.round(u.usynlig_pst ?? 0)}% av salg)`
    return `${navnFor.get(id)}: total manko +${Math.round(manko)} kr, overskudd ${Math.round(overskudd)} kr.\n  Topp manko: ${topp.slice(0, 5).map(sett).join('; ')}\n  Topp overskudd: ${topp.slice(-3).reverse().map(sett).join('; ')}`
  }).join('\n')

  const kryssTekst = [...kryss.entries()]
    .filter(([, k]) => k.manko >= 3 || k.overskudd >= 3 || Math.abs(k.sum) > 20000)
    .sort((a, b) => Math.abs(b[1].sum) - Math.abs(a[1].sum))
    .map(([navn, k]) => `${navn}: ${k.manko} stasjoner med manko, ${k.overskudd} med overskudd, netto ${Math.round(k.sum)} kr`)
    .join('\n')

  const forrigeTekst = forrige?.rapport?.sammendrag
    ? `Forrige periode (${forrige.periode}) sammendrag: ${forrige.rapport.sammendrag}`
    : 'Ingen tidligere analyse å sammenligne med.'

  const brukerMelding =
    `MÅNEDSREGNSKAP (cluster-P&L):\n${clusterTekst}\n\n` +
    `NØKKELTALL PER STASJON (omsetning, brutto, lønn mot lønnsbudsjett — eks. drivstoff/pant):\n${stasjonTekst}\n\n` +
    `USYNLIG SVINN PER STASJON (+ = manko, − = overskudd):\n${svinnTekst || 'Ingen usynlig svinn-data.'}\n\n` +
    `KRYSS-STASJON (samme vare på flere stasjoner):\n${kryssTekst || 'Ingen tydelige kryss-mønstre.'}\n\n` +
    `${forrigeTekst}\n\n` +
    'Lag analysen: sammendrag (3–5 linjer: resultat vs budsjett, beste/verste, hva som haster), per-stasjon status + kommentar, systemfeil (kryss-stasjon-mønstre), røde flagg, muligheter, tiltak (m/prioritet), og endringer vs forrige periode.'
  return kjorOpusOgLagre(supabase, retailerId, periode, 'maaned', brukerMelding)
}

// UI-trigger (eier, manuell regenerering).
export async function genererRegnskapsanalyse(): Promise<Resultat> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan kjøre regnskapsanalysen.' }
  }
  const supabase = await lagSupabaseServerKlient()
  return kjorRegnskapsanalyse(supabase, bruker.retailerId)
}

// HITTIL I ÅR-analyse (regnskapsfører på årsbasis; for onboarding/hele året).
// Summerer månedene via regnskap_sum/svinn_sum (RLS → kun egen kjede). UI-only.
export async function kjorRegnskapsanalyseHittil(supabase: Klient, retailerId: string, aar?: string): Promise<Resultat> {
  if (!env.ANTHROPIC_API_KEY) return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }

  const { data: perRader } = await supabase
    .from('regnskapslinjer').select('periode').eq('retailer_id', retailerId).is('stasjon_id', null)
    .order('periode', { ascending: false }).limit(60).overrideTypes<{ periode: string }[]>()
  const perioder = [...new Set((perRader ?? []).map((p) => p.periode))]
  if (perioder.length === 0) return { ok: false, grunn: 'Ingen regnskap ennå. Behandle en regnskapsfil først.' }
  const valgtAar = aar ?? perioder[0].slice(0, 4)
  const iAaret = perioder.filter((p) => p.slice(0, 4) === valgtAar).sort()
  if (iAaret.length === 0) return { ok: false, grunn: `Ingen regnskap for ${valgtAar}.` }
  const til = iAaret[iAaret.length - 1]
  const fra = `${valgtAar}-01-01`

  type SumRad = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null }
  type SvinnRad = { stasjon_id: string | null; navn: string; salg: number | null; usynlig_kr: number | null }
  const [{ data: sum }, { data: stasjoner }, { data: svinn }] = await Promise.all([
    supabase.rpc('regnskap_sum', { p_fra: fra, p_til: til }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase.rpc('svinn_sum', { p_fra: fra, p_til: til }),
  ])
  const rader = (sum ?? []) as SumRad[]
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const clusterTekst = rader.filter((l) => l.stasjon_id == null && !UTELAT_KODER.has(l.kode ?? ''))
    .map((l) => { const r = l.regnskap ?? 0, b = l.budsjett ?? 0, idx = b ? ((r - b) / b) * 100 : 0; return `[${l.seksjon}] ${l.post}: regnskap ${Math.round(r)} kr, budsjett ${Math.round(b)} kr, avvik ${Math.round(r - b)} kr (${idx.toFixed(1)} %)` }).join('\n')

  type Tre = { oms: { r: number; b: number }; brf: { r: number; b: number }; lonn: { r: number; b: number } }
  const perStasjon = new Map<string, Tre>()
  for (const r of rader) {
    if (r.stasjon_id == null) continue
    const t = perStasjon.get(r.stasjon_id) ?? { oms: { r: 0, b: 0 }, brf: { r: 0, b: 0 }, lonn: { r: 0, b: 0 } }
    if (r.seksjon === 'omsetning' && !SKJUL_OMS_KODER.has(r.kode ?? '')) { t.oms.r += r.regnskap ?? 0; t.oms.b += r.budsjett ?? 0 }
    else if (r.seksjon === 'bruttofortjeneste' && !SKJUL_OMS_KODER.has(r.kode ?? '')) { t.brf.r += r.regnskap ?? 0; t.brf.b += r.budsjett ?? 0 }
    else if (r.seksjon === 'driftskostnader' && BUTIKKSJEF_PERSONAL_KODER.has(r.kode ?? '')) { t.lonn.r += r.regnskap ?? 0; t.lonn.b += r.budsjett ?? 0 }
    perStasjon.set(r.stasjon_id, t)
  }
  const avp = (x: { r: number; b: number }) => (x.b ? (((x.r - x.b) / x.b) * 100).toFixed(1) : '0')
  const stasjonTekst = [...perStasjon.entries()].filter(([id]) => navnFor.has(id))
    .map(([id, t]) => `${navnFor.get(id)}: omsetning ${Math.round(t.oms.r)} av budsjett ${Math.round(t.oms.b)} kr (${avp(t.oms)} %); brutto ${Math.round(t.brf.r)} av ${Math.round(t.brf.b)} kr (${avp(t.brf)} %); lønn ${Math.round(t.lonn.r)} mot lønnsbudsjett ${Math.round(t.lonn.b)} kr (${avp(t.lonn)} %)`).join('\n')

  const svinnRader = (svinn ?? []) as SvinnRad[]
  const perSvinn = new Map<string, SvinnRad[]>()
  const kryss = new Map<string, { sum: number; manko: number; overskudd: number }>()
  for (const u of svinnRader) {
    if (!u.stasjon_id) continue
    const l = perSvinn.get(u.stasjon_id) ?? []; l.push(u); perSvinn.set(u.stasjon_id, l)
    const k = kryss.get(u.navn) ?? { sum: 0, manko: 0, overskudd: 0 }
    const v = u.usynlig_kr ?? 0; k.sum += v; if (v > 0) k.manko++; else if (v < 0) k.overskudd++; kryss.set(u.navn, k)
  }
  const sett = (u: SvinnRad) => { const pst = u.salg ? ((u.usynlig_kr ?? 0) / u.salg) * 100 : 0; return `${u.navn} ${Math.round(u.usynlig_kr ?? 0)} kr (${Math.round(pst)}% av salg)` }
  const svinnTekst = [...perSvinn.entries()].filter(([id]) => navnFor.has(id)).map(([id, liste]) => {
    let manko = 0, overskudd = 0; for (const u of liste) { const v = u.usynlig_kr ?? 0; if (v > 0) manko += v; else overskudd += v }
    const topp = [...liste].sort((a, b) => (b.usynlig_kr ?? 0) - (a.usynlig_kr ?? 0))
    return `${navnFor.get(id)}: total manko +${Math.round(manko)} kr, overskudd ${Math.round(overskudd)} kr.\n  Topp manko: ${topp.slice(0, 5).map(sett).join('; ')}\n  Topp overskudd: ${topp.slice(-3).reverse().map(sett).join('; ')}`
  }).join('\n')
  const kryssTekst = [...kryss.entries()].filter(([, k]) => k.manko >= 3 || k.overskudd >= 3 || Math.abs(k.sum) > 20000)
    .sort((a, b) => Math.abs(b[1].sum) - Math.abs(a[1].sum))
    .map(([navn, k]) => `${navn}: ${k.manko} stasjoner med manko, ${k.overskudd} med overskudd, netto ${Math.round(k.sum)} kr`).join('\n')

  const mnd = new Intl.DateTimeFormat('nb-NO', { month: 'long', timeZone: 'Europe/Oslo' }).format(new Date(`${til}T12:00:00Z`))
  const brukerMelding =
    `HITTIL I ÅR ${valgtAar} (sum jan–${mnd}) — cluster-P&L:\n${clusterTekst}\n\n` +
    `NØKKELTALL PER STASJON hittil i år (omsetning, brutto, lønn mot lønnsbudsjett — eks. drivstoff/pant):\n${stasjonTekst}\n\n` +
    `USYNLIG SVINN PER STASJON hittil i år (+ = manko, − = overskudd):\n${svinnTekst || 'Ingen usynlig svinn-data.'}\n\n` +
    `KRYSS-STASJON hittil i år:\n${kryssTekst || 'Ingen tydelige kryss-mønstre.'}\n\n` +
    'Dette er en HITTIL-I-ÅR-vurdering (årsbasis, ny start hvert år) — vurder den RØDE TRÅDEN, ikke enkeltmåneder. En enkeltmåned i minus som netter ut over året er ikke krise. Lag analysen: sammendrag (3–5 linjer: resultat vs budsjett hittil, beste/verste stasjon, hva som haster), per-stasjon status + kommentar (på årsbasis), systemfeil (kryss-stasjon-mønstre), røde flagg, muligheter, tiltak (m/prioritet). La «endringer» være tom.'

  return kjorOpusOgLagre(supabase, retailerId, til, 'hittil', brukerMelding)
}

export async function genererRegnskapsanalyseHittil(aar?: string): Promise<Resultat> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan kjøre regnskapsanalysen.' }
  }
  const supabase = await lagSupabaseServerKlient()
  return kjorRegnskapsanalyseHittil(supabase, bruker.retailerId, aar)
}
