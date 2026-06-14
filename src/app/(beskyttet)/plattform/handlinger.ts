'use server'
import { headers } from 'next/headers'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

async function erEier(): Promise<boolean> {
  const bruker = await hentInnloggetBruker()
  return bruker.rolle === 'plattform_redaktor'
}

const Skjema = z.object({
  firma: z.string().min(2, { error: 'Skriv inn firmanavn.' }),
  org_nr: z.string().regex(/^\d{9}$/, { error: 'Organisasjonsnummer må være 9 siffer.' }),
  fullt_navn: z.string().min(1, { error: 'Skriv inn navnet på admin-kontakten.' }),
  epost: z.email({ error: 'Skriv inn en gyldig e-post.' }),
})

export type KundeTilstand = { feil?: string; ok?: string } | undefined

function slugify(s: string): string {
  return s.toLowerCase().replace(/æ/g, 'ae').replace(/ø/g, 'o').replace(/å/g, 'a')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'kjede'
}

// Plattform-eier oppretter en ny kjede og inviterer admin-kontakten på e-post.
// Supabase sender invitasjonen via SMTP-en du har koblet i Auth-innstillingene.
export async function opprettKunde(_t: KundeTilstand, formData: FormData): Promise<KundeTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return { feil: 'Kun plattform-eier kan opprette kunder.' }

  const felt = Skjema.safeParse({ firma: formData.get('firma'), org_nr: formData.get('org_nr'), fullt_navn: formData.get('fullt_navn'), epost: formData.get('epost') })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const { firma, org_nr, fullt_navn, epost } = felt.data

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Mangler service-nøkkel — kan ikke opprette kunde.' }
  }

  // Unik slug (også innboks-adresse for e-postinntak).
  let slug = slugify(firma)
  for (let i = 0; i < 25; i++) {
    const { data } = await admin.from('retailers').select('id').eq('slug', slug).maybeSingle()
    if (!data) break
    slug = `${slugify(firma)}-${i + 2}`
  }

  // 1. Kjede.
  const { data: retailer, error: re } = await admin.from('retailers')
    .insert({ navn: firma, org_nr, slug, inntak_epost: `${slug}@sentiqa.ai` }).select('id').single()
  if (re || !retailer) return { feil: 'Kunne ikke opprette kjeden.' }

  // 2. Inviter admin-kontakten (Supabase sender e-post med lenke til /auth/bekreft → sett passord).
  const h = await headers()
  const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`
  const { data: inv, error: ie } = await admin.auth.admin.inviteUserByEmail(epost, { redirectTo: `${origin}/auth/bekreft` })
  if (ie || !inv?.user) {
    await admin.from('retailers').delete().eq('id', retailer.id)
    return { feil: /already|registered|exist/i.test(ie?.message ?? '') ? 'E-posten er allerede i bruk.' : 'Kunne ikke sende invitasjon (er SMTP koblet i Supabase?).' }
  }

  // 3. Admin-profil knyttet til den inviterte brukeren.
  const { error: pe } = await admin.from('profiler')
    .insert({ id: inv.user.id, retailer_id: retailer.id, rolle: 'retailer_admin', fullt_navn })
  if (pe) {
    await admin.auth.admin.deleteUser(inv.user.id)
    await admin.from('retailers').delete().eq('id', retailer.id)
    return { feil: 'Kunne ikke fullføre opprettelsen.' }
  }

  revalidatePath('/plattform')
  return { ok: `${firma} opprettet. Invitasjon sendt til ${epost}.` }
}

// Send påloggingslenke på nytt (kunden fikk aldri / mistet invitasjonen).
// Bruker recovery-e-post → samme /auth/bekreft → /sett-passord-flyt.
export async function sendInvitasjonPaaNytt(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const epost = String(formData.get('epost') ?? '').trim()
  if (!epost) return
  const h = await headers()
  const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`
  const supabase = await lagSupabaseServerKlient()
  await supabase.auth.resetPasswordForEmail(epost, { redirectTo: `${origin}/auth/bekreft` })
  revalidatePath('/plattform')
}

// Deaktiver (mykt, reversibelt): sperr innlogging for kjedens brukere + skjul kjeden.
export async function deaktiverKunde(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  const { data: profiler } = await admin.from('profiler').select('id').eq('retailer_id', id)
  for (const p of (profiler ?? []) as { id: string }[]) {
    await admin.auth.admin.updateUserById(p.id, { ban_duration: '876000h' }) // ~100 år = sperret
  }
  await admin.from('retailers').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/plattform')
}

// Reaktiver: opphev sperringen + vis kjeden igjen.
export async function reaktiverKunde(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  const { data: profiler } = await admin.from('profiler').select('id').eq('retailer_id', id)
  for (const p of (profiler ?? []) as { id: string }[]) {
    await admin.auth.admin.updateUserById(p.id, { ban_duration: 'none' })
  }
  await admin.from('retailers').update({ slettet_tid: null }).eq('id', id)
  revalidatePath('/plattform')
}

// Slett permanent (GDPR): all data + auth-brukere for godt. Uopprettelig.
export async function slettKundePermanent(formData: FormData): Promise<void> {
  if (!(await erEier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  let admin
  try { admin = lagSupabaseAdminKlient() } catch { return }
  const { data: profiler } = await admin.from('profiler').select('id').eq('retailer_id', id)
  const brukerIder = (profiler ?? []).map((p: { id: string }) => p.id)
  const { error } = await admin.rpc('slett_retailer_permanent', { p_retailer: id })
  if (error) return
  for (const uid of brukerIder) await admin.auth.admin.deleteUser(uid)
  revalidatePath('/plattform')
}
