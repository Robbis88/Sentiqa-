import type { NextRequest } from 'next/server'
import { oppdaterSesjon } from '@/lib/supabase/proxy'

// Next.js 16: "Middleware" heter nå Proxy. Én fil per prosjekt, på nivå med app/.
export async function proxy(request: NextRequest) {
  return oppdaterSesjon(request)
}

export const config = {
  // Kjør på alt unntatt API-ruter (egne webhooks), statiske filer og bilder.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|manifest.webmanifest|sw.js|.*\\.(?:svg|png|jpg|jpeg|gif|webp|mp4|webm|mov|ogg|m4v)$).*)'],
}
