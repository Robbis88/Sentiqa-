'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { STANDARD_OPPLARING } from '@/lib/opplaring/standard'

function iDag(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
}
function erLeder(rolle: string) {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}

// Setter opp standard læreplan for kjeden (ett klikk).
export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase
    .from('opplaring_punkter')
    .select('*', { count: 'exact', head: true })
    .eq('retailer_id', bruker.retailerId)
    .is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  const rader = STANDARD_OPPLARING.map((p, i) => ({
    retailer_id: bruker.retailerId,
    omrade: p.omrade,
    tekst: p.tekst,
    sortering: i,
  }))
  await supabase.from('opplaring_punkter').insert(rader)
  revalidatePath('/opplaring')
}

export async function leggTilPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const omrade = String(formData.get('omrade') ?? '').trim() || 'Annet'
  const tekst = String(formData.get('tekst') ?? '').trim()
  if (!tekst) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaring_punkter').insert({ retailer_id: bruker.retailerId, omrade, tekst, sortering: 999 })
  revalidatePath('/opplaring')
}

export async function leggTilPerson(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const navn = String(formData.get('navn') ?? '').trim()
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const startdato = String(formData.get('startdato') ?? '') || null
  if (!navn || !stasjonId) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaring_personer').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    navn,
    startdato,
    opprettet_av: bruker.id,
  })
  revalidatePath('/opplaring')
}

// Signer/avsigner et lærepunkt for en person.
export async function veksleFullfort(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const personId = String(formData.get('person_id') ?? '')
  const punktId = String(formData.get('punkt_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!personId || !punktId || !stasjonId) return
  const supabase = await lagSupabaseServerKlient()
  if (til) {
    await supabase.from('opplaring_fullfort').upsert(
      { person_id: personId, punkt_id: punktId, stasjon_id: stasjonId, signert_av: bruker.id, fullfort_dato: iDag() },
      { onConflict: 'person_id,punkt_id' },
    )
  } else {
    await supabase.from('opplaring_fullfort').delete().eq('person_id', personId).eq('punkt_id', punktId)
  }
  revalidatePath('/opplaring')
}
