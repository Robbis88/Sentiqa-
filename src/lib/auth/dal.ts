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

  const { data: profil } = await supabase
    .from('profiler')
    .select('rolle, retailer_id, fullt_navn')
    .eq('id', user.id)
    .is('slettet_tid', null)
    .single()

  if (!profil) redirect('/ingen-tilgang')

  return {
    id: user.id,
    rolle: profil.rolle,
    retailerId: profil.retailer_id,
    fulltNavn: profil.fullt_navn,
    epost: user.email ?? null,
  }
})
