import 'server-only'
import { cookies } from 'next/headers'
import { createServerClient } from '@supabase/ssr'
import { env } from '@/lib/env'

// Supabase-klient for Server Components, Server Actions og Route Handlers.
// Kjører som innlogget bruker (anon-nøkkel + brukerens cookie-sesjon) →
// RLS gjelder fullt ut. Bruk ALDRI service-role her.
export async function lagSupabaseServerKlient() {
  const cookieStore = await cookies()

  return createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          // I rene Server Components er cookie-skriving ikke tillatt; da fornyer
          // proxy.ts sesjonen i stedet. Derfor svelger vi feilen her.
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options)
            }
          } catch {
            // Ignoreres med vilje — håndteres av proxy-laget.
          }
        },
      },
    },
  )
}
