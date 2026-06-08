import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>
export type Stilling = { stasjon_id: string; stasjon: string; verdi: number }

// Måler en konkurranse fra daglig_salg (gjetter aldri). Delt av AI-verktøyet
// og UI-en. Returnerer sortert stilling + vinner, eller null hvis ingen data.
export async function maalKonkurranse(
  supabase: Klient,
  konkId: string,
): Promise<{ stilling: Stilling[]; vinner: Stilling } | null> {
  const { data: k } = await supabase
    .from('konkurranser')
    .select('varegruppe_kode, maaltype, stasjon_ids, periode_start, periode_slutt')
    .eq('id', konkId)
    .maybeSingle<{
      varegruppe_kode: string | null
      maaltype: string
      stasjon_ids: string[]
      periode_start: string
      periode_slutt: string
    }>()
  if (!k) return null

  let q = supabase
    .from('daglig_salg')
    .select('stasjon_id, omsetning_eks_mva, antall')
    .gte('dato', k.periode_start)
    .lte('dato', k.periode_slutt)
    .is('slettet_tid', null)
  if (k.varegruppe_kode) q = q.eq('varegruppe_kode', k.varegruppe_kode)
  if (k.stasjon_ids.length > 0) q = q.in('stasjon_id', k.stasjon_ids)
  const { data: salg } = await q.overrideTypes<{ stasjon_id: string; omsetning_eks_mva: number | null; antall: number | null }[]>()

  const { data: stasjoner } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null)
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const per = new Map<string, number>()
  for (const r of salg ?? []) {
    const v = k.maaltype === 'antall' ? (r.antall ?? 0) : (r.omsetning_eks_mva ?? 0)
    per.set(r.stasjon_id, (per.get(r.stasjon_id) ?? 0) + v)
  }
  const stilling: Stilling[] = [...per.entries()]
    .map(([sid, verdi]) => ({ stasjon_id: sid, stasjon: navnFor.get(sid) ?? '—', verdi: Math.round(verdi) }))
    .sort((a, b) => b.verdi - a.verdi)

  if (stilling.length === 0) return null
  return { stilling, vinner: stilling[0] }
}
