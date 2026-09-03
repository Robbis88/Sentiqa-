'use server'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import type { Kvittering } from '@/lib/kvittering'
import { taalerAaFeile } from '@/lib/skriv-svar'

const Ny = z.object({
  navn: z.string().min(1, { error: 'Skriv inn navn.' }),
  epost: z.email({ error: 'Ugyldig e-post.' }),
  passord: z.string().min(8, { error: 'Passord må være minst 8 tegn.' }),
  rolle: z.enum(['butikksjef', 'butikkbruker_tablet']),
})

export type BrukerTilstand = { ok?: true; feil?: string } | undefined

export async function opprettBruker(_t: BrukerTilstand, formData: FormData): Promise<BrukerTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { feil: 'Kun eier kan opprette brukere.' }
  const felt = Ny.safeParse({
    navn: formData.get('navn'),
    epost: formData.get('epost'),
    passord: formData.get('passord'),
    rolle: formData.get('rolle'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const { navn, epost, passord, rolle } = felt.data
  const valgteStasjoner = formData.getAll('stasjon_ids').map(String).filter(Boolean)
  if (valgteStasjoner.length === 0) return { feil: 'Velg minst én stasjon.' }

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Brukeropprettelse er ikke aktivert (mangler service-nøkkel).' }
  }

  // Sikre at stasjonene tilhører eierens egen tenant (admin-klient omgår RLS).
  const { data: egne } = await admin
    .from('stasjoner')
    .select('id')
    .eq('retailer_id', bruker.retailerId)
    .is('slettet_tid', null)
    .in('id', valgteStasjoner)
  const stasjonIds = (egne ?? []).map((s: { id: string }) => s.id)
  if (stasjonIds.length === 0) return { feil: 'Ugyldige stasjoner.' }

  const opprettet = await admin.auth.admin.createUser({ email: epost, password: passord, email_confirm: true })
  if (opprettet.error || !opprettet.data.user) {
    return { feil: /already|registered|exist/i.test(opprettet.error?.message ?? '') ? 'E-posten er allerede i bruk.' : 'Kunne ikke opprette bruker.' }
  }
  const brukerId = opprettet.data.user.id

  const { error: pe } = await admin.from('profiler').insert({
    id: brukerId,
    retailer_id: bruker.retailerId,
    fullt_navn: navn,
    rolle,
  })
  if (pe) {
    taalerAaFeile(await admin.auth.admin.deleteUser(brukerId),
      'rydder bort innloggingen vi nettopp opprettet')
    return { feil: 'Kunne ikke opprette profil.' }
  }

  // EN BUTIKKSJEF UTEN STASJONER SER UT SOM EN VANLIG BRUKER. Feiler
  // denne, er kontoen opprettet men uten noe aa styre - og det er
  // ikke til aa skille fra en riktig opprettet konto.
  const { error: se } = await admin.from('butikksjef_stasjoner')
    .insert(stasjonIds.map((sid) => ({ profil_id: brukerId, stasjon_id: sid })))
  if (se) return { feil: `Brukeren er opprettet, men stasjonene ble ikke koblet: ${se.message}` }
  return { ok: true }
}

/**
 * Endrer hvilke stasjoner en butikksjef naar.
 *
 * Fantes ikke foer 2026-09-03: sida hadde bare opprett og fjern, saa en
 * feilkoblet butikksjef maatte slettes og lages paa nytt - med nytt
 * passord, og med all historikk paa profilen borte.
 *
 * REKKEFOELGEN ER IKKE TILFELDIG. Det fjernes foerst, legges til etterpaa.
 * PostgREST gir ingen transaksjon, saa en av de to kan feile alene. Feiler
 * fjerningen, har vi ikke lagt til noe enda og ingen har faatt mer enn
 * hun skulle. Feiler tilleggene, har hun mistet noe hun skulle hatt - og
 * det oppdages med en gang, av henne. For lite tilgang roper; for mye
 * tilgang er stille, og det er den stille feilen som er farlig.
 */
export async function endreStasjoner(_t: BrukerTilstand, formData: FormData): Promise<BrukerTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { feil: 'Kun eier kan endre tilganger.' }

  const profilId = String(formData.get('profil_id') ?? '')
  if (!profilId) return { feil: 'Mangler bruker.' }
  const valgte = [...new Set(formData.getAll('stasjon_ids').map(String).filter(Boolean))]
  // EN BUTIKKSJEF UTEN STASJONER SER UT SOM EN VANLIG BRUKER - hun logger
  // inn, alt er tomt, og ingenting sier hvorfor. Samme grunn som ved
  // opprettelse: null stasjoner er ikke en tilstand noen mener.
  if (valgte.length === 0) return { feil: 'Velg minst én stasjon. Skal hun ikke ha tilgang, fjern brukeren.' }

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Tilgangsstyring er ikke aktivert (mangler service-nøkkel).' }
  }

  // Admin-klienten omgaar RLS, saa BEGGE sider maa sjekkes mot egen kjede:
  // hvem profilen tilhoerer, og hvilke stasjoner som er vaare.
  const { data: profil } = await admin
    .from('profiler').select('id, rolle').eq('id', profilId)
    .eq('retailer_id', bruker.retailerId).is('slettet_tid', null)
    .maybeSingle<{ id: string; rolle: string }>()
  if (!profil) return { feil: 'Fant ikke brukeren i din kjede.' }

  const { data: egne } = await admin
    .from('stasjoner').select('id')
    .eq('retailer_id', bruker.retailerId).is('slettet_tid', null).in('id', valgte)
    .overrideTypes<{ id: string }[]>()
  const gyldige = (egne ?? []).map((s) => s.id)
  if (gyldige.length !== valgte.length) return { feil: 'Én eller flere stasjoner hører ikke til din kjede.' }

  const { error: fjernFeil } = await admin
    .from('butikksjef_stasjoner').delete()
    .eq('profil_id', profilId).not('stasjon_id', 'in', `(${gyldige.join(',')})`)
  if (fjernFeil) return { feil: `Kunne ikke fjerne gamle tilganger: ${fjernFeil.message}` }

  const { error: leggTilFeil } = await admin
    .from('butikksjef_stasjoner')
    .upsert(gyldige.map((sid) => ({ profil_id: profilId, stasjon_id: sid })),
      { onConflict: 'profil_id,stasjon_id', ignoreDuplicates: true })
  if (leggTilFeil) return { feil: `Tilganger ble fjernet, men ikke lagt til: ${leggTilFeil.message}` }

  return { ok: true }
}

