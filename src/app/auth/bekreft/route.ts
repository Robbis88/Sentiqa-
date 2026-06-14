import { type NextRequest, NextResponse } from 'next/server'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// Landingspunkt for invitasjons-/gjenopprettingslenker. Supabase sender brukeren
// hit med en ?code som byttes mot en sesjon (cookie). Deretter velger de passord.
export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url)
  const code = searchParams.get('code')
  if (code) {
    const supabase = await lagSupabaseServerKlient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}/sett-passord`)
  }
  return NextResponse.redirect(`${origin}/logg-inn?feil=invitasjon`)
}
