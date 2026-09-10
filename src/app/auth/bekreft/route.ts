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
//
// =====================================================================
// «INGEN FEIL» ER IKKE «INNLOGGET»
//
// Begge kallene kan svare uten `error` og likevel uten sesjon. `verifyOtp`
// POSTer til `/verify` og leser sesjonen ut av svaret; mangler den, kaster
// den ikke — den returnerer `{ user: null, session: null, error: null }`.
// Cookien skrives bare når det finnes et `access_token`, så resultatet er
// en bruker som sendes videre UTEN å være innlogget.
//
// Da har `/sett-passord` ingen bruker, og sier «Lenken er utløpt eller
// allerede brukt». Det er feil forklaring: lenken var fersk og ble
// godtatt. Den som leser meldingen ber om en ny lenke, får samme svar, og
// leter etter et problem som ikke finnes.
//
// Derfor sjekkes sesjonen, ikke fraværet av feil. Dette traff oss ikke
// 2026-09-10 — PKCE-tokenet fra Supabase-malen løste seg fint — men det
// er en stille feilmåte, og en stille feilmåte venter bare.
// =====================================================================
export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url)
  const token_hash = searchParams.get('token_hash')
  const type = searchParams.get('type') as EmailOtpType | null
  const code = searchParams.get('code')

  const supabase = await lagSupabaseServerKlient()

  if (token_hash && type) {
    const { data, error } = await supabase.auth.verifyOtp({ type, token_hash })
    const ny = type === 'invite' || type === 'signup' ? '?ny=1' : ''
    if (!error && data.session?.access_token) {
      return NextResponse.redirect(`${origin}/sett-passord${ny}`)
    }
    if (!error) {
      // Godtatt, men tom. Loggen bærer `type` og formen på tokenet —
      // ikke tokenet selv, som fortsatt er gyldig i noen minutter.
      console.error('[auth/bekreft] verifyOtp ga ingen sesjon:', {
        type,
        prefiks: token_hash.slice(0, 5),
      })
      return NextResponse.redirect(`${origin}/logg-inn?feil=ingen-sesjon`)
    }
  } else if (code) {
    const { data, error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error && data.session?.access_token) {
      return NextResponse.redirect(`${origin}/sett-passord`)
    }
    if (!error) {
      console.error('[auth/bekreft] exchangeCodeForSession ga ingen sesjon')
      return NextResponse.redirect(`${origin}/logg-inn?feil=ingen-sesjon`)
    }
  }
  // TRE ULIKE FEIL, OG DE HAR HVER SIN AARSAK.
  //
  // «ingen-token» betyr at lenken ikke BAR noe. Da er den nesten alltid
  // bygget av Supabase sin standardmal, som sender tokenet i URL-
  // fragmentet (`#access_token=…`) — og et fragment naar aldri serveren.
  // Symptomet er en lenke som ser helt riktig ut og ikke gjoer noe.
  // Malene i `supabase/templates/` bruker `token_hash` i spoerrestrengen
  // nettopp for aa unngaa det; ser du denne, stemmer ikke dashboardet med
  // dem lenger.
  //
  // «ingen-sesjon» betyr at tokenet ble GODTATT og likevel ikke ga noen
  // innlogging. Vaar sak, ikke hennes — se blokken oeverst.
  //
  // «invitasjon» betyr at tokenet var der og ble avvist: utloept eller
  // brukt. Det er helt normalt og brukerens sak.
  //
  // Ett felles «noe gikk galt» ville gjort en oppsettsfeil hos oss
  // umulig aa skille fra en gammel lenke hos henne.
  const grunn = token_hash || code ? 'invitasjon' : 'ingen-token'
  return NextResponse.redirect(`${origin}/logg-inn?feil=${grunn}`)
}
