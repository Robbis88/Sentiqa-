import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'

// Auto-fokus er ikke-sanntid → Sonnet holder (PROSJEKT.md §8; batch-API senere).
const MODELL = 'claude-sonnet-4-6'

const FokusSchema = z.object({
  forbedring: z.array(z.string()),
  positivt: z.array(z.string()),
})

type Klient = SupabaseClient

async function forStasjon(
  anthropic: Anthropic,
  supabase: Klient,
  stasjonId: string,
  navn: string,
  periode: string,
): Promise<{ forbedring: string[]; positivt: string[] } | null> {
  const { data } = await supabase
    .from('regnskapslinjer')
    .select('post, regnskap, budsjett, index_pct')
    .eq('periode', periode)
    .eq('stasjon_id', stasjonId)
    .eq('seksjon', 'omsetning')
    .overrideTypes<{ post: string; regnskap: number | null; budsjett: number | null; index_pct: number | null }[]>()

  if (!data || data.length === 0) return null

  const tall = data
    .map(
      (l) =>
        `${l.post}: regnskap ${Math.round(l.regnskap ?? 0)} kr, budsjett ${Math.round(l.budsjett ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} % mot budsjett)`,
    )
    .join('\n')

  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 1024,
    system:
      'Du er Sentiqa-assistenten. Etter månedsregnskapet lager du fokuspunkter til en butikksjef. ' +
      'Norsk bokmål. Hvert punkt er ÉN setning med et konkret tiltak og et konkret tall (kroner eller %). ' +
      'Aldri finn på tall — bruk kun tallene du får. Vær oppmuntrende, ikke anklagende.',
    messages: [
      {
        role: 'user',
        content:
          `Stasjon: ${navn}. Omsetning mot budsjett denne måneden:\n${tall}\n\n` +
          'Gi nøyaktig 3 forbedringspunkter (varegrupper som ligger under budsjett og bør løftes) ' +
          'og nøyaktig 3 positive punkter (der stasjonen gjør det bra), hver med tall.',
      },
    ],
    output_config: { format: zodOutputFormat(FokusSchema) },
  })

  return resp.parsed_output ?? null
}

// Genererer og lagrer fokuspunkter for alle stasjoner (siste regnskapsperiode)
// for ÉN kjede. Tar klient + retailerId → fungerer både fra UI (sesjon) og
// nattjobb (service-role).
export async function genererFokusForRetailer(
  supabase: Klient,
  retailerId: string,
): Promise<{ ok: true; antall: number; periode: string } | { ok: false; grunn: string }> {
  if (!env.ANTHROPIC_API_KEY) {
    return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }
  }

  const { data: siste } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .eq('retailer_id', retailerId)
    .not('stasjon_id', 'is', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()
  if (!siste) return { ok: false, grunn: 'Ingen regnskap per stasjon ennå. Behandle en regnskapsfil først.' }
  const periode = siste.periode

  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })

  // Erstatt periodens fokuspunkter (idempotent).
  await supabase.from('fokuspunkter').delete().eq('retailer_id', retailerId).eq('periode', periode)

  const resultater = await Promise.all(
    (stasjoner ?? []).map(async (s) => {
      const pts = await forStasjon(anthropic, supabase, s.id, `${s.butikknummer} ${s.navn}`, periode)
      if (!pts) return []
      return [
        ...pts.forbedring.slice(0, 3).map((tekst) => ({ retailer_id: retailerId, stasjon_id: s.id, periode, type: 'forbedring', tekst })),
        ...pts.positivt.slice(0, 3).map((tekst) => ({ retailer_id: retailerId, stasjon_id: s.id, periode, type: 'positivt', tekst })),
      ]
    }),
  )

  const rader = resultater.flat()
  if (rader.length > 0) {
    const { error } = await supabase.from('fokuspunkter').insert(rader)
    if (error) return { ok: false, grunn: error.message }
  }
  return { ok: true, antall: rader.length, periode }
}

// UI-knappen: kjør for innlogget eiers egen kjede.
export async function genererAlleFokus(): Promise<
  { ok: true; antall: number; periode: string } | { ok: false; grunn: string }
> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan generere fokuspunkter.' }
  }
  const supabase = await lagSupabaseServerKlient()
  return genererFokusForRetailer(supabase, bruker.retailerId)
}
