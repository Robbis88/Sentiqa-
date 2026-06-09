import 'server-only'
import { createHash } from 'node:crypto'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { maalFor } from '@/lib/sprak'

const OversettSchema = z.object({ oversettelser: z.array(z.string()) })
const hash = (t: string) => createHash('sha256').update(t).digest('hex')

// Oversetter en liste tekster til valgt språk. Cache først (sha256), Haiku for
// resten. Faller alltid tilbake til norsk om noe mangler/feiler.
export async function oversettMange(tekster: string[], sprak: string): Promise<Map<string, string>> {
  const map = new Map<string, string>()
  const unike = [...new Set(tekster.filter(Boolean))]
  for (const t of unike) map.set(t, t) // standard: norsk

  const maal = maalFor(sprak)
  if (sprak === 'no' || !maal || !env.ANTHROPIC_API_KEY || unike.length === 0) return map

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return map
  }

  const hashes = unike.map(hash)
  const { data: cachet } = await admin
    .from('oversettelse_cache')
    .select('kilde_hash, oversatt')
    .eq('sprak', sprak)
    .in('kilde_hash', hashes)
  const cacheMap = new Map((cachet ?? []).map((c: { kilde_hash: string; oversatt: string }) => [c.kilde_hash, c.oversatt]))

  const mangler: string[] = []
  for (const t of unike) {
    const truffet = cacheMap.get(hash(t))
    if (truffet) map.set(t, truffet)
    else mangler.push(t)
  }
  if (mangler.length === 0) return map

  try {
    const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
    const resp = await anthropic.messages.parse({
      model: 'claude-haiku-4-5',
      max_tokens: 2048,
      system: `Oversett hver norske tekst (rutiner i butikk) til ${maal}. Behold rekkefølgen og antall elementer. Naturlig og kortfattet, samme tone.`,
      messages: [{ role: 'user', content: JSON.stringify(mangler) }],
      output_config: { format: zodOutputFormat(OversettSchema) },
    })
    const ut = resp.parsed_output?.oversettelser ?? []
    const innsett: { sprak: string; kilde_hash: string; oversatt: string }[] = []
    mangler.forEach((t, i) => {
      const o = ut[i]
      if (o) {
        map.set(t, o)
        innsett.push({ sprak, kilde_hash: hash(t), oversatt: o })
      }
    })
    if (innsett.length > 0) await admin.from('oversettelse_cache').upsert(innsett, { onConflict: 'sprak,kilde_hash' })
  } catch {
    // fallback: norsk (identity allerede satt)
  }
  return map
}
