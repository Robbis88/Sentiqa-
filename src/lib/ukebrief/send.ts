import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { Resend } from 'resend'
import { env } from '@/lib/env'
import { hentUkedata } from './hent'
import { byggUkebrief } from './bygg'
import { tilEpost } from './epost'

// =====================================================================
// Utsendingen.
//
// Tre ting maa staa, og de er alle tre av samme grunn: en jobb som
// sender e-post til virkelige mennesker faar ikke prove seg fram.
//
//   DUPLIKATSPERRE  `ukebrief_utsending` har en partiell unik indeks paa
//                   (stasjon, uke, profil) `where status = 'sendt'`.
//                   Jobben leser den FOER den sender, og skriver til den
//                   ETTER. Kraesjer den midt i, kan den kjoeres om igjen
//                   uten at noen faar brevet to ganger.
//   RETRY           Et feilet forsoek logges som `feilet` og sperrer
//                   ingenting. Neste kjoering forsoeker det paa nytt.
//   FEILER LUKKET   Mangler `RESEND_API_KEY`, kastes det. En stille
//                   no-op ville sett ut som «ingen hadde bruk for et brev
//                   denne uken», og det er den verste av alle utganger:
//                   den ser vellykket ut.
//
// TOERRKJOERING er ikke en bryter for de forsiktige — den er hvordan man
// ser hvem som ville faatt hva, uten aa sende. Den skriver ingenting.
// =====================================================================

type Klient = SupabaseClient

export type Mottaker = { profilId: string; epost: string; navn: string | null }

export type Stasjonsresultat = {
  stasjonId: string
  navn: string
  /** null = ingen salgsdata for uken; da sendes ingenting. */
  harBrief: boolean
  mottakere: number
  sendt: number
  /** Allerede sendt tidligere. Ikke en feil — det er sperren som virker. */
  hoppet: number
  feilet: number
  meldinger: string[]
}

/**
 * Hvem skal ha brevet for denne stasjonen.
 *
 * Adressen finnes bare i `auth.users` og hentes med admin-klienten, én
 * profil om gangen. Det er flere kall enn `listUsers()`, men det er ogsaa
 * det eneste som ikke drar hele brukertabellen inn i minnet for aa finne
 * to adresser.
 */
export async function finnMottakere(admin: Klient, stasjonId: string): Promise<Mottaker[]> {
  const { data: tilganger, error } = await admin
    .from('butikksjef_stasjoner')
    .select('profil_id, profiler!inner(id, fullt_navn, rolle, slettet_tid)')
    .eq('stasjon_id', stasjonId)
    .overrideTypes<{ profil_id: string; profiler: { fullt_navn: string | null; rolle: string; slettet_tid: string | null } }[]>()
  if (error) throw new Error(`kunne ikke lese mottakere: ${error.message}`)

  const ut: Mottaker[] = []
  for (const t of tilganger ?? []) {
    if (t.profiler.rolle !== 'butikksjef') continue
    if (t.profiler.slettet_tid !== null) continue
    const { data } = await admin.auth.admin.getUserById(t.profil_id)
    const epost = data?.user?.email
    // En profil uten adresse hoppes over, men den TELLES ikke som sendt.
    // Hadde vi bare filtrert den bort i stillhet, ville en butikksjef som
    // aldri fikk brevet sett ut som en som ikke skulle ha det.
    if (!epost) continue
    ut.push({ profilId: t.profil_id, epost, navn: t.profiler.fullt_navn })
  }
  return ut
}

async function alleredeSendt(
  admin: Klient, stasjonId: string, ukeMandag: string,
): Promise<Set<string>> {
  const { data, error } = await admin
    .from('ukebrief_utsending')
    .select('profil_id')
    .eq('stasjon_id', stasjonId).eq('uke_mandag', ukeMandag).eq('status', 'sendt')
    .overrideTypes<{ profil_id: string }[]>()
  // Kan vi ikke lese loggen, VET vi ikke hvem som har faatt brevet. Da er
  // det eneste trygge aa la vaere aa sende — ikke aa sende til alle.
  if (error) throw new Error(`kunne ikke lese utsendingsloggen: ${error.message}`)
  return new Set((data ?? []).map((r) => r.profil_id))
}

/**
 * Én prøve til én adresse — den innloggedes egen.
 *
 * Bevisst en ANNEN vei enn utsendingen: den logger ingenting, leser ikke
 * duplikatsperren, og tar aldri en mottakerliste. En knapp som gikk
 * gjennom `sendUkebriefForRetailer` kunne truffet en butikksjef ved en
 * feil i ett argument, og det er ikke en feil man vil kunne gjoere.
 *
 * Klienten er den RLS-scopede serverklienten, ikke admin: er stasjonen
 * ikke din, finnes det ingen data aa bygge et brev av.
 */
