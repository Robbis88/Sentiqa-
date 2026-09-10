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
  passord_gjenta: z.string(),
  rolle: z.enum(['butikksjef', 'butikkbruker_tablet']),
}).refine((d) => d.passord === d.passord_gjenta, {
  // =================================================================
  // EN SKRIVEFEIL HER LAGER EN BRUKER INGEN KAN LOGGE INN SOM
  //
  // Feltet sto alene, som `type="password"`. Traff du feil tast, ble
  // kontoen opprettet med et passord ingen kjenner — verken den som
  // skrev det eller den som skulle bruke det. Det ser ut som en
  // vellykket handling helt til noen prøver å logge inn, og da er det
  // ingenting som peker tilbake hit.
  //
  // SJEKKEN LIGGER PÅ SERVEREN, ikke bare i skjemaet. Et
  // `required`-attributt er en visning; det er dette som er grensen.
  // Samme regel som resten av systemet: et flagg i en kolonne er ikke
  // en grense før noe under visningen leser det.
  // =================================================================
  error: 'Passordene er ikke like.',
  path: ['passord_gjenta'],
})

export type BrukerTilstand = { ok?: true; feil?: string } | undefined

export async function opprettBruker(_t: BrukerTilstand, formData: FormData): Promise<BrukerTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return { feil: 'Kun eier kan opprette brukere.' }
  const felt = Ny.safeParse({
    navn: formData.get('navn'),
    epost: formData.get('epost'),
    passord: formData.get('passord'),
    passord_gjenta: formData.get('passord_gjenta') ?? '',
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

const NyttPassord = z.object({
  passord: z.string().min(8, { error: 'Passord må være minst 8 tegn.' }),
  passord_gjenta: z.string(),
}).refine((d) => d.passord === d.passord_gjenta, {
  // SAMME GRUNN SOM VED OPPRETTELSE (#247). En skrivefeil i et skjult
  // felt gir en konto ingen kommer inn på — og her er det verre, for
  // brukeren HADDE et passord som virket til vi tok det fra henne.
  error: 'Passordene er ikke like.',
  path: ['passord_gjenta'],
})

/**
 * Setter et nytt passord for en butikksjef eller en tablet-konto.
 *
 * HVORFOR DENNE FINNES VED SIDEN AV «GLEMT PASSORD?».
 * E-postlenken på innloggingssiden dekker den som har en postkasse hun
 * leser. To tilfeller faller utenfor:
 *
 *   TABLET-KONTOEN er delt på stasjonen, og adressen den er opprettet
 *   med er ofte ikke en postkasse noen åpner. En lenke dit forsvinner.
 *
 *   E-POST SOM IKKE KOMMER FRAM. Supabase Auth sender gjennom sin egen
 *   SMTP, ikke gjennom Resend. Er den ikke satt opp, ser alt riktig ut
 *   og ingenting skjer. Da må det finnes en vei som ikke går om e-post
 *   i det hele tatt — ellers er eneste utvei å slette brukeren og lage
 *   henne på nytt, som er nøyaktig det `endreStasjoner` ble skrevet for
 *   å slippe.
 *
 * FORRIGE PASSORD KREVES IKKE, og det er med vilje: eieren kan det
 * ikke. Det er derfor handlingen er eierens alene og bare når egen
 * kjede — grensen ligger i hvem som får trykke, ikke i hva hun vet.
 */
export async function settNyttPassord(
  _t: Kvittering, formData: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare kjedeadministrator kan sette nytt passord.' }
  }

  const profilId = String(formData.get('profil_id') ?? '')
  if (!profilId) return { feil: 'Mangler bruker.' }

  const felt = NyttPassord.safeParse({
    passord: formData.get('passord'),
    passord_gjenta: formData.get('passord_gjenta') ?? '',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return { feil: 'Passordbytte er ikke aktivert (mangler service-nøkkel).' }
  }

  // ADMIN-KLIENTEN OMGÅR RLS, så tenanten må sjekkes her. Rollen sjekkes
  // også: lista viser bare butikksjefer og tablet-kontoer, men en id i
  // et skjult felt er ikke en grense — den er en visning.
  const { data: profil } = await admin
    .from('profiler').select('id, fullt_navn, rolle')
    .eq('id', profilId).eq('retailer_id', bruker.retailerId).is('slettet_tid', null)
    .maybeSingle<{ id: string; fullt_navn: string | null; rolle: string }>()
  if (!profil) return { feil: 'Fant ikke brukeren i din kjede.' }
  if (profil.rolle !== 'butikksjef' && profil.rolle !== 'butikkbruker_tablet') {
    return { feil: 'Passordet til denne brukeren kan ikke settes herfra.' }
  }

  const { error } = await admin.auth.admin.updateUserById(
    profilId, { password: felt.data.passord },
  )
  if (error) return { feil: `Kunne ikke sette passordet: ${error.message}` }

  return { ok: `Nytt passord satt for ${profil.fullt_navn ?? 'brukeren'}. Gi det videre selv — det vises ikke igjen.` }
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
