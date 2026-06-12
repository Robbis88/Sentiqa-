import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'

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

type Linje = { seksjon: string; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }
type Usynlig = { stasjon_id: string; navn: string; salg: number | null; brf_pst: number | null; usynlig_kr: number | null; usynlig_pst: number | null }

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
    supabase.from('regnskapslinjer').select('seksjon, post, regnskap, budsjett, avvik, index_pct').eq('retailer_id', retailerId).eq('periode', periode).is('stasjon_id', null).order('sortering').overrideTypes<Linje[]>(),
    supabase.from('regnskapslinjer').select('stasjon_id, regnskap, budsjett').eq('retailer_id', retailerId).eq('periode', periode).eq('seksjon', 'omsetning').not('stasjon_id', 'is', null).overrideTypes<{ stasjon_id: string; regnskap: number | null; budsjett: number | null }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase.from('regnskap_usynlig_svinn').select('stasjon_id, navn, salg, brf_pst, usynlig_kr, usynlig_pst').eq('retailer_id', retailerId).eq('periode', periode).is('slettet_tid', null).overrideTypes<Usynlig[]>(),
    supabase.from('regnskapsanalyser').select('periode, rapport').eq('retailer_id', retailerId).lt('periode', periode).is('slettet_tid', null).order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string; rapport: Analyse }>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Cluster-P&L
  const clusterTekst = (cluster ?? [])
    .map((l) => `[${l.seksjon}] ${l.post}: regnskap ${Math.round(l.regnskap ?? 0)} kr, budsjett ${Math.round(l.budsjett ?? 0)} kr, avvik ${Math.round(l.avvik ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} %)`)
    .join('\n')

  // Omsetning per stasjon
  const perSum = new Map<string, { r: number; b: number }>()
  for (const r of perRader ?? []) {
    const p = perSum.get(r.stasjon_id) ?? { r: 0, b: 0 }
    p.r += r.regnskap ?? 0; p.b += r.budsjett ?? 0; perSum.set(r.stasjon_id, p)
  }
  const stasjonTekst = [...perSum.entries()].filter(([id]) => navnFor.has(id))
    .map(([id, p]) => `${navnFor.get(id)}: omsetning ${Math.round(p.r)} kr av budsjett ${Math.round(p.b)} kr (${p.b ? (((p.r - p.b) / p.b) * 100).toFixed(1) : '0'} %)`)
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

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 8192,
    thinking: { type: 'adaptive' },
    system:
      'Du er eierens FASTE REGNSKAPSFØRER for en servicehandel-kjede (bensinstasjoner). Norsk bokmål. ' +
      'Vær DIREKTE og handlingsorientert — skriv «betyr at», ikke «kan tyde på». ALDRI finn på tall; bruk kun tallene du får. Vær konkret med kroner og prosent.\n' +
      'FORTEGNS-REGEL på usynlig svinn: positivt tall = MANKO (penger forsvinner = tap). Negativt tall = OVERSKUDD på lager (som regel feilslag/registreringsfeil på kassa). Si ALLTID «manko» eller «overskudd», aldri bare «svinn».\n' +
      'Let etter MØNSTRE PÅ TVERS av stasjoner = systemfeil, ikke enkeltstasjon. Eksempler: KAFFE-manko + KAFFELOJALITET-overskudd = lojalitetskaffe registreres feil; MASKINVASK APP-overskudd = app-betalinger lekker og MASKERER ekte manko. Slike funn skal i «systemfeil».\n' +
      'Bruk RESULTAT EX 9900 (uten admin-stasjon 9900) mot budsjett for driftsvurderingen, og total-RESULTAT for bunnlinja.\n' +
      'Status per stasjon: gronn (på/over budsjett, lite reell manko), gul (litt under), rod (klart under / reell manko). 2–4 setninger med konkrete tall per stasjon.\n' +
      'Tiltak: 3–5 konkrete handlinger med prioritet (hoy/medium/lav) — «sjekk vaktplan på Lone man–ons», ikke «vurder bemanning». Maks 5 røde flagg.',
    messages: [{
      role: 'user',
      content:
        `MÅNEDSREGNSKAP (cluster-P&L):\n${clusterTekst}\n\n` +
        `OMSETNING PER STASJON:\n${stasjonTekst}\n\n` +
        `USYNLIG SVINN PER STASJON (+ = manko, − = overskudd):\n${svinnTekst || 'Ingen usynlig svinn-data.'}\n\n` +
        `KRYSS-STASJON (samme vare på flere stasjoner):\n${kryssTekst || 'Ingen tydelige kryss-mønstre.'}\n\n` +
        `${forrigeTekst}\n\n` +
        'Lag analysen: sammendrag (3–5 linjer: resultat vs budsjett, beste/verste, hva som haster), per-stasjon status + kommentar, systemfeil (kryss-stasjon-mønstre), røde flagg, muligheter, tiltak (m/prioritet), og endringer vs forrige periode.',
    }],
    output_config: { format: zodOutputFormat(AnalyseSchema) },
  })

  const analyse = resp.parsed_output
  if (!analyse) return { ok: false, grunn: 'AI-en ga ikke et gyldig svar. Prøv igjen.' }

  await supabase.from('regnskapsanalyser').delete().eq('retailer_id', retailerId).eq('periode', periode)
  const { error } = await supabase.from('regnskapsanalyser').insert({ retailer_id: retailerId, periode, rapport: analyse, modell: MODELL })
  if (error) return { ok: false, grunn: error.message }
  return { ok: true, periode }
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
