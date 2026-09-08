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

  // PROFILEN FOERST, UENDRET. Denne spoerringen er inngangen til hele
  // systemet, og den skal ikke ha flere maater aa feile paa enn den
  // hadde. Foerste utgave hentet kjeden i samme spoerring med en
  // innbakt `retailers(godkjent_tid)` - og en embed som ikke loeser seg
  // gir `null` her, hvilket ser ut som «ingen profil» og sender ALLE til
  // /ingen-tilgang. Det er en dyr feil aa gjoere paa det ene stedet all
  // autorisasjon gaar gjennom.
  const { data: profil } = await supabase
    .from('profiler')
    .select('rolle, retailer_id, fullt_navn')
    .eq('id', user.id)
    .is('slettet_tid', null)
    .single()

  if (!profil) redirect('/ingen-tilgang')

  // ---------------------------------------------------------------
  // VENTER PAA GODKJENNING (0190)
  // ---------------------------------------------------------------
  // En selvregistrert kjede finnes fra sekundet skjemaet gaar, men naar
  // ingenting foer et menneske har sagt ja. Sjekken maa ligge HER og
  // ikke i `(beskyttet)/layout.tsx` - en rute utenfor det treet som
  // kaller `hentInnloggetBruker` ville ellers vaert en vei rundt, og
  // `/sikkerhet` er nettopp en slik rute.
  //
  // Plattformredaktoeren staar utenfor: hun har ingen kjede aa vente
  // paa, og det er hun som godkjenner.
  //
  // FEILER AAPENT, OG DET ER MED VILJE. Tenantisolasjonen er RLS og
  // holder uansett; godkjenningen er en forretningsport. Klarer vi ikke
  // aa lese den, er svaret aa slippe gjennom framfor aa stenge ute hver
  // eneste kunde paa en forbigaaende lesefeil. Bare et tydelig `null`
  // stopper noen - og det betyr at raden faktisk sier «ikke godkjent».
  if (profil.rolle !== 'plattform_redaktor' && profil.retailer_id) {
    const { data: kjede, error } = await supabase
      .from('retailers')
      .select('godkjent_tid')
      .eq('id', profil.retailer_id)
      .maybeSingle<{ godkjent_tid: string | null }>()
    if (!error && kjede && kjede.godkjent_tid === null) {
      redirect('/venter-paa-godkjenning')
    }
  }

  return {
    id: user.id,
    rolle: profil.rolle,
    retailerId: profil.retailer_id,
    fulltNavn: profil.fullt_navn,
    epost: user.email ?? null,
  }
})
