'use server'
import { createHmac } from 'node:crypto'
import { headers } from 'next/headers'
import * as z from 'zod'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { loggHendelse } from '@/lib/kontrollrom'
import { DPA_VERSJON } from '@/lib/juss'
import { taalerAaFeile } from '@/lib/skriv-svar'
import { env } from '@/lib/env'

// =====================================================================
// SELVBETJENT REGISTRERING, MEN MED PORT
//
// Denne var helt åpen. Hvem som helst kunne opprette en kjede med seg
// selv som `retailer_admin`, og den var live i samme sekund.
// Isolasjonen holdt — RLS gir dem bare sin egen tomme kjede — så det
// var aldri en lekkasje. Det var fire åpninger, og tre av dem lukkes
// her.
//
// ---------------------------------------------------------------------
// 1. E-POSTEN BLIR NÅ FAKTISK VERIFISERT
//
// Før: `createUser({ email_confirm: true })` — som markerer adressen
// som bekreftet UTEN å sende noe. Man kunne registrere seg på en
// adresse man ikke eier, og da går «glemt passord» til den ekte
// eieren, med en lenke inn i en konto de aldri opprettet.
//
// Nå: `inviteUserByEmail`, samme vei `/plattform` har brukt hele tiden.
// Supabase sender lenken, `/auth/bekreft` løser den inn, og
// `/sett-passord` tar passordet. **Passordfeltet er derfor borte fra
// skjemaet** — det er ikke en forenkling, det er hele beviset: du eier
// adressen fordi du fikk brevet.
//
// Å bygge en egen bekreftelse med eget token ville krevd en e-postsender
// systemet ikke har. Å late som med `email_confirm: true` var nettopp
// problemet.
//
// ---------------------------------------------------------------------
// 2. KJEDEN ER IKKE LIVE FØR NOEN HAR SETT DEN
//
// `retailers.godkjent_tid` er null til en plattformredaktør sier ja
// (`0190`). DAL-en sender dem til `/venter-paa-godkjenning` så lenge
// den er det. Rekkefølgen er med vilje: adressen er bekreftet FØR vi
// godkjenner, så vi godkjenner en verifisert e-post og ikke en påstand.
//
// ---------------------------------------------------------------------
// 3. EN GRENSE PER KILDE
//
// Registreringen går gjennom service_role og forbi Supabase sine egne
// auth-grenser. Uten en teller kan noen lage ubegrenset antall kjeder,
// og hver av dem tar en `@sentiqa.ai`-adresse.
//
// Organisasjonsnummeret er unikt fra `0190` — den fjerde åpningen — og
// håndheves av databasen, ikke her. En sjekk i koden ville hatt et
// kappløp mellom to samtidige skjemaer; en indeks har det ikke.
// =====================================================================

const Skjema = z.object({
  firma: z.string().min(2, { error: 'Skriv inn firmanavn.' }),
  org_nr: z.string().regex(/^\d{9}$/, { error: 'Organisasjonsnummer må være 9 siffer.' }),
  fullt_navn: z.string().min(1, { error: 'Skriv inn navnet ditt.' }),
  epost: z.email({ error: 'Skriv inn en gyldig e-post.' }),
  dpa: z.literal(true, { error: 'Du må godta databehandleravtalen og personvernerklæringen for å opprette konto.' }),
})

export type RegTilstand = { feil?: string; ok?: string } | undefined

/** Hvor mange forsøk én kilde får per time. */
const GRENSE = 3
const VINDU_MIN = 60

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/æ/g, 'ae').replace(/ø/g, 'o').replace(/å/g, 'a')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'kjede'
}

/**
 * Hvem som spør, som en ugjenkallelig streng.
 *
 * INGEN RÅ IP I BASEN. Tabellen skal kunne svare «har denne kilden
 * prøvd tre ganger den siste timen», ikke «hvem prøvde». En logg over
 * hvilke adresser folk har forsøkt å registrere er personopplysninger vi
 * ikke trenger for å telle.
 *
 * HMAC og ikke ren `sha256`: en IPv4-adresse har fire milliarder
 * verdier, og en usaltet hash av den er oppslagbar på en ettermiddag.
 * Nøkkelen er service-nøkkelen, som allerede må finnes for at
 * registrering skal virke i det hele tatt — så det er ingen ny
 * hemmelighet å glemme å sette.
 */
async function kildehash(): Promise<string> {
  const h = await headers()
  const ip = (h.get('x-forwarded-for') ?? '').split(',')[0].trim()
    || h.get('x-real-ip')
    || 'ukjent'
  return createHmac('sha256', env.SUPABASE_SERVICE_ROLE_KEY ?? 'ingen').update(ip).digest('hex')
}

