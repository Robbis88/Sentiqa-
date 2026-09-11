'use server'
import { headers } from 'next/headers'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kvitter, type Kvittering } from '@/lib/kvittering'
import { taalerAaFeile } from '@/lib/skriv-svar'
import { krevStotte, apneStotte, lukkStotte, MAKS_TIMER } from '@/lib/stotte'
import { loggHendelse } from '@/lib/kontrollrom'

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

  // BEVISST UTENFOR STOETTEPORTEN, og det er verdt aa skrive ned hvorfor.
  // Aa sende en gjenopprettingslenke er funksjonelt en vei inn i kundens
  // konto - men handlingen finnes nettopp for kunden som IKKE kommer inn,
  // ofte foer det finnes data i kjeden i det hele tatt. Et stoettevindu
  // som maa aapnes foerst ville laast den flyten den ble laget for.
  //
  // Den skal likevel ikke vaere usporet. Kontrollrommet faar linja.
  await loggHendelse({
    type: 'support',
    alvorlighet: 'warning',
    tittel: 'Plattform sendte gjenopprettingslenke',
    detaljer: { epost, av: (await hentInnloggetBruker()).id },
  })

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

/**
 * Slipper en selvregistrert kjede inn.
 *
 * =====================================================================
 * PORTEN ER ET MENNESKE, IKKE ET SKJEMA
 * =====================================================================
 * `/registrer` er selvbetjent, og skal være det — men en kjede som er
 * live i det sekundet et skjema går, er en kjede ingen har sett på.
 * `0190` gir dem `godkjent_tid = null`, og DAL-en sender dem til
 * `/venter-paa-godkjenning` til den er satt.
 *
 * Når du klikker her, er e-postadressen allerede bevist: søkeren kom
 * inn gjennom invitasjonslenken. Du godkjenner en verifisert adresse,
 * ikke en påstand.
 *
 * VAKTET, SÅ EN ANDRE GANG IKKE FLYTTER TIDSPUNKTET. `godkjent_tid` er
 * når kjeden ble sluppet inn, og det skjedde bare én gang.
 */
export async function godkjennKunde(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const k = await eierOgAdmin()
  if ('feil' in k) return k
  const id = String(fd.get('id') ?? '').trim()
  if (!id) return { feil: 'Mangler kjede-id.' }

  const bruker = await hentInnloggetBruker()
  const { data, error } = await k.admin
    .from('retailers')
    .update({ godkjent_tid: new Date().toISOString(), godkjent_av: bruker.id })
    .eq('id', id)
    .is('godkjent_tid', null)
    .select('navn')
    .maybeSingle<{ navn: string }>()
  if (error) return { feil: `Kunne ikke godkjenne: ${error.message}` }
  // INGEN RAD ER IKKE INGEN FEIL. Enten er kjeden alt godkjent, eller
  // id-en finnes ikke - og «godkjent!» på begge ville vært en løgn.
  if (!data) return { feil: 'Kjeden er allerede godkjent, eller finnes ikke.' }

  // INGEN `revalidatePath` HER. En serverhandling som frisker opp sin
  // egen rute gjoer kvitteringen til gissel for ruteroppdateringen -
  // `useKvittering` i `HandlingKnapp` tar visningen. Se
  // `skrivevakt`-vakten og `sentiqa-flaky-stempling-e2e`.
  return { ok: `${data.navn} er godkjent og har tilgang.` }
}

// Deaktiver (mykt, reversibelt): sperr innlogging for kjedens brukere + skjul kjeden.
export async function deaktiverKunde(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  // PORTEN. Aa sperre innloggingen for en hel kjede er ikke en handling
  // som skal kunne gjoeres uten at det staar hvorfor. Se lib/stotte.ts.
  const k = await krevStotte(id, 'deaktiver_kjede')
  if (!k.ok) return { feil: k.feil }

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
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const k = await krevStotte(id, 'reaktiver_kjede')
  if (!k.ok) return { feil: k.feil }

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
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  // Den mest uopprettelige handlingen i systemet. Den skal aldri kunne
  // ha skjedd uten at det staar hvem, naar og hvorfor.
  const k = await krevStotte(id, 'slett_kjede_permanent')
  if (!k.ok) return { feil: k.feil }

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

// =====================================================================
// STOETTEVINDUET
//
// Den som skal roere en levende kjede, aapner et vindu foerst - med en
// begrunnelse kunden faar se, og en varighet basen selv begrenser (0196).
// Handlingene over nekter aa kjoere uten.
// =====================================================================
export async function apneStottevindu(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const id = String(fd.get('id') ?? '')
  const grunn = String(fd.get('begrunnelse') ?? '')
  const timer = Number(fd.get('timer') ?? 1)
  if (!id) return { feil: 'Mangler kjede.' }

  const svar = await apneStotte(id, grunn, timer)
  if (!svar.ok) return { feil: svar.feil }

  // Kontrollrommet faar den ogsaa. En aapning som bare finnes i kundens
  // egen logg, er en aapning ingen hos oss ser.
  await loggHendelse({
    type: 'support',
    alvorlighet: 'warning',
    tittel: 'Stoettetilgang aapnet',
    detaljer: { retailer_id: id, timer, begrunnelse: grunn.trim().slice(0, 300) },
  })

  // INGEN revalidatePath paa egen rute: `useKvittering` frisker opp
  // ruteren selv ETTER at kvitteringen er vist. Kalles den herfra, blir
  // oppdateringen en del av overgangen, og knappen staar «Aapner ...»
  // paa noe som alt er lagret.
  return { ok: `Stoettetilgang aapen i ${Math.min(Math.max(Math.round(timer) || 1, 1), MAKS_TIMER)} time(r).` }
}

export async function lukkStottevindu(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const tilgangId = String(fd.get('tilgang_id') ?? '')
  if (!tilgangId) return { feil: 'Mangler tilgang.' }
  const svar = await lukkStotte(tilgangId)
  if (!svar.ok) return { feil: svar.feil }
  return { ok: 'Stoettetilgangen er lukket.' }
}
