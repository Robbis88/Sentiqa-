'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export type LinjeData = {
  stasjon_id: string
  dato: string
  varenavn: string
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  foreslatt: number
  planlagt: number
}

// Lagrer/overstyrer en plan-linje. Kalles fra stepper-klienten ved endring.
export async function setLinje(data: LinjeData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !data.stasjon_id || !data.dato || !data.varenavn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('produksjonsplan_linjer').upsert(
    {
      retailer_id: bruker.retailerId,
      stasjon_id: data.stasjon_id,
      dato: data.dato,
      varenavn: data.varenavn,
      varegruppe_kode: data.varegruppe_kode,
      varegruppe_navn: data.varegruppe_navn,
      foreslatt: Math.round(data.foreslatt),
      planlagt: Math.max(0, Math.round(data.planlagt)),
      oppdatert_tid: new Date().toISOString(),
    },
    { onConflict: 'stasjon_id,dato,varenavn' },
  )
}
