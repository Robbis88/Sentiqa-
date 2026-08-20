import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { env } from '@/lib/env'
import { stasjonFraUrl, STASJONSKAPSEL, type Stasjon } from '@/lib/stasjonsvalg'

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

  // URL-EN SKRIVER DET HUSKEDE VALGET - og gjør det HER.
  //
  // Første utgave gjorde dette fra en useEffect i toppstripen, fordi en
  // serverkomponent ikke kan sette informasjonskapsler under render. Det
  // ga et kappløp: handlingen ble sendt fra siden man var i ferd med å
  // forlate, og svaret kunne treffe etter at neste side hadde lastet.
  // Testen fanget det som «5102 ble til 5101» - én gang, ikke hver gang,
  // som kappløp pleier.
  //
  // Proxyen har ingen slik tvetydighet. Den ser URL-en før noe rendres,
  // og kapselen den setter gjelder fra neste forespørsel.
  //
  // BARE NÅR VERDIEN ER GYLDIG. Oppslaget går gjennom brukerens egen
  // sesjon, så RLS avgjør hva som finnes: en lenke til en annen kjedes
  // stasjon gir ingen treff, og da skrives ingenting. En dårlig lenke
  // skal ikke kunne flytte brukeren, og aller minst uten at hun ser det.
  //
  // Spørringen kjøres kun når parameteren faktisk står der. `stasjoner`
  // er en liten tabell med indeks på id; dette er ikke datahenting i
  // proxyen, det er en oppslagsvalidering av noe brukeren nettopp ba om.
  if (user) {
    const sok = request.nextUrl.searchParams
    if (sok.has('stasjon') || sok.has('butikknummer')) {
      const { data } = await supabase
        .from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null)
      const valg = stasjonFraUrl(sok, (data ?? []) as Stasjon[])
      if (valg) {
        response.cookies.set(STASJONSKAPSEL, valg, {
          path: '/', sameSite: 'lax', httpOnly: true, maxAge: 60 * 60 * 24 * 365,
        })
      }
    }
  }

  return response
}
