import { type NextRequest, NextResponse } from 'next/server'
import type { EmailOtpType } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// Landingspunkt for invitasjons-/gjenopprettingslenker. To flyter støttes:
//  1) token_hash + type  → verifyOtp (e-postlenker; virker uansett enhet) — anbefalt
//  2) code               → exchangeCodeForSession (PKCE)
// Lykkes verifiseringen er brukeren innlogget (cookie) og sendes til /sett-passord.
//
// `?ny=1` skiller de to ærendene på den siden: en invitasjon møtes med
// «Velkommen», en glemt-passord-lenke med «Nytt passord». PKCE-armen vet
// ikke hvilken lenke det var — `code` bærer ingen type — og da er den
// nøytrale teksten det ærlige valget.
export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url)
  const token_hash = searchParams.get('token_hash')
  const type = searchParams.get('type') as EmailOtpType | null
  const code = searchParams.get('code')

  const supabase = await lagSupabaseServerKlient()

  if (token_hash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash })
    const ny = type === 'invite' || type === 'signup' ? '?ny=1' : ''
    if (!error) return NextResponse.redirect(`${origin}/sett-passord${ny}`)
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}/sett-passord`)
  }
  // TO ULIKE FEIL, OG DE HAR HVER SIN AARSAK.
  //
  // «ingen-token» betyr at lenken ikke BAR noe. Da er den nesten alltid
  // bygget av Supabase sin standardmal, som sender tokenet i URL-
  // fragmentet (`#access_token=…`) — og et fragment naar aldri serveren.
  // Symptomet er en lenke som ser helt riktig ut og ikke gjoer noe.
  // Malene i `supabase/templates/` bruker `token_hash` i spoerrestrengen
  // nettopp for aa unngaa det; ser du denne, stemmer ikke dashboardet med
  // dem lenger.
  //
  // «invitasjon» betyr at tokenet var der og ble avvist: utloept eller
  // brukt. Det er helt normalt og brukerens sak.
  //
  // Ett felles «noe gikk galt» ville gjort en oppsettsfeil hos oss
  // umulig aa skille fra en gammel lenke hos henne.
  const grunn = token_hash || code ? 'invitasjon' : 'ingen-token'
  return NextResponse.redirect(`${origin}/logg-inn?feil=${grunn}`)
}
