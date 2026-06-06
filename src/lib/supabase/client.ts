'use client'
import { createBrowserClient } from '@supabase/ssr'

// Supabase-klient for Client Components. Kun NEXT_PUBLIC-variabler (inlines
// av Next i bundelen). Også her gjelder RLS — anon-nøkkelen gir ingen tilgang
// utover det policyene tillater for den innloggede brukeren.
export function lagSupabaseNettleserKlient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )
}
