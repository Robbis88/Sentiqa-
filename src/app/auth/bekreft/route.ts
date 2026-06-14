import { type NextRequest, NextResponse } from 'next/server'
import type { EmailOtpType } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// Landingspunkt for invitasjons-/gjenopprettingslenker. To flyter støttes:
//  1) token_hash + type  → verifyOtp (e-postlenker; virker uansett enhet) — anbefalt
//  2) code               → exchangeCodeForSession (PKCE)
// Lykkes verifiseringen er brukeren innlogget (cookie) og sendes til /sett-passord.
export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url)
  const token_hash = searchParams.get('token_hash')
  const type = searchParams.get('type') as EmailOtpType | null
  const code = searchParams.get('code')

  const supabase = await lagSupabaseServerKlient()

  if (token_hash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash })
    if (!error) return NextResponse.redirect(`${origin}/sett-passord`)
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}/sett-passord`)
  }
  return NextResponse.redirect(`${origin}/logg-inn?feil=invitasjon`)
}
