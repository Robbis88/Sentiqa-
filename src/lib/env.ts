import 'server-only'
import * as z from 'zod'

// Validerer miljøvariabler ved oppstart — feiler tydelig hvis noe mangler,
// i stedet for kryptiske runtime-feil senere. Service-role-nøkkelen er
// server-only og skal ALDRI eksponeres i klient (§3, §15).
const skjema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  // Kun server-side (bakgrunnsarbeidere/admin). Valgfri inntil de bygges, så
  // et manglende secret aldri velter app-bygget. ALDRI eksponert i klient.
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).optional(),
})

const resultat = skjema.safeParse(process.env)
if (!resultat.success) {
  throw new Error(
    'Ugyldige/manglende miljøvariabler i .env.local:\n' +
      z.prettifyError(resultat.error),
  )
}

export const env = resultat.data
