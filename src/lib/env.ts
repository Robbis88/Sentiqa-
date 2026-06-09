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
  // Anthropic Claude (AI-assistenten, §8). Valgfri til den er lagt inn; uten
  // den svarer assistenten at nøkkelen mangler i stedet for å velte bygget.
  ANTHROPIC_API_KEY: z.string().min(1).optional(),
  // Delt hemmelighet som e-post-webhooken (§6) må sende i x-inntak-secret.
  EPOST_INNTAK_SECRET: z.string().min(1).optional(),
  // Fiken-fakturering (§4). Token + selskap + bankkonto fra Fiken-kontoen din.
  FIKEN_API_TOKEN: z.string().min(1).optional(),
  FIKEN_COMPANY_SLUG: z.string().min(1).optional(),
  FIKEN_BANK_ACCOUNT_CODE: z.string().min(1).optional(), // f.eks. "1920:10001"
  FIKEN_INCOME_ACCOUNT: z.string().min(1).optional(), // salgskonto, default "3000"
  FIKEN_VAT_TYPE: z.string().min(1).optional(), // "HIGH" (25 % mva) | "NONE" m.fl.
  FAKTURA_SECRET: z.string().min(1).optional(), // beskytter /api/faktura
  // Web-push (varsler til mobil/nettleser). Public-nøkkel eksponeres i klient.
  NEXT_PUBLIC_VAPID_PUBLIC_KEY: z.string().min(1).optional(),
  VAPID_PRIVATE_KEY: z.string().min(1).optional(),
  VAPID_SUBJECT: z.string().min(1).optional(), // mailto:… kontakt
  // Vercel Cron sender denne i Authorization-headeren ved nattjobber.
  CRON_SECRET: z.string().min(1).optional(),
})

const resultat = skjema.safeParse(process.env)
if (!resultat.success) {
  throw new Error(
    'Ugyldige/manglende miljøvariabler i .env.local:\n' +
      z.prettifyError(resultat.error),
  )
}

export const env = resultat.data