// SLETTER ET MENNESKE, IKKE EN RAD. Derfor gaar den via admin-klienten
// og `auth.admin.deleteUser` - cascade fjerner profil og tilganger. Den
// kan ikke gaa gjennom `kvitter`, som snakker PostgREST.
//
// HVERT AVSLAG HAR SIN EGEN TEKST. «Ikke tilgang» paa alle fire ville
// vaert usant paa tre av dem: aa forsoeke aa fjerne seg selv er ikke et
// tilgangsproblem, og en bruker i en annen kjede er noe helt annet enn
// en som ikke finnes. Foer sa alle fire ingenting i det hele tatt.
export async function fjernBruker(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare kjedeadministrator kan fjerne brukere.' }
  }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  if (id === bruker.id) return { feil: 'Du kan ikke fjerne deg selv.' }

  const admin = lagSupabaseAdminKlient()
  // Bekreft at brukeren tilhoerer egen tenant foer sletting.
  const { data } = await admin.from('profiler').select('retailer_id').eq('id', id).maybeSingle<{ retailer_id: string }>()
  if (!data) return { feil: 'Fant ikke brukeren.' }
  if (data.retailer_id !== bruker.retailerId) {
    return { feil: 'Brukeren hoerer til en annen kjede.' }
  }

  const { error } = await admin.auth.admin.deleteUser(id)
  if (error) return { feil: `Kunne ikke fjerne brukeren: ${error.message}` }

  return { ok: 'Brukeren er fjernet' }
}
