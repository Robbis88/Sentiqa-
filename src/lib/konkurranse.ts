import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentPerDato } from '@/lib/supabase/datobolker'

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
    .select('varegruppe_kode, maaltype, stasjon_ids, periode_start, periode_slutt').is('slettet_tid', null)
    .eq('id', konkId)
    .maybeSingle<{
      varegruppe_kode: string | null
      maaltype: string
      stasjon_ids: string[]
      periode_start: string
      periode_slutt: string
    }>()
  if (!k) return null

  // =====================================================================
  // VINNEREN BLE AVGJORT AV DE FØRSTE TUSEN RADENE
  // =====================================================================
  // Her sto én spørring uten grense, uten sortering og uten paginering.
  // `v_butikksalg` er én rad per EAN per dag — `0157` sier at åtte uker
  // for fem stasjoner er ~95 000 rader. En månedskonkurranse er godt
  // over 30 000, og PostgREST gir tusen uten å si fra.
  //
  // `daglig_salg` er partisjonert på dato, så utsnittet blir kronologisk:
  // de første dagene av konkurransen, og ingenting etter. En stasjon som
  // tok igjen i uke tre fantes ikke i tallet.
  //
  // Og `kaarVinner` skriver `pengepremie` på svaret. Det er ikke en
  // visningsfeil — det er feil person som får pengene.
  //
  // `hentPerDato` deler perioden i bolker og deler en bolk i to hvis den
  // treffer taket, så svaret kan ikke være stille avkortet.
  type Salgsrad = { stasjon_id: string; omsetning_eks_mva: number | null; antall: number | null }
  const salg = await hentPerDato<Salgsrad>(
    (fra, til) => {
      let q = supabase
        .from('v_butikksalg')
        .select('stasjon_id, omsetning_eks_mva, antall')
        .gte('dato', fra)
        .lte('dato', til)
        .is('slettet_tid', null)
      if (k.varegruppe_kode) q = q.eq('varegruppe_kode', k.varegruppe_kode)
      if (k.stasjon_ids.length > 0) q = q.in('stasjon_id', k.stasjon_ids)
      return q.overrideTypes<Salgsrad[]>()
    },
    k.periode_start,
    k.periode_slutt,
    // TETTERE BOLKER ENN STANDARD. Uten varegruppefilter er dette hele
    // sortimentet: ~340 rader per stasjonsdøgn, altså ~1700 for fem
    // stasjoner på én dag. Tjue dager ville delt seg hver gang.
    k.varegruppe_kode ? 20 : 1,
  )

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).limit(500)
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const per = new Map<string, number>()
  for (const r of salg) {
    const v = k.maaltype === 'antall' ? (r.antall ?? 0) : (r.omsetning_eks_mva ?? 0)
    per.set(r.stasjon_id, (per.get(r.stasjon_id) ?? 0) + v)
  }
  const stilling: Stilling[] = [...per.entries()]
    .map(([sid, verdi]) => ({ stasjon_id: sid, stasjon: navnFor.get(sid) ?? '—', verdi: Math.round(verdi) }))
    .sort((a, b) => b.verdi - a.verdi)

  if (stilling.length === 0) return null
  return { stilling, vinner: stilling[0] }
}
