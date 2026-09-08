import 'server-only'
import { cache } from 'react'
import { redirect } from 'next/navigation'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'

// Data Access Layer (Next.js auth-guide): all autorisasjon går gjennom ett
// sted. cache() memoiserer per render-pass så vi ikke spør gjentatte ganger.
// getUser() er verifisert mot Auth-serveren — getSession() er det IKKE.

export const verifiserSesjon = cache(async () => {
  const supabase = await lagSupabaseServerKlient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) redirect('/logg-inn')
  return user
})

// Henter innlogget bruker med profil (rolle + tenant). RLS sørger for at
// brukeren kun kan lese sin egen profilrad. Mangler profil → ingen tilgang.
export const hentInnloggetBruker = cache(async (): Promise<InnloggetBruker> => {
  const user = await verifiserSesjon()
  const supabase = await lagSupabaseServerKlient()

  // KJEDEN HENTES I SAMME SPOERRING, ikke i en til.
  //
  // Godkjenningen (0190) maa sjekkes ved HVER inngang, ikke bare i
  // `(beskyttet)/layout.tsx` - en rute utenfor det treet som kaller
  // `hentInnloggetBruker` ville ellers vaert en vei rundt porten.
  // Derfor ligger den her, i det ene stedet all autorisasjon gaar
  // gjennom. Innbakt embed koster ingen ekstra rundtur.
  const { data: profil } = await supabase
    .from('profiler')
    .select('rolle, retailer_id, fullt_navn, retailers(godkjent_tid)')
    .eq('id', user.id)
    .is('slettet_tid', null)
    .single<{
      rolle: InnloggetBruker['rolle']
      retailer_id: string | null
      fullt_navn: string | null
      retailers: { godkjent_tid: string | null } | null
    }>()

  if (!profil) redirect('/ingen-tilgang')

  // VENTER PAA GODKJENNING.
  //
  // En selvregistrert kjede finnes fra sekundet skjemaet gaar, men naar
  // ingenting foer et menneske har sagt ja. Plattformredaktoeren staar
  // utenfor: hun har ingen kjede aa vente paa, og det er hun som
  // godkjenner.
  //
  // Rekkefoelgen er med vilje: e-posten er alt bekreftet naar en soeker
  // kommer hit, for hun kom inn gjennom invitasjonslenken. Vi godkjenner
  // en verifisert adresse, ikke en paastand.
  if (profil.rolle !== 'plattform_redaktor' && profil.retailers?.godkjent_tid == null) {
    redirect('/venter-paa-godkjenning')
  }

  return {
    id: user.id,
    rolle: profil.rolle,
    retailerId: profil.retailer_id,
    fulltNavn: profil.fullt_navn,
    epost: user.email ?? null,
  }
})
