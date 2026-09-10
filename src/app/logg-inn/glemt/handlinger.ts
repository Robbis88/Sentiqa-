'use server'
import { headers } from 'next/headers'
import * as z from 'zod'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const Skjema = z.object({
  epost: z.email({ error: 'Skriv inn en gyldig e-postadresse.' }),
})

export type GlemtTilstand = { ok?: string; feil?: string } | undefined

/**
 * Sender en lenke som lar brukeren velge nytt passord selv.
 *
 * SAMME MEKANISME SOM PLATTFORMKONSOLLEN ALLEREDE BRUKER — `sendInvitasjonPaaNytt`
 * i /plattform har sendt recovery-e-post siden den ble skrevet, og den lander
 * i `/auth/bekreft` → `/sett-passord`. Det som manglet var at noen andre enn
 * plattformeieren kunne utløse den. Fram til nå måtte en butikksjef som hadde
 * glemt passordet sitt ringe eieren, som måtte ringe meg.
 *
 * SVARET ER LIKT UANSETT OM E-POSTEN FINNES. En side som sier «vi kjenner
 * ikke den adressen» er et oppslagsverk over hvem som har konto hos oss,
 * åpent for hvem som helst. Innloggingen selv er allerede bevisst generisk
 * («Feil e-post eller passord»); dette er samme regel.
 *
 * MEN «SENDT» ER IKKE «KOM FRAM», og det skal teksten være ærlig om.
 * Supabase Auth sender disse gjennom SIN egen SMTP — ikke gjennom Resend,
 * som ukebriefen bruker. Er ikke egen SMTP satt opp i prosjektet, sender
 * standardoppsettet noen få e-poster i timen og bare til prosjektets
 * teammedlemmer. Da er alt her grønt og ingenting kommer fram. Kvitteringen
 * sier derfor hva som skal skje og hva man gjør når det ikke skjer.
 */
export async function sendGlemtLenke(
  _t: GlemtTilstand, formData: FormData,
): Promise<GlemtTilstand> {
  const felt = Skjema.safeParse({ epost: formData.get('epost') })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const h = await headers()
  const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.auth.resetPasswordForEmail(
    felt.data.epost, { redirectTo: `${origin}/auth/bekreft` },
  )

  // EN AVVISNING HER ER IKKE «FINNES IKKE». Supabase svarer med feil på
  // ratebegrensning og på oppsettsfeil, ikke på ukjent adresse — så en
  // feil er noe brukeren skal få vite om, uten at den avslører noe.
  if (error) {
    return {
      feil: 'Klarte ikke sende akkurat nå. Har du bedt om en lenke nylig, '
        + 'vent noen minutter og prøv igjen.',
    }
  }

  return {
    ok: `Er ${felt.data.epost} registrert hos oss, ligger det en lenke i innboksen `
      + 'om et minutt eller to. Sjekk søppelpost. Kommer det ingenting, '
      + 'kan eieren av kjeden sette et nytt passord for deg under Brukere.',
  }
}
