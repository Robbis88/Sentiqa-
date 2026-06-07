import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'

// Faktura-parsing krever god vision-kvalitet (§11: vanskeligst å gjøre pålitelig) → Opus.
const MODELL = 'claude-opus-4-8'

export const FakturaSchema = z.object({
  leverandor: z.string(),
  kategori: z.string(), // f.eks. mobil, renovasjon, strøm, forsikring, leie
  faktura_dato: z.string(), // YYYY-MM-DD
  belop_kr: z.number(),
  beskrivelse: z.string(),
})
export type Faktura = z.infer<typeof FakturaSchema>

function innholdsblokk(base64: string, mediaType: string) {
  if (mediaType === 'application/pdf') {
    return { type: 'document' as const, source: { type: 'base64' as const, media_type: 'application/pdf' as const, data: base64 } }
  }
  const mt = mediaType === 'image/png' ? 'image/png' : 'image/jpeg'
  return { type: 'image' as const, source: { type: 'base64' as const, media_type: mt as 'image/png' | 'image/jpeg', data: base64 } }
}

export async function parseFaktura(data: Buffer, mediaType: string): Promise<Faktura | null> {
  if (!env.ANTHROPIC_API_KEY) return null
  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const blokk = innholdsblokk(data.toString('base64'), mediaType)

  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 1024,
    system:
      'Du leser en norsk faktura og trekker ut: leverandør (firmanavn), kategori (mobil/renovasjon/strøm/' +
      'forsikring/leie/annet), fakturadato (YYYY-MM-DD), totalbeløp i kroner, og en kort beskrivelse. ' +
      'ALDRI finn på tall — les dem fra fakturaen.',
    messages: [
      { role: 'user', content: [blokk, { type: 'text', text: 'Trekk ut feltene fra denne fakturaen.' }] },
    ],
    output_config: { format: zodOutputFormat(FakturaSchema) },
  })
  return resp.parsed_output ?? null
}

// Forhandlings-utkast: AI fyller ut en e-post med dine faktiske tall (særlig
// total årlig spend = kjøpekraften). Mennesket sender, aldri AI-en (§11).
export async function lagForhandlingsutkast(
  leverandor: string,
  kategori: string,
  totalAarlig: number,
  antallStasjoner: number,
  detaljer: string,
): Promise<string> {
  if (!env.ANTHROPIC_API_KEY) return 'AI er ikke aktivert.'
  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const resp = await anthropic.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    system:
      'Du skriver et profesjonelt, vennlig forhandlings-e-postutkast på norsk bokmål til en leverandør. ' +
      'Bruk kundens faktiske tall (særlig samlet årlig spend som kjøpekraft – kunden forhandler som én konto ' +
      'for alle stasjonene). Be om bedre betingelser. ALDRI finn på tall. Mennesket sender selv.',
    messages: [
      {
        role: 'user',
        content:
          `Leverandør: ${leverandor} (${kategori}). Samlet årlig spend: ${Math.round(totalAarlig)} kr fordelt på ` +
          `${antallStasjoner} stasjon(er).\nDetaljer:\n${detaljer}\n\nSkriv et forhandlings-utkast.`,
      },
    ],
  })
  return resp.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('\n')
    .trim()
}
