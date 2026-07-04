import { NextResponse, type NextRequest } from 'next/server'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

/**
 * Retensjons-cron (Vercel Cron). Dataminimering: sletter AI-genererte
 * analyser/rapporter og verktøylogg eldre enn RETENSJON_MND. Rører ikke
 * fakturaer eller annen bokføringspliktig data.
 * Beskyttet av CRON_SECRET (Vercel sender den i Authorization-headeren).
 */
export const maxDuration = 60

const RETENSJON_MND = 12
const TABELLER = [
  'regnskapsanalyser',
  'lederstotte_rapporter',
  'fokuspunkter',
  'ai_tool_log',
] as const

export async function GET(req: NextRequest) {
  const auth = req.headers.get('authorization')
  if (!env.CRON_SECRET || auth !== `Bearer ${env.CRON_SECRET}`) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }

  const supabase = lagSupabaseAdminKlient()
  const grense = new Date()
  grense.setMonth(grense.getMonth() - RETENSJON_MND)
  const grenseISO = grense.toISOString()

  const slettet: Record<string, number | string> = {}
  for (const tabell of TABELLER) {
    const { data, error } = await supabase
      .from(tabell)
      .delete()
      .lt('opprettet_tid', grenseISO)
      .select('retailer_id')
    slettet[tabell] = error ? `feil: ${error.message}` : (data?.length ?? 0)
  }

  return NextResponse.json({ ok: true, slettet })
}
