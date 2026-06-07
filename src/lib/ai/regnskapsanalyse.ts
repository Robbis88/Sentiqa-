import 'server-only'
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
  rodeFlagg: z.array(z.string()),
  muligheter: z.array(z.string()),
  tiltak: z.array(z.string()),
})
export type Analyse = z.infer<typeof AnalyseSchema>

export async function genererRegnskapsanalyse(): Promise<
  { ok: true; periode: string } | { ok: false; grunn: string }
> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan kjøre regnskapsanalysen.' }
  }
  if (!env.ANTHROPIC_API_KEY) return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }
  const retailerId = bruker.retailerId
  const supabase = await lagSupabaseServerKlient()

  const { data: siste } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .is('stasjon_id', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()
  if (!siste) return { ok: false, grunn: 'Ingen regnskap ennå. Behandle en regnskapsfil først.' }
  const periode = siste.periode

  // Cluster-P&L
  const { data: cluster } = await supabase
    .from('regnskapslinjer')
    .select('seksjon, post, regnskap, budsjett, avvik, index_pct')
    .eq('periode', periode)
    .is('stasjon_id', null)
    .order('sortering')
    .overrideTypes<{ seksjon: string; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }[]>()

  // Per-stasjon omsetning
  const [{ data: perRader }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('regnskapslinjer')
      .select('stasjon_id, regnskap, budsjett')
      .eq('periode', periode)
      .eq('seksjon', 'omsetning')
      .not('stasjon_id', 'is', null)
      .overrideTypes<{ stasjon_id: string; regnskap: number | null; budsjett: number | null }[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perSum = new Map<string, { r: number; b: number }>()
  for (const r of perRader ?? []) {
    const p = perSum.get(r.stasjon_id) ?? { r: 0, b: 0 }
    p.r += r.regnskap ?? 0
    p.b += r.budsjett ?? 0
    perSum.set(r.stasjon_id, p)
  }

  const clusterTekst = (cluster ?? [])
    .map((l) => `[${l.seksjon}] ${l.post}: regnskap ${Math.round(l.regnskap ?? 0)} kr, budsjett ${Math.round(l.budsjett ?? 0)} kr, avvik ${Math.round(l.avvik ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} %)`)
    .join('\n')
  const stasjonTekst = [...perSum.entries()]
    .filter(([id]) => navnFor.has(id))
    .map(([id, p]) => `${navnFor.get(id)}: omsetning ${Math.round(p.r)} kr av budsjett ${Math.round(p.b)} kr (${p.b ? (((p.r - p.b) / p.b) * 100).toFixed(1) : '0'} %)`)
    .join('\n')

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 8192,
    thinking: { type: 'adaptive' },
    system:
      'Du er Sentiqa-assistenten og lager en regnskapsanalyse for en bensinstasjons-eier. ' +
      'Norsk bokmål. ALDRI finn på tall — bruk kun tallene du får. Vær konkret med kroner og prosent. ' +
      'Sett status per stasjon: gronn (på/over budsjett), gul (litt under), rod (klart under). ' +
      'Tiltak skal være konkrete handlinger, prioritert med viktigst først.',
    messages: [
      {
        role: 'user',
        content:
          `Månedsregnskap (cluster-nivå):\n${clusterTekst}\n\nOmsetning per stasjon:\n${stasjonTekst}\n\n` +
          'Lag en analyse: kort sammendrag (2–4 setninger), status + kommentar per stasjon, ' +
          'røde flagg (det som haster), muligheter, og prioriterte tiltak.',
      },
    ],
    output_config: { format: zodOutputFormat(AnalyseSchema) },
  })

  const analyse = resp.parsed_output
  if (!analyse) return { ok: false, grunn: 'AI-en ga ikke et gyldig svar. Prøv igjen.' }

  await supabase.from('regnskapsanalyser').delete().eq('retailer_id', retailerId).eq('periode', periode)
  const { error } = await supabase.from('regnskapsanalyser').insert({
    retailer_id: retailerId,
    periode,
    rapport: analyse,
    modell: MODELL,
  })
  if (error) return { ok: false, grunn: error.message }
  return { ok: true, periode }
}
