'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { iDag } from '@/lib/format'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function leggTilPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const tittel = String(formData.get('tittel') ?? '').trim()
  const gjentakende = formData.get('gjentakende') === 'on'
  if (!tittel) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('personlig_punkt').insert({
    user_id: bruker.id,
    retailer_id: bruker.retailerId ?? null,
    tittel,
    gjentakende,
  }), 'opprette personlig punkt')
  revalidatePath('/rutiner/min')
}

export async function veksle(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const punktId = String(formData.get('punkt_id') ?? '')
  const gjentakende = String(formData.get('gjentakende') ?? '') === 'true'
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!punktId) return
  const supabase = await lagSupabaseServerKlient()

  if (gjentakende) {
    if (til) {
      maaLykkes(await supabase.from('personlig_kryss').upsert(
        { punkt_id: punktId, user_id: bruker.id, dato: iDag() },
        { onConflict: 'punkt_id,dato', ignoreDuplicates: true },
      ), 'lagre personlig kryss')
    } else {
      maaLykkes(await supabase.from('personlig_kryss').delete().eq('punkt_id', punktId).eq('dato', iDag()), 'slette personlig kryss')
    }
  } else {
    maaLykkes(await supabase
      .from('personlig_punkt')
      .update({ fullfort_tid: til ? new Date().toISOString() : null })
      .eq('id', punktId), 'oppdatere personlig punkt')
  }
  revalidatePath('/rutiner/min')
}

export async function slettPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('personlig_punkt').update({ slettet_tid: new Date().toISOString() }).eq('id', id), 'slette personlig punkt')
  revalidatePath('/rutiner/min')
}
