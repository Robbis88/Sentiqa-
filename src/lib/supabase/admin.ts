import 'server-only'
import { createClient } from '@supabase/supabase-js'
import { env } from '@/lib/env'

// Service-role-klient — OMGÅR RLS. ALDRI eksponert i klient.
//
// TO LOVLIGE BRUK, OG DE HANDLER IKKE OM ROLLE:
//
//   1. System-prosesser uten brukersesjon — e-post-webhook, nattjobber.
//
//   2. En identitet SERVEREN har bevist, men RLS ikke kan se. Nettbrettets
//      vakt er den ene: `checkInn` setter en signert kapsel og etterlater
//      ingen rad, så databasen har ingen måte å vite hvem som står der.
//      `lesAktivAnsatt` beviser den med signatur OG oppslag gjennom
//      nettbrettets egen RLS. Se `personvern/bekreftelse.ts`.
//
// DET ER IKKE EN PLATTFORM-NØKKEL. De to sidene som brukte den før var
// begge låst til `plattform_redaktor`, og det kunne lest som en regel.
// Det er det ikke: redaktøren styrer plattformen og skal ikke rydde for
// 150 butikker. Kjedens egen admin og butikksjefen per stasjon må kunne
// ordne sitt eget — den grensen settes av RLS, ikke av denne filen.
//
// KRAVET ER SMALHET, IKKE RANG: én kjent rad, de kolonnene som trengs, og
// et filter serveren selv har utledet. Kommer id-en fra forespørselen, er
// dette feil verktøy.
export function lagSupabaseAdminKlient() {
  if (!env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Mangler SUPABASE_SERVICE_ROLE_KEY')
  }
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}
