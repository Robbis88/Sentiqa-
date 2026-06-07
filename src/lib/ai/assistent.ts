import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { VERKTOY, VERKTOY_SCHEMA } from './verktoy'

// Chatbot kjører på Sonnet (PROSJEKT.md §8/§18 — margin; hev til Opus ved behov).
const CHATBOT_MODELL = 'claude-sonnet-4-6'
const MAKS_ITERASJONER = 8

export type Melding = { rolle: 'bruker' | 'assistent'; tekst: string }
export type AssistentSvar = { svar: string; kilder: string[] }

const VERKTOY_ETIKETT: Record<string, string> = {
  list_stasjoner: 'stasjoner',
  hent_salg: 'salg',
  hent_regnskap: 'regnskap',
  hent_svinn: 'svinn',
  hent_timesalg: 'timesalg',
}

function systemprompt(bruker: InnloggetBruker, idag: string): string {
  const rolleRegel =
    bruker.rolle === 'retailer_admin'
      ? 'Du er eierens assistent og kan vise alle stasjoners tall, kostnader og regnskap.'
      : 'Du hjelper en butikksjef med deres egne stasjoner. Oppgi aldri andre stasjoners eksakte tall — relativ plassering er greit, eksakte tall ikke.'

  return [
    'Du er Sentiqa-assistenten for en bensinstasjons-eier. Du svarer på norsk bokmål.',
    rolleRegel,
    'ALDRI finn på et tall. Slå alltid opp tall via verktøyene. Kan du ikke slå det opp, si det ærlig.',
    'Svar kort: 2–4 setninger, med konkrete tiltak (f.eks. «sjekk vaktplan man–ons», ikke «vurder bemanning»).',
    'Alle beløp er i norske kroner. All tid er Europe/Oslo.',
    `Dagens dato er ${idag}.`,
    `Brukerens rolle: ${ROLLE_ETIKETT[bruker.rolle]}.`,
  ].join('\n')
}

export async function kjorAssistent(
  bruker: InnloggetBruker,
  historikk: Melding[],
  nyMelding: string,
): Promise<AssistentSvar> {
  if (!env.ANTHROPIC_API_KEY) {
    return {
      svar: 'AI-assistenten er ikke aktivert ennå — legg inn ANTHROPIC_API_KEY i .env.local.',
      kilder: [],
    }
  }

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const messages: Anthropic.MessageParam[] = [
    ...historikk.map((m): Anthropic.MessageParam => ({
      role: m.rolle === 'bruker' ? 'user' : 'assistant',
      content: m.tekst,
    })),
    { role: 'user', content: nyMelding },
  ]

  const kilder = new Set<string>()
  let svar = ''

  for (let i = 0; i < MAKS_ITERASJONER; i++) {
    const resp = await anthropic.messages.create({
      model: CHATBOT_MODELL,
      max_tokens: 2048,
      system: systemprompt(bruker, idag),
      tools: VERKTOY_SCHEMA,
      messages,
    })

    if (resp.stop_reason !== 'tool_use') {
      svar = resp.content
        .filter((b): b is Anthropic.TextBlock => b.type === 'text')
        .map((b) => b.text)
        .join('\n')
        .trim()
      break
    }

    messages.push({ role: 'assistant', content: resp.content })
    const resultater: Anthropic.ToolResultBlockParam[] = []

    for (const block of resp.content) {
      if (block.type !== 'tool_use') continue
      const verktoy = VERKTOY[block.name]
      kilder.add(VERKTOY_ETIKETT[block.name] ?? block.name)

      let utdata: unknown
      try {
        utdata = verktoy
          ? await verktoy.kjor(block.input as Record<string, unknown>, supabase)
          : { feil: 'Ukjent verktøy.' }
      } catch (e) {
        utdata = { feil: `Verktøyfeil: ${String(e)}` }
      }

      // Logg kallet (§8/§15). Argumentene her er datoer/butikknummer — ingen PII.
      if (bruker.retailerId) {
        await supabase.from('ai_tool_log').insert({
          retailer_id: bruker.retailerId,
          bruker_id: bruker.id,
          verktoy: block.name,
          argument: block.input as Record<string, unknown>,
        })
      }

      resultater.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: JSON.stringify(utdata),
      })
    }

    messages.push({ role: 'user', content: resultater })
  }

  if (!svar) svar = 'Jeg klarte ikke å fullføre svaret. Prøv å spørre litt enklere.'
  return { svar, kilder: [...kilder] }
}
