import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'

// Interaktiv tekstformulering → Sonnet (rask, god norsk prosa). PROSJEKT.md §8.
const MODELL = 'claude-sonnet-4-6'

const Schema = z.object({
  tittel: z.string(),
  innhold: z.string(),
})
export type Nyhetsforslag = z.infer<typeof Schema>

// Tar redaktørens stikkord/idé + ønsket tone → ferdig formulert nyhet (tittel +
// innhold). Returnerer null hvis AI ikke er konfigurert.
export async function formulerNyhetstekst(ide: string, tone: string): Promise<Nyhetsforslag | null> {
  if (!env.ANTHROPIC_API_KEY) return null
  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 1200,
    system:
      'Du er kommunikasjonsrådgiver for Sentiqa — et norsk SaaS for servicehandel (bensinstasjon-/kioskkjeder). ' +
      'Du skriver korte nyheter som vises til kjedene: eiere, butikksjefer og ansatte på nettbrett. Norsk bokmål.\n' +
      'Lag (1) en fengende, konkret TITTEL på maks ~8 ord, og (2) et INNHOLD på 2–4 korte avsnitt som er lette å lese på en skjerm. ' +
      'Vær varm og tydelig. ALDRI finn på fakta, tall, datoer eller funksjoner som ikke står i stikkordene — hold deg til det redaktøren oppgir. ' +
      'Tilpass språket til ønsket tone. Ikke bruk emoji i tittelen; maks ett i innholdet hvis det passer.',
    messages: [{ role: 'user', content: `Ønsket tone: ${tone}.\n\nStikkord / idé til nyheten:\n${ide}` }],
    output_config: { format: zodOutputFormat(Schema) },
  })
  return resp.parsed_output ?? null
}
