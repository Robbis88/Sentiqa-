'use server'
import { headers } from 'next/headers'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kvitter, type Kvittering } from '@/lib/kvittering'
import { taalerAaFeile } from '@/lib/skriv-svar'

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
    taalerAaFeile(await admin.from('retailers').delete().eq('id', retailer.id),
      'rydder bort kjeden vi nettopp opprettet')
    return { feil: /already|registered|exist/i.test(ie?.message ?? '') ? 'E-posten er allerede i bruk.' : 'Kunne ikke sende invitasjon (er SMTP koblet i Supabase?).' }
  }

  // 3. Admin-profil knyttet til den inviterte brukeren.
  const { error: pe } = await admin.from('profiler')
    .insert({ id: inv.user.id, retailer_id: retailer.id, rolle: 'retailer_admin', fullt_navn })
  if (pe) {
    taalerAaFeile(await admin.auth.admin.deleteUser(inv.user.id),
      'rydder bort den inviterte brukeren')
    taalerAaFeile(await admin.from('retailers').delete().eq('id', retailer.id),
      'rydder bort kjeden vi nettopp opprettet')
    return { feil: 'Kunne ikke fullføre opprettelsen.' }
  }

  return { ok: `${firma} opprettet. Invitasjon sendt til ${epost}.` }
}

// Send påloggingslenke på nytt (kunden fikk aldri / mistet invitasjonen).
// Bruker recovery-e-post → samme /auth/bekreft → /sett-passord-flyt.
export async function sendInvitasjonPaaNytt(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  if (!(await erEier())) return { feil: 'Bare eier kan gjøre dette.' }
  const epost = String(fd.get('epost') ?? '').trim()
  if (!epost) return { feil: 'Mangler e-postadresse.' }
  const h = await headers()
  const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`

  // SMTP ER DEN VANLIGE AARSAKEN, og den er usynlig herfra. Uten svar
  // sto eieren og ventet paa en e-post som aldri ble sendt.
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.auth.resetPasswordForEmail(
    epost, { redirectTo: `${origin}/auth/bekreft` },
  )
  if (error) return { feil: `Kunne ikke sende: ${error.message}` }

  return { ok: `Lenke sendt til ${epost}` }
}

// HELE PLATTFORM-KONSOLLEN SVARER. Fire handlinger som endrer en hel
// kjedes tilgang sto stille: `try { admin = ... } catch { return }` ga
// nøyaktig samme bilde som et vellykket klikk. Er tjenestenøkkelen ikke
// satt i miljøet — som den ikke er lokalt — skjedde det ingenting, og
// ingenting sa fra.
async function eierOgAdmin(): Promise<
  { admin: ReturnType<typeof lagSupabaseAdminKlient> } | { feil: string }
> {
  if (!(await erEier())) return { feil: 'Bare eier kan gjøre dette.' }
  try {
    return { admin: lagSupabaseAdminKlient() }
  } catch {
    return { feil: 'Tjenestenøkkelen mangler i miljøet.' }
  }
}

/** Sperrer eller åpner innlogging for alle brukerne i kjeden. */
async function settSperre(
  admin: ReturnType<typeof lagSupabaseAdminKlient>, id: string, sperr: boolean,
): Promise<string | null> {
  const { data: profiler, error } = await admin.from('profiler').select('id').eq('retailer_id', id)
  if (error) return `Fant ikke brukerne: ${error.message}`
  for (const p of (profiler ?? []) as { id: string }[]) {
    // ~100 aar = sperret.
    const { error: ue } = await admin.auth.admin.updateUserById(
      p.id, { ban_duration: sperr ? '876000h' : 'none' },
    )
    // ÉN BRUKER SOM IKKE LOT SEG SPERRE ER HELE POENGET MED HANDLINGEN.
    // Fortsetter vi i stillhet, staar kjeden som deaktivert mens noen
    // fortsatt kommer inn.
    if (ue) return `Klarte ikke sperre alle brukerne: ${ue.message}`
  }
  return null
}

// Deaktiver (mykt, reversibelt): sperr innlogging for kjedens brukere + skjul kjeden.
export async function deaktiverKunde(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const k = await eierOgAdmin()
  if ('feil' in k) return k
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }

  const sperrefeil = await settSperre(k.admin, id, true)
  if (sperrefeil) return { feil: sperrefeil }

  return kvitter(
    k.admin.from('retailers')
      .update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id),
    { hva: 'deaktivere kjeden', ok: 'Kjeden er deaktivert', oppfrisk: ['/plattform'] },
  )
}

// Reaktiver: opphev sperringen + vis kjeden igjen.
export async function reaktiverKunde(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const k = await eierOgAdmin()
  if ('feil' in k) return k
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }

  const sperrefeil = await settSperre(k.admin, id, false)
  if (sperrefeil) return { feil: sperrefeil }

  return kvitter(
    k.admin.from('retailers').update({ slettet_tid: null }, { count: 'exact' }).eq('id', id),
    { hva: 'reaktivere kjeden', ok: 'Kjeden er tilbake', oppfrisk: ['/plattform'] },
  )
}

// Slett permanent (GDPR): all data + auth-brukere for godt. Uopprettelig.
export async function slettKundePermanent(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const k = await eierOgAdmin()
  if ('feil' in k) return k
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }

  const { data: profiler, error: pe } = await k.admin.from('profiler').select('id').eq('retailer_id', id)
  if (pe) return { feil: `Fant ikke brukerne: ${pe.message}` }
  const brukerIder = (profiler ?? []).map((p: { id: string }) => p.id)

  const { error } = await k.admin.rpc('slett_retailer_permanent', { p_retailer: id })
  if (error) return { feil: `Kunne ikke slette kjeden: ${error.message}` }

  // DATAENE ER BORTE ALLEREDE. Feiler en auth-bruker her, er kjeden
  // likevel slettet - da er det riktige aa si hvor mange som ble igjen,
  // ikke aa kaste og late som ingenting skjedde.
  const etterlatte: string[] = []
  for (const uid of brukerIder) {
    const { error: de } = await k.admin.auth.admin.deleteUser(uid)
    if (de) etterlatte.push(uid)
  }

  return etterlatte.length
    ? {
      feil: `Kjeden og dataene er slettet, men ${etterlatte.length} `
        + 'innlogging(er) ble stående igjen. Fjern dem i Supabase.',
    }
    : { ok: 'Kjeden og alle data er slettet' }
}
