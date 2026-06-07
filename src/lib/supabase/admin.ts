import 'server-only'
import { createClient } from '@supabase/supabase-js'
import { env } from '@/lib/env'

// Service-role-klient — OMGÅR RLS. Kun for system-prosesser uten brukersesjon
// (e-post-webhook, bakgrunnsarbeidere). ALDRI eksponert i klient.
export function lagSupabaseAdminKlient() {
  if (!env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Mangler SUPABASE_SERVICE_ROLE_KEY')
  }
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}
