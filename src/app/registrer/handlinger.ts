'use server'
import { redirect } from 'next/navigation'
import * as z from 'zod'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { loggHendelse } from '@/lib/kontrollrom'
import { DPA_VERSJON } from '@/lib/juss'
import { taalerAaFeile } from '@/lib/skriv-svar'

const Skjema = z.object({
  firma: z.string().min(2, { error: 'Skriv inn firmanavn.' }),
  org_nr: z.string().regex(/^\d{9}$/, { error: 'Organisasjonsnummer må være 9 siffer.' }),
  fullt_navn: z.string().min(1, { error: 'Skriv inn navnet ditt.' }),
  epost: z.email({ error: 'Skriv inn en gyldig e-post.' }),
  passord: z.string().min(8, { error: 'Passordet må være minst 8 tegn.' }),
  dpa: z.literal(true, { error: 'Du må godta databehandleravtalen og personvernerklæringen for å opprette konto.' }),
})

export type RegTilstand = { feil?: string } | undefined

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/æ/g, 'ae').replace(/ø/g, 'o').replace(/å/g, 'a')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'kjede'
}

export async function registrer(_t: RegTilstand, formData: FormData): Promise<RegTilstand> {
  const felt = Skjema.safeParse({
    firma: formData.get('firma'),
    org_nr: formData.get('org_nr'),
    fullt_navn: formData.get('fullt_navn'),
    epost: formData.get('epost'),
    passord: formData.get('passord'),
    dpa: formData.get('dpa') === 'ja',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const { firma, org_nr, fullt_navn, epost, passord } = felt.data

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Registrering er ikke aktivert (mangler service-nøkkel).' }
  }

  // 1. Opprett auth-bruker (auto-bekreftet for selvbetjent oppstart).
  const opprettet = await admin.auth.admin.createUser({ email: epost, password: passord, email_confirm: true })
  if (opprettet.error || !opprettet.data.user) {
    return { feil: /already|registered|exist/i.test(opprettet.error?.message ?? '') ? 'E-posten er allerede registrert.' : 'Kunne ikke opprette konto.' }
  }
  const brukerId = opprettet.data.user.id

  // 2. Unik slug fra firmanavn (brukes også til innboks-adresse).
  let slug = slugify(firma)
  for (let i = 0; i < 25; i++) {
    const { data } = await admin.from('retailers').select('id').eq('slug', slug).maybeSingle()
    if (!data) break
    slug = `${slugify(firma)}-${i + 2}`
  }

  // 3. Opprett tenant (org.nr lagres for EHF-fakturering). DPA-aksepten
  //    fra registreringsskjemaet stemples på raden (versjon + tid + hvem).
  const { data: retailer, error: re } = await admin
    .from('retailers')
    .insert({
      navn: firma, org_nr, slug, inntak_epost: `${slug}@sentiqa.ai`,
      dpa_akseptert_tid: new Date().toISOString(), dpa_versjon: DPA_VERSJON, dpa_akseptert_av: fullt_navn,
    })
    .select('id')
    .single()
  if (re || !retailer) {
    await admin.auth.admin.deleteUser(brukerId)
    return { feil: 'Kunne ikke opprette kjede.' }
  }

  // 4. Admin-profil for eieren.
  const { error: pe } = await admin
    .from('profiler')
    .insert({ id: brukerId, retailer_id: retailer.id, rolle: 'retailer_admin', fullt_navn })
  if (pe) {
    taalerAaFeile(await admin.from('retailers').delete().eq('id', retailer.id),
      'rydder bort kjeden vi nettopp opprettet')
    await admin.auth.admin.deleteUser(brukerId)
    return { feil: 'Kunne ikke fullføre registreringen.' }
  }

  await loggHendelse({
    type: 'onboarding',
    alvorlighet: 'info',
    tittel: `Ny kjede registrert: ${firma}`,
    detaljer: { firma, org_nr, slug, epost, dpa_versjon: DPA_VERSJON },
    bruker_ref: fullt_navn,
  })

  // 5. Logg inn (setter sesjon-cookie) og videre til onboarding.
  const supabase = await lagSupabaseServerKlient()
  await supabase.auth.signInWithPassword({ email: epost, password: passord })
  redirect('/stasjoner')
}
