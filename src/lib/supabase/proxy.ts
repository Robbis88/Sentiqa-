import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { env } from '@/lib/env'

// Offentlige ruter (ingen innlogging kreves). Alt annet krever sesjon.
// '/' (landingssiden) matches eksakt; resten som prefiks.
const OFFENTLIGE_PREFIX = ['/logg-inn', '/registrer', '/auth/bekreft', '/sett-passord', '/personvern', '/databehandleravtale']
function erOffentligSti(sti: string): boolean {
  return sti === '/' || OFFENTLIGE_PREFIX.some((r) => sti.startsWith(r))
}

/**
 * Navnet på hodet som bærer URL-en inn til layouten.
 *
 * HVORFOR DETTE MÅ TIL: en layout i App Router får ikke `searchParams`.
 * Appskallet kunne derfor ikke vite at siden under det sto på
 * `?butikknummer=4177`, og viste sitt eget huskede valg i stedet - to
 * stasjonskontekster på samme skjerm. Proxyen ser URL-en uansett, og
 * sender den videre som et forespørselshode.
 *
 * Bare stien og spørrestrengen. Ingen tolkning her: proxyen kjenner
 * verken parameternavn eller stasjoner, og skal ikke gjøre det.
 */
export const URL_HODE = 'x-sentiqa-url'

// Fornyer Supabase-sesjonen og setter oppdaterte auth-cookies på responsen.
// Kjøres fra proxy.ts (Next 16s "middleware"). Gjør KUN en optimistisk
// sjekk — den ekte autorisasjonen skjer i DAL + RLS nær datakilden (§3).
export async function oppdaterSesjon(request: NextRequest) {
  const hoder = new Headers(request.headers)
  hoder.set(URL_HODE, request.nextUrl.pathname + request.nextUrl.search)

  let response = NextResponse.next({ request: { headers: hoder } })

  const supabase = createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet, headers) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value)
          }
          // Kapslene må også følge med i de VIDERESENDTE hodene, ellers
          // mister den nye responsen den ferske auth-kapselen.
          hoder.set('cookie', request.cookies.toString())
          response = NextResponse.next({ request: { headers: hoder } })
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options)
          }
          // Auth-responser må aldri caches av CDN/proxy (ssr 0.10.x).
          for (const [nøkkel, verdi] of Object.entries(headers ?? {})) {
            response.headers.set(nøkkel, verdi)
          }
        },
      },
    },
  )

  // VIKTIG: getUser() (verifisert mot Auth-server) må kalles før responsen
  // genereres, ellers går en fersk token-fornying tapt. Er Supabase
  // utilgjengelig (pauset prosjekt/nettverk) behandler vi det som uinnlogget,
  // slik at offentlige sider (logg-inn) ALLTID laster og hele siden ikke faller.
  let user = null
  try {
    const res = await supabase.auth.getUser()
    user = res.data.user
  } catch {
    user = null
  }

  const sti = request.nextUrl.pathname
  const erOffentlig = erOffentligSti(sti)

  // Uinnlogget på beskyttet rute → til innlogging.
  if (!user && !erOffentlig) {
    const url = request.nextUrl.clone()
    url.pathname = '/logg-inn'
    url.searchParams.set('retur', sti)
    return NextResponse.redirect(url)
  }

  // Innlogget som besøker selve innloggingssiden → til oversikten. Eksakt
  // match: steg-opp-siden (/logg-inn/totp) krever en aal1-sesjon og må IKKE
  // bounces bort, ellers kommer brukeren aldri til engangskode-steget.
  if (user && sti === '/logg-inn') {
    const url = request.nextUrl.clone()
    url.pathname = '/oversikt'
    url.search = ''
    return NextResponse.redirect(url)
  }

  return response
}
