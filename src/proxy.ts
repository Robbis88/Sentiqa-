import type { NextRequest } from 'next/server'
import { oppdaterSesjon } from '@/lib/supabase/proxy'

// Next.js 16: "Middleware" heter nå Proxy. Én fil per prosjekt, på nivå med app/.
export async function proxy(request: NextRequest) {
  return oppdaterSesjon(request)
}

export const config = {
  // Kjør på alt unntatt statiske filer og bilder. Auth bør dekke alle ruter.
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