export async function registrer(_t: RegTilstand, formData: FormData): Promise<RegTilstand> {
  const felt = Skjema.safeParse({
    firma: formData.get('firma'),
    org_nr: formData.get('org_nr'),
    fullt_navn: formData.get('fullt_navn'),
    epost: formData.get('epost'),
    dpa: formData.get('dpa') === 'ja',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const { firma, org_nr, fullt_navn, epost } = felt.data

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Registrering er ikke aktivert (mangler service-nøkkel).' }
  }

  // 0. Grensen. Telles FØR noe opprettes, og forsøket føres uansett
  //    utfall — ellers ville en angriper med feil org.nr fått uendelig
  //    mange gratis forsøk.
  const kilde = await kildehash()
  const siden = new Date(Date.now() - VINDU_MIN * 60_000).toISOString()
  const { count } = await admin
    .from('registrering_forsok')
    .select('id', { count: 'exact', head: true })
    .eq('kilde_hash', kilde)
    .gte('tid', siden)
  if ((count ?? 0) >= GRENSE) {
    return {
      feil: 'For mange registreringsforsøk fra denne maskinen. Prøv igjen om en time, '
        + 'eller ta kontakt så oppretter vi kjeden for deg.',
    }
  }
  // GRENSEN FEILER LUKKET. Klarer vi ikke å telle forsøket, kan vi ikke
  // begrense det heller — og da er en åpen dør verre enn en registrering
  // som må prøves igjen. Samme valg som `VAKT_SIGNATUR_SECRET`.
  const { error: fe } = await admin.from('registrering_forsok').insert({ kilde_hash: kilde })
  if (fe) return { feil: 'Kunne ikke behandle registreringen nå. Prøv igjen om litt.' }

  // 1. Unik slug fra firmanavn (brukes også til innboks-adresse).
  let slug = slugify(firma)
  for (let i = 0; i < 25; i++) {
    const { data } = await admin.from('retailers').select('id').eq('slug', slug).maybeSingle()
    if (!data) break
    slug = `${slugify(firma)}-${i + 2}`
  }

  // 2. Kjeden. `godkjent_tid` står null — den er ikke live ennå.
  //    DPA-aksepten fra skjemaet stemples på raden (versjon + tid + hvem).
  const { data: retailer, error: re } = await admin
    .from('retailers')
    .insert({
      navn: firma, org_nr, slug, inntak_epost: `${slug}@sentiqa.ai`,
      dpa_akseptert_tid: new Date().toISOString(), dpa_versjon: DPA_VERSJON, dpa_akseptert_av: fullt_navn,
    })
    .select('id')
    .single()
  if (re || !retailer) {
    // DEN UNIKE INDEKSEN SKAL SI HVA DEN ER. «Kunne ikke opprette
    // kjede» på et org.nr som allerede finnes, sender folk på leting
    // etter en feil som ikke er deres.
    return {
      feil: /duplicate|unique/i.test(re?.message ?? '')
        ? 'Organisasjonsnummeret er allerede registrert. Ta kontakt hvis du '
          + 'skulle hatt tilgang til den kjeden.'
        : 'Kunne ikke opprette kjede.',
    }
  }

  // 3. Invitasjonen. Det er den som beviser at adressen er ekte.
  const h = await headers()
  const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`
  const { data: inv, error: ie } = await admin.auth.admin
    .inviteUserByEmail(epost, { redirectTo: `${origin}/auth/bekreft` })
  if (ie || !inv?.user) {
    taalerAaFeile(await admin.from('retailers').delete().eq('id', retailer.id),
      'rydder bort kjeden vi nettopp opprettet')
    return {
      feil: /already|registered|exist/i.test(ie?.message ?? '')
        ? 'E-posten er allerede registrert. Prøv å logge inn i stedet.'
        : 'Kunne ikke sende bekreftelsen på e-post. Prøv igjen om litt.',
    }
  }

  // 4. Admin-profil for eieren, knyttet til den inviterte brukeren.
  const { error: pe } = await admin
    .from('profiler')
    .insert({ id: inv.user.id, retailer_id: retailer.id, rolle: 'retailer_admin', fullt_navn })
  if (pe) {
    taalerAaFeile(await admin.auth.admin.deleteUser(inv.user.id),
      'rydder bort den inviterte brukeren')
    taalerAaFeile(await admin.from('retailers').delete().eq('id', retailer.id),
      'rydder bort kjeden vi nettopp opprettet')
    return { feil: 'Kunne ikke fullføre registreringen.' }
  }

  await loggHendelse({
    type: 'onboarding',
    alvorlighet: 'info',
    tittel: `Ny kjede venter på godkjenning: ${firma}`,
    detaljer: { firma, org_nr, slug, epost, dpa_versjon: DPA_VERSJON },
    bruker_ref: fullt_navn,
  })

  // 5. INGEN AUTOMATISK INNLOGGING. Vi har ikke sett et passord, og vi
  //    vet ennå ikke om adressen er ekte — det er nettopp brevet som
  //    avgjør det. Svaret sier hva som skjer nå.
  return {
    ok: `Vi har sendt en bekreftelse til ${epost}. Åpne lenken der for å sette `
      + 'passord. Kjeden åpnes når vi har sett over registreringen.',
  }
}
