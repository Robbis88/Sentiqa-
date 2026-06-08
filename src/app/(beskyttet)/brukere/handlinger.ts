'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'

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
    await admin.auth.admin.deleteUser(brukerId)
    return { feil: 'Kunne ikke opprette profil.' }
  }

  await admin.from('butikksjef_stasjoner').insert(stasjonIds.map((sid) => ({ profil_id: brukerId, stasjon_id: sid })))
  revalidatePath('/brukere')
  return { ok: true }
}

export async function fjernBruker(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return
  const id = String(formData.get('id') ?? '')
  if (!id || id === bruker.id) return // ikke fjern deg selv
  const admin = lagSupabaseAdminKlient()
  // Bekreft at brukeren tilhører egen tenant før sletting.
  const { data } = await admin.from('profiler').select('retailer_id').eq('id', id).maybeSingle<{ retailer_id: string }>()
  if (data?.retailer_id !== bruker.retailerId) return
  await admin.auth.admin.deleteUser(id) // cascade fjerner profil + tilganger
  revalidatePath('/brukere')
}
