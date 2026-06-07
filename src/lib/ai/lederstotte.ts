import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'

// Per-stasjon coaching → Sonnet (ikke-sanntid, §8).
const MODELL = 'claude-sonnet-4-6'

export const LederstotteSchema = z.object({
  status: z.enum(['gronn', 'gul', 'bla']), // aldri rød (§8D)
  oppsummering: z.string(),
  styrker: z.array(z.string()),
  utviklingsomrader: z.array(z.string()),
  nesteSteg: z.array(z.string()),
})
export type Lederstotte = z.infer<typeof LederstotteSchema>

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

async function forStasjon(
  anthropic: Anthropic,
  supabase: Klient,
  stasjonId: string,
  navn: string,
  periode: string,
): Promise<Lederstotte | null> {
  const { data } = await supabase
    .from('regnskapslinjer')
    .select('post, regnskap, budsjett, index_pct')
    .eq('periode', periode)
    .eq('stasjon_id', stasjonId)
    .eq('seksjon', 'omsetning')
    .overrideTypes<{ post: string; regnskap: number | null; budsjett: number | null; index_pct: number | null }[]>()
  if (!data || data.length === 0) return null

  const tall = data
    .map((l) => `${l.post}: ${Math.round(l.regnskap ?? 0)} kr av budsjett ${Math.round(l.budsjett ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} %)`)
    .join('\n')

  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 1024,
    system:
      'Du er Sentiqa-assistenten og skriver en utviklingsorientert lederstøtte-rapport til en butikksjef. ' +
      'Coaching-tone: oppmuntrende og fremovervendt, ALDRI anklagende. Bruk status gronn (sterkt), gul (på god vei) ' +
      'eller bla (utviklingspotensial) — ALDRI ord som «dårlig» eller «rødt». Norsk bokmål. Bruk konkrete tall.',
    messages: [
      {
        role: 'user',
        content:
          `Stasjon: ${navn}. Omsetning mot budsjett denne måneden:\n${tall}\n\n` +
          'Skriv: kort oppsummering, 2–3 styrker, 2–3 utviklingsområder (formulert som muligheter), og 2–3 konkrete neste steg.',
      },
    ],
    output_config: { format: zodOutputFormat(LederstotteSchema) },
  })
  return resp.parsed_output ?? null
}

export async function genererAlleLederstotte(): Promise<
  { ok: true; antall: number; periode: string } | { ok: false; grunn: string }
> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan generere lederstøtte-rapporter.' }
  }
  if (!env.ANTHROPIC_API_KEY) return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }
  const retailerId = bruker.retailerId
  const supabase = await lagSupabaseServerKlient()

  const { data: siste } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .not('stasjon_id', 'is', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()
  if (!siste) return { ok: false, grunn: 'Ingen regnskap per stasjon ennå. Behandle en regnskapsfil først.' }
  const periode = siste.periode

  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  await supabase.from('lederstotte_rapporter').delete().eq('retailer_id', retailerId).eq('periode', periode)

  const rader = (
    await Promise.all(
      (stasjoner ?? []).map(async (s) => {
        const rapport = await forStasjon(anthropic, supabase, s.id, `${s.butikknummer} ${s.navn}`, periode)
        return rapport
          ? { retailer_id: retailerId, stasjon_id: s.id, periode, rapport, modell: MODELL }
          : null
      }),
    )
  ).filter((r): r is NonNullable<typeof r> => r !== null)

  if (rader.length > 0) {
    const { error } = await supabase.from('lederstotte_rapporter').insert(rader)
    if (error) return { ok: false, grunn: error.message }
  }
  return { ok: true, antall: rader.length, periode }
}
