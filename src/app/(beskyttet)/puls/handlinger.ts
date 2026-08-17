'use server'
import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt, hentStasjonId } from '@/lib/ansatt'
import { STANDARD_PULS_SPORSMAL } from '@/lib/puls/standard'

// ---- Spørsmålsbibliotek ----
export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase.from('puls_sporsmal').select('*', { count: 'exact', head: true }).eq('retailer_id', bruker.retailerId).is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  await supabase.from('puls_sporsmal').insert(
    STANDARD_PULS_SPORSMAL.map((s, i) => ({ retailer_id: bruker.retailerId, kategori: s.kategori, tekst: s.tekst, sortering: i })),
  )
  revalidatePath('/puls/sporsmal')
}

export async function leggTilSporsmal(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const kategori = String(formData.get('kategori') ?? '').trim() || 'Trivsel'
  const tekst = String(formData.get('tekst') ?? '').trim()
  if (!tekst) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('puls_sporsmal').insert({ retailer_id: bruker.retailerId, kategori, tekst, sortering: 999 })
  revalidatePath('/puls/sporsmal')
}

export async function vekslAktivSporsmal(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('puls_sporsmal').update({ aktiv: til }).eq('id', id)
  revalidatePath('/puls/sporsmal')
}

export async function slettSporsmal(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('puls_sporsmal').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/puls/sporsmal')
}

// ---- Runder ----
export async function startRunde(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  let sporsmalId = String(formData.get('sporsmal_id') ?? '')
  const nyTekst = String(formData.get('nytt_sporsmal') ?? '').trim()
  const start = String(formData.get('start_dato') ?? '')
  const slutt = String(formData.get('slutt_dato') ?? '')
  const notat = String(formData.get('notat') ?? '').trim() || null
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start) || !/^\d{4}-\d{2}-\d{2}$/.test(slutt)) return
  const supabase = await lagSupabaseServerKlient()

  // Skrev de et nytt spørsmål rett her? Opprett det først, så slipper de å
  // innom spørsmålsbiblioteket — alt i ett steg.
  if (nyTekst) {
    const kategori = String(formData.get('kategori') ?? '').trim() || 'Trivsel'
    const { data: nytt } = await supabase
      .from('puls_sporsmal')
      .insert({ retailer_id: bruker.retailerId, kategori, tekst: nyTekst, sortering: 999 })
      .select('id')
      .single()
    sporsmalId = nytt?.id ?? ''
  }
  if (!sporsmalId) return

  await supabase.from('puls_runde').insert({
    retailer_id: bruker.retailerId,
    sporsmal_id: sporsmalId,
    start_dato: start,
    slutt_dato: slutt,
    notat,
    opprettet_av: bruker.id,
  })
  redirect('/puls')
}

export async function avsluttRunde(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('puls_runde').update({ status: 'avsluttet' }).eq('id', id)
  revalidatePath('/puls')
}

export async function slettRunde(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('puls_runde').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/puls')
}

// ---- Svar (tablet, sporadisk popup) ----
export type SvarResultat = { ok?: true; feil?: string }
export async function svarRunde(_t: SvarResultat | undefined, formData: FormData): Promise<SvarResultat> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const rundeId = String(formData.get('runde_id') ?? '')
  const skala = Number(formData.get('skala'))
  const kommentar = String(formData.get('kommentar') ?? '').trim() || null
  if (!rundeId || !Number.isInteger(skala) || skala < 1 || skala > 5) return { feil: 'Velg en verdi.' }

  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt()
  const stasjonId = await hentStasjonId(supabase, ansatt)
  if (!stasjonId) return { feil: 'Fant ingen stasjon.' }

  // Gaar gjennom funksjonen, ikke rett paa tabellen: ansatt_id er ikke
  // lesbar for noen (0104), saa appen kan ikke avduplisere selv. Koblingen
  // finnes bare for aa hindre at samme person svarer to ganger — ingen med
  // lederinnlogging kan hente den ut.
  const { error } = await supabase.rpc('lagre_puls_svar', {
    p_runde: rundeId,
    p_stasjon: stasjonId,
    p_ansatt: ansatt?.id ?? null,
    p_skala: skala,
    p_kommentar: kommentar,
  })
  if (error) return { feil: 'Fikk ikke lagret svaret.' }
  return { ok: true }
}