export async function sendProve(opts: {
  klient: Klient
  stasjon: { id: string; butikknummer: string; navn: string }
  ukeMandag: string
  basisUrl: string
  til: string
}): Promise<{ ok: true } | { ok: false; feil: string }> {
  if (!env.RESEND_API_KEY) return { ok: false, feil: 'RESEND_API_KEY mangler i miljøet.' }

  const data = await hentUkedata(opts.klient, opts.stasjon, opts.ukeMandag)
  if (data === null) return { ok: false, feil: 'Ingen salgsdata for uken — det finnes ikke noe brev å sende.' }

  const epost = tilEpost(byggUkebrief(data), opts.basisUrl)
  const resend = new Resend(env.RESEND_API_KEY)
  try {
    const svar = await resend.emails.send({
      from: env.UKEBRIEF_AVSENDER,
      to: opts.til,
      // Emnet merkes, saa en proeve aldri kan forveksles med det ekte
      // brevet — verken i innboksen eller i et skjermbilde av den.
      subject: `[Prøve] ${epost.emne}`,
      html: epost.html,
      text: epost.tekst,
    })
    if (svar.error) return { ok: false, feil: svar.error.message }
    return { ok: true }
  } catch (e) {
    return { ok: false, feil: e instanceof Error ? e.message : String(e) }
  }
}

export async function sendUkebriefForRetailer(opts: {
  admin: Klient
  retailerId: string
  ukeMandag: string
  basisUrl: string
  torrkjor?: boolean
  /** Overstyrer mottakerne. Brukes av «send til meg selv»-knappen, som
      aldri skal kunne treffe en butikksjef ved et uhell. */
  kunTil?: Mottaker
}): Promise<Stasjonsresultat[]> {
  const { admin, retailerId, ukeMandag, basisUrl, torrkjor = false, kunTil } = opts

  if (!torrkjor && !env.RESEND_API_KEY) {
    throw new Error('RESEND_API_KEY mangler — ingenting ble sendt.')
  }
  const resend = env.RESEND_API_KEY ? new Resend(env.RESEND_API_KEY) : null

  const { data: stasjoner, error: stasjonsfeil } = await admin
    .from('stasjoner')
    .select('id, butikknummer, navn')
    .eq('retailer_id', retailerId).is('slettet_tid', null).order('butikknummer')
    .overrideTypes<{ id: string; butikknummer: string; navn: string }[]>()
  if (stasjonsfeil) throw new Error(`kunne ikke lese stasjoner: ${stasjonsfeil.message}`)

  const ut: Stasjonsresultat[] = []

  for (const stasjon of stasjoner ?? []) {
    const rad: Stasjonsresultat = {
      stasjonId: stasjon.id, navn: `${stasjon.butikknummer} ${stasjon.navn}`,
      harBrief: false, mottakere: 0, sendt: 0, hoppet: 0, feilet: 0, meldinger: [],
    }

    const data = await hentUkedata(admin, stasjon, ukeMandag)
    if (data === null) {
      rad.meldinger.push('Ingen salgsdata for uken — ingenting sendt.')
      ut.push(rad)
      continue
    }
    rad.harBrief = true

    const brief = byggUkebrief(data)
    const epost = tilEpost(brief, basisUrl)

    const mottakere = kunTil ? [kunTil] : await finnMottakere(admin, stasjon.id)
    rad.mottakere = mottakere.length
    if (mottakere.length === 0) {
      rad.meldinger.push('Ingen butikksjef med e-postadresse er knyttet til stasjonen.')
      ut.push(rad)
      continue
    }

    // «Send til meg selv» skal kunne gjentas. Den logges ikke og leser
    // ikke sperren — den er en prove, ikke en utsending.
    const sendtFor = kunTil ? new Set<string>() : await alleredeSendt(admin, stasjon.id, ukeMandag)

    for (const m of mottakere) {
      if (sendtFor.has(m.profilId)) { rad.hoppet++; continue }
      if (torrkjor) { rad.meldinger.push(`Ville sendt til ${m.epost}`); continue }

      let eksternId: string | null = null
      let feil: string | null = null
      try {
        const svar = await resend!.emails.send({
          from: env.UKEBRIEF_AVSENDER,
          to: m.epost,
          subject: epost.emne,
          html: epost.html,
          text: epost.tekst,
        })
        // Resend kaster ikke paa avvist e-post — den svarer med `error`.
        // Uten denne linja ville hver avvisning blitt logget som «sendt».
        if (svar.error) feil = svar.error.message
        else eksternId = svar.data?.id ?? null
      } catch (e) {
        feil = e instanceof Error ? e.message : String(e)
      }

      if (feil) { rad.feilet++; rad.meldinger.push(`${m.epost}: ${feil}`) } else rad.sendt++

      if (!kunTil) {
        // Logges FOER neste mottaker, ikke samlet til slutt. Kraesjer
        // prosessen midt i, skal det som faktisk gikk ut staa i basen.
        const { error } = await admin.from('ukebrief_utsending').insert({
          retailer_id: retailerId, stasjon_id: stasjon.id, uke_mandag: ukeMandag,
          profil_id: m.profilId, status: feil ? 'feilet' : 'sendt',
          ekstern_id: eksternId, feil,
        })
        if (error) rad.meldinger.push(`Kunne ikke logge sending til ${m.epost}: ${error.message}`)
      }
    }
    ut.push(rad)
  }
  return ut
}
