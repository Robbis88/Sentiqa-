import 'server-only'
import { cookies } from 'next/headers'
import { velgStasjon, type Stasjon } from './stasjonsvalg'

/**
 * Navnet på informasjonskapselen.
 *
 * Bor her, ikke i 'use server'-fila: den kan bare eksportere async
 * funksjoner, og en konstant der brekker bygget.
 */
export const STASJONSKAPSEL = 'sentiqa_stasjon'

/**
 * Hvilken stasjon siden skal vise.
 *
 * Erstatter `alle.find((s) => s.id === sok.stasjon) ?? alle[0]`, som sto
 * i hver side og ignorerte at brukeren hadde valgt noe i toppstripen.
 *
 * URL-en vinner fortsatt — en delt lenke skal vise det den lovet.
 */
export async function husketStasjon(
  alle: Stasjon[],
  fraUrl?: string | null,
  tillatAlle = false,
): Promise<string | null> {
  const husket = (await cookies()).get(STASJONSKAPSEL)?.value ?? null
  return velgStasjon(alle, { fraUrl, fraHukommelse: husket, tillatAlle })
}
