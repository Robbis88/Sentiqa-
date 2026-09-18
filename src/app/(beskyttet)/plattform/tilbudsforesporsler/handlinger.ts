'use server'
import { revalidatePath } from 'next/cache'
import { headers } from 'next/headers'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { beregnAvtaledatoer } from '@/lib/avtale-dato'

async function eier() { return (await hentInnloggetBruker()).rolle === 'plattform_redaktor' }

export async function endreForesporsel(formData: FormData): Promise<void> {
  if (!(await eier())) return
  const id = String(formData.get('id') ?? '')
  const status = String(formData.get('status') ?? '')
  const tillatt = ['ny', 'kontaktet', 'tilbud_klargjoeres', 'tilbud_sendt', 'akseptert', 'avslatt', 'utloopt']
  if (!id || !tillatt.includes(status)) return
  const admin = lagSupabaseAdminKlient()
  const { data: gammel } = await admin.from('tilbudsforesporsler').select('status').eq('id', id).limit(1).maybeSingle<{ status: string }>()
  const { error } = await admin.from('tilbudsforesporsler').update({ status, oppdatert_tid: new Date().toISOString() }).eq('id', id)
  if (error) return
  const bruker = await hentInnloggetBruker()
  await admin.from('tilbudsforesporsel_revisjon').insert({ foresporsel_id: id, utfort_av: bruker.id, handling: 'status', endringer: { fra: gammel?.status ?? null, til: status } })
  revalidatePath('/plattform/tilbudsforesporsler')
}

export async function opprettTilbud(formData: FormData): Promise<void> {
  if (!(await eier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const admin = lagSupabaseAdminKlient()
  const { data: eksisterende } = await admin.from('tilbud').select('id').eq('foresporsel_id', id).limit(1).maybeSingle()
  if (!eksisterende) {
    const start = String(formData.get('trial_starts_at') ?? '').trim() || null
    const datoer = start ? beregnAvtaledatoer(start) : {}
    const { error } = await admin.from('tilbud').insert({ foresporsel_id: id, retailer_limit: Number(formData.get('retailer_limit') ?? 1), butikksjef_limit: Number(formData.get('butikksjef_limit') ?? 0), tablet_station_limit: Number(formData.get('tablet_station_limit') ?? 0), trial_maaneder: 2, binding_maaneder: 12, maanedspris_kr: Number(formData.get('maanedspris_kr') || 0), oppstartsgebyr_kr: Number(formData.get('oppstartsgebyr_kr') || 0), ...datoer })
    if (error) return
    const bruker = await hentInnloggetBruker()
    const { data: nytt } = await admin.from('tilbud').select('id').eq('foresporsel_id', id).limit(1).maybeSingle<{ id: string }>()
    if (nytt) await admin.from('avtale_revisjon').insert({ tilbud_id: nytt.id, utfort_av: bruker.id, handling: 'tilbud_opprettet', endringer: { trial_maaneder: 2, binding_maaneder: 12 } })
  }
  revalidatePath('/plattform/tilbudsforesporsler')
}

export async function registrerAksept(formData: FormData): Promise<void> {
  if (!(await eier())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const admin = lagSupabaseAdminKlient()
  const bruker = await hentInnloggetBruker()
  const { error } = await admin.from('tilbud').update({ status: 'akseptert', accepted_at: new Date().toISOString(), accepted_by: String(formData.get('accepted_by') ?? '').trim() || null, acceptance_reference: String(formData.get('acceptance_reference') ?? '').trim() || null, oppdatert_tid: new Date().toISOString() }).eq('id', id)
  if (error) return
  await admin.from('avtale_revisjon').insert({ tilbud_id: id, utfort_av: bruker.id, handling: 'aksept', endringer: { accepted_by: String(formData.get('accepted_by') ?? '') } })
  revalidatePath('/plattform/tilbudsforesporsler')
}

function slug(s: string) { return s.toLowerCase().replace(/æ/g, 'ae').replace(/ø/g, 'o').replace(/å/g, 'a').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'kunde' }

export async function opprettKundeFraTilbud(formData: FormData): Promise<void> {
  if (!(await eier())) return
  const tilbudId = String(formData.get('id') ?? '')
  if (!tilbudId) return
  const admin = lagSupabaseAdminKlient()
  const { data: tilbud } = await admin.from('tilbud').select('id, retailer_id, retailer_limit, foresporsel_id').eq('id', tilbudId).limit(1).maybeSingle<{ id: string; retailer_id: string | null; retailer_limit: number; foresporsel_id: string }>()
  if (!tilbud) return
  if (tilbud.retailer_id) { revalidatePath('/plattform/tilbudsforesporsler'); return }
  const { data: f } = await admin.from('tilbudsforesporsler').select('virksomhet, org_nr, kontaktperson, epost, antall_stasjoner').eq('id', tilbud.foresporsel_id).limit(1).single<{ virksomhet: string; org_nr: string | null; kontaktperson: string; epost: string; antall_stasjoner: number }>()
  if (!f) return
  const grunn = slug(f.virksomhet)
  const { data: eksisterende } = await admin.from('retailers').select('id').eq('org_nr', f.org_nr).limit(1).maybeSingle<{ id: string }>()
  if (eksisterende) return
  const { data: retailer, error } = await admin.from('retailers').insert({ navn: f.virksomhet, org_nr: f.org_nr, slug: `${grunn}-${tilbud.id.slice(0, 6)}`, inntak_epost: `${grunn}-${tilbud.id.slice(0, 6)}@sentiqa.ai` }).select('id').limit(1).single<{ id: string }>()
  if (error || !retailer) return
  const h = await headers(); const origin = `${h.get('x-forwarded-proto') ?? 'https'}://${h.get('host')}`
  const inv = await admin.auth.admin.inviteUserByEmail(f.epost, { redirectTo: `${origin}/auth/bekreft` })
  if (inv.error || !inv.data.user) { await admin.from('retailers').delete().eq('id', retailer.id); return }
  await admin.from('profiler').insert({ id: inv.data.user.id, retailer_id: retailer.id, rolle: 'retailer_admin', fullt_navn: f.kontaktperson })
  const stasjoner = Array.from({ length: f.antall_stasjoner }, (_, i) => ({ retailer_id: retailer.id, navn: `Stasjon ${i + 1}`, butikknummer: `${tilbud.id.slice(0, 4)}${String(i + 1).padStart(2, '0')}` }))
  await admin.from('stasjoner').insert(stasjoner)
  await admin.from('tilbud').update({ retailer_id: retailer.id, activated_at: new Date().toISOString(), status: 'aktivert', oppdatert_tid: new Date().toISOString() }).eq('id', tilbud.id).is('retailer_id', null)
  const bruker = await hentInnloggetBruker()
  await admin.from('avtale_revisjon').insert({ tilbud_id: tilbud.id, utfort_av: bruker.id, handling: 'kundeopprettelse', endringer: { retailer_id: retailer.id } })
  revalidatePath('/plattform/tilbudsforesporsler'); revalidatePath('/plattform')
}
