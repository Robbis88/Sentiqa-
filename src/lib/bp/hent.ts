import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAlle } from '@/lib/supabase/sider'
import type { Aarstall, Varegruppe, Kostnadskonto } from './analyse'

// =====================================================================
// BP-AARGANGENE UT AV BASEN, I DEN FORMEN ANALYSEN LESER
//
// `summer()` i analyse.ts tar en `BpResultat` rett fra parseren. Her
// bygges den samme `Aarstall` fra `bp_aar` og `bp_linje` i stedet, slik
// at sida kan lese aarganger som ble importert for lenge siden.
//
// De to veiene MAA gi samme svar. `hent.test.ts` beviser det paa den
// eneste maaten som teller: samme tall gjennom begge.
//
// ---------------------------------------------------------------------
// PAGINERING ER IKKE VALGFRITT
//
// PostgREST kutter i stillhet ved 1000 rader. En aargang er 5 stasjoner
// x 12 maaneder x ~40 koder = rundt 2 400 linjer, saa uten `hentAlle`
// ville analysen lest under halve budsjettet og sagt det med to
// desimaler.
// =====================================================================

type Klient = SupabaseClient

export type Aargang = {
  ar: number
  format: string
  stasjoner: number
  stasjonerMedTimer: number
  timerAar: number
  sistOppdatert: string
}

/** Hvilke aarganger kjeden faktisk har. Sida skal ikke love mer enn det. */
export async function hentAarganger(supabase: Klient): Promise<Aargang[]> {
  const { data, error } = await supabase
    .from('v_bp_aarganger')
    .select('ar, format, stasjoner, stasjoner_med_timer, timer_aar, sist_oppdatert')
    .order('ar', { ascending: false })
  if (error) throw new Error(`Kunne ikke lese BP-årganger: ${error.message}`)
  return ((data ?? []) as {
    ar: number; format: string; stasjoner: number
    stasjoner_med_timer: number; timer_aar: number; sist_oppdatert: string
  }[]).map((r) => ({
    ar: r.ar,
    format: r.format,
    stasjoner: r.stasjoner,
    stasjonerMedTimer: r.stasjoner_med_timer,
    timerAar: r.timer_aar ?? 0,
    sistOppdatert: r.sist_oppdatert,
  }))
}

type AarRad = { id: string; stasjon_id: string; timer_aar: number | null; format: string }
type LinjeRad = {
  bp_aar_id: string; seksjon: string; kode: string; post: string; belop_kr: number
}

const ROYALTY = '6312'
const FSA = '6315'
const erLonn = (kode: string) => /^5\d{3}$/.test(kode)

/**
 * Bygger en `Aarstall` for ett aar.
 *
 * `stasjonIder` avgrenser til de stasjonene sammenligningen gjelder. Det
 * er ikke pynt: Lone kom til 01.02.25 og Dale 01.04.25, saa en
 * aar-mot-aar-sammenligning over ALLE stasjoner ville malt oppkjoep som
 * vekst. Kallstedet bestemmer utvalget; denne funksjonen gjetter ikke.
 */
export async function hentAarstall(
  supabase: Klient, ar: number, stasjonIder?: string[],
): Promise<Aarstall | null> {
  let q = supabase.from('bp_aar').select('id, stasjon_id, timer_aar, format').eq('ar', ar)
  if (stasjonIder) q = q.in('stasjon_id', stasjonIder)
  const { data: aarRader, error } = await q
  if (error) throw new Error(`Kunne ikke lese BP ${ar}: ${error.message}`)
  const aargangene = (aarRader ?? []) as AarRad[]
  // Null, ikke en tom `Aarstall`. «Vi har ingen BP for 2025» og «BP-en
  // for 2025 er null kroner» er to helt forskjellige svar.
  if (aargangene.length === 0) return null

  const ider = aargangene.map((a) => a.id)
  const linjer = await hentAlle<LinjeRad>(() =>
    supabase
      .from('bp_linje')
      .select('bp_aar_id, seksjon, kode, post, belop_kr')
      .in('bp_aar_id', ider)
      .order('bp_aar_id'),
  )

  const t: Aarstall = {
    ar,
    salg: 0, varekost: 0, brutto: 0,
    personal: 0, timelonn: 0, fastlonn: 0,
    andreKostnader: 0, royalty: 0, timer: 0,
    kategorier: new Map<string, Varegruppe>(),
    konti: new Map<string, Kostnadskonto>(),
  }
  for (const a of aargangene) t.timer += a.timer_aar ?? 0

  for (const l of linjer) {
    const kr = Number(l.belop_kr) || 0
    if (l.seksjon === 'omsetning' || l.seksjon === 'varekost') {
      const v = t.kategorier.get(l.kode) ?? { post: l.post, salg: 0, varekost: 0 }
      if (l.seksjon === 'omsetning') { v.salg += kr; t.salg += kr }
      else { v.varekost += kr; t.varekost += kr }
      t.kategorier.set(l.kode, v)
      continue
    }
    if (l.kode === ROYALTY) { t.royalty += kr; continue }
    if (l.kode === FSA) continue
    const v = t.konti.get(l.kode) ?? { post: l.post, kr: 0 }
    v.kr += kr
    t.konti.set(l.kode, v)
    if (erLonn(l.kode)) t.personal += kr
    else t.andreKostnader += kr
  }

  t.brutto = t.salg - t.varekost

  // SPLITTEN FINNES BARE DER FORMATET HAR DEN, og det er formatet som
  // avgjoer - ikke om kontoen tilfeldigvis har en verdi.
  //
  // BP25-malen foerer HELE stasjonens loenn paa 5010. Leses den som
  // fastloenn, staar 2025 med 11,2 millioner mot BP26s 1,86 - et kutt
  // paa 84 % som aldri har funnet sted, og som en graf tegner like
  // villig som et riktig tall. Parseren lar begge feltene staa paa null
  // av samme grunn; her maa basen behandles likt.
  const harSplitt = aargangene.every((a) => a.format === 'st1_bp26')
  t.timelonn = harSplitt ? (t.konti.get('5012')?.kr ?? 0) : 0
  t.fastlonn = harSplitt ? (t.konti.get('5010')?.kr ?? 0) : 0
  return t
}

/**
 * Stasjonene som finnes i BEGGE aargangene, og bare de.
 *
 * DETTE ER IKKE EN DETALJ. Robert overtok Lone 01.02.25 og Dale
 * 01.04.25. En sammenligning over alle stasjoner i hver aargang ville
 * malt oppkjoep som vekst: BP26 har fem stasjoner, BP25 har tre, og
 * "+40 % omsetning" hadde vaert to nye stasjoner - ikke en krone mer per
 * stasjon.
 *
 * Snittet er det eneste utvalget som svarer paa spoersmaalet "hva betyr
 * den nye BP-en for driften vi alt har".
 */
export async function fellesStasjoner(
  supabase: Klient, fjor: number, iAar: number,
): Promise<string[]> {
  const { data, error } = await supabase
    .from('bp_aar')
    .select('ar, stasjon_id')
    .in('ar', [fjor, iAar])
  if (error) throw new Error(`Kunne ikke lese BP-stasjoner: ${error.message}`)
  const per = new Map<number, Set<string>>()
  for (const r of (data ?? []) as { ar: number; stasjon_id: string }[]) {
    if (!per.has(r.ar)) per.set(r.ar, new Set())
    per.get(r.ar)!.add(r.stasjon_id)
  }
  const a = per.get(fjor)
  const b = per.get(iAar)
  if (!a || !b) return []
  return [...a].filter((s) => b.has(s)).sort()
}
