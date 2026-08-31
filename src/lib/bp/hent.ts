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
  const { aargangene, linjer } = await lesAargang(supabase, ar, stasjonIder)
  // Null, ikke en tom `Aarstall`. «Vi har ingen BP for 2025» og «BP-en
  // for 2025 er null kroner» er to helt forskjellige svar.
  if (aargangene.length === 0) return null
  return bygg(ar, aargangene, linjer)
}

/**
 * Samme årgang, men delt per stasjon.
 *
 * «trenger jo å kunne se hvilken stasjon også» — Robert 2026-08-31.
 *
 * Kjedetotalen sier hva den nye BP-en betyr samlet; den sier ikke hvilken
 * stasjon som bærer endringen. En royaltyandel som stiger like mye på alle
 * tre er noe helt annet enn én stasjon som drar snittet.
 *
 * Leser NØYAKTIG de samme radene som `hentAarstall`, og bygger med samme
 * funksjon — så summen av stasjonene er kjedetallet, ikke et tall til.
 */
export async function hentPerStasjon(
  supabase: Klient, ar: number, stasjonIder?: string[],
): Promise<Map<string, Aarstall>> {
  const { aargangene, linjer } = await lesAargang(supabase, ar, stasjonIder)
  const ut = new Map<string, Aarstall>()
  for (const a of aargangene) {
    const mine = linjer.filter((l) => l.bp_aar_id === a.id)
    ut.set(a.stasjon_id, bygg(ar, [a], mine))
  }
  return ut
}

/** Radene for en årgang. Delt av begge inngangene over. */
async function lesAargang(
  supabase: Klient, ar: number, stasjonIder?: string[],
): Promise<{ aargangene: AarRad[]; linjer: LinjeRad[] }> {
  let q = supabase.from('bp_aar').select('id, stasjon_id, timer_aar, format').eq('ar', ar)
  if (stasjonIder) q = q.in('stasjon_id', stasjonIder)
  const { data: aarRader, error } = await q
  if (error) throw new Error(`Kunne ikke lese BP ${ar}: ${error.message}`)
  const aargangene = (aarRader ?? []) as AarRad[]
  if (aargangene.length === 0) return { aargangene, linjer: [] }
  const linjer = await hentAlle<LinjeRad>(() =>
    supabase
      .from('bp_linje')
      .select('bp_aar_id, seksjon, kode, post, belop_kr')
      .in('bp_aar_id', aargangene.map((a) => a.id))
      .order('bp_aar_id'),
  )
  return { aargangene, linjer }
}

/** Summerer et sett årgangsrader og linjer til én `Aarstall`. */
function bygg(ar: number, aargangene: AarRad[], linjer: LinjeRad[]): Aarstall {
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
 * Hvor mange måneder BP-en faktisk dekker, per stasjon.
 *
 * EN BP DEKKER IKKE NØDVENDIGVIS ET HELT ÅR. Målt mot Kelsars egne
 * filer 2026-08-31:
 *
 *   Laguneparken, Varden, Bønes   BP 2025   12 mnd
 *   Dale                          BP 2025    9 mnd  (apr–des)
 *   Lone                          BP 2025   11 mnd  (feb–des)
 *
 * Robert overtok Lone 01.02.25 og Dale 01.04.25, og St1 lager da en BP
 * for den delen av året han faktisk driver.
 */
export async function maanederPerStasjon(
  supabase: Klient, ar: number,
): Promise<Map<string, number>> {
  const { data: aarRader, error } = await supabase
    .from('bp_aar').select('id, stasjon_id').eq('ar', ar)
  if (error) throw new Error(`Kunne ikke lese BP-stasjoner ${ar}: ${error.message}`)
  const aargangene = (aarRader ?? []) as { id: string; stasjon_id: string }[]
  if (aargangene.length === 0) return new Map()
  const stasjonFor = new Map(aargangene.map((a) => [a.id, a.stasjon_id]))

  const linjer = await hentAlle<{ bp_aar_id: string; maned: number }>(() =>
    supabase
      .from('bp_linje')
      .select('bp_aar_id, maned')
      .eq('seksjon', 'omsetning')
      .in('bp_aar_id', [...stasjonFor.keys()])
      .order('bp_aar_id'),
  )

  const per = new Map<string, Set<number>>()
  for (const l of linjer) {
    const s = stasjonFor.get(l.bp_aar_id)
    if (!s) continue
    if (!per.has(s)) per.set(s, new Set())
    per.get(s)!.add(l.maned)
  }
  return new Map([...per].map(([s, m]) => [s, m.size]))
}

export type Utelatt = { stasjonId: string; fjor: number; iAar: number }

/**
 * Stasjonene sammenligningen kan bruke, og de den maa la ligge.
 *
 * TO KRAV, OG BEGGE ER ARITMETIKK - IKKE SMAK:
 *
 *   1. Stasjonen maa finnes i BEGGE aarganger. Ellers males et oppkjoep
 *      som vekst.
 *   2. BP-ene maa dekke LIKE MANGE MAANEDER. Dales BP for 2025 dekker
 *      ni maaneder, den for 2026 tolv. Stilt mot hverandre gir det rundt
 *      +33 % «vekst» som utelukkende er kalender - og tallet ser like
 *      solid ut som et ekte.
 *
 * De utelatte returneres med tallene sine, slik at sida kan si HVEM som
 * er holdt utenfor og HVORFOR. En stille utelatelse ville vaert like
 * misvisende som en stille medregning.
 */
export async function sammenlignbareStasjoner(
  supabase: Klient, fjor: number, iAar: number,
): Promise<{ med: string[]; utelatt: Utelatt[] }> {
  const [a, b] = await Promise.all([
    maanederPerStasjon(supabase, fjor),
    maanederPerStasjon(supabase, iAar),
  ])
  const med: string[] = []
  const utelatt: Utelatt[] = []
  for (const [stasjonId, mFjor] of [...a].sort()) {
    const mIAar = b.get(stasjonId)
    if (mIAar === undefined) continue // finnes ikke i det nye aaret
    if (mFjor === mIAar) med.push(stasjonId)
    else utelatt.push({ stasjonId, fjor: mFjor, iAar: mIAar })
  }
  return { med, utelatt }
}

/**
 * Budsjettert Mat-omsetning per aar og stasjon.
 *
 * Grunnlaget for aa plassere en delingsfil i riktig aargang: fila oppgir
 * `Budsjettert matomsetning`, og det tallet er BP-ens Mat paa krona.
 *
 * MAT ER ST1s EGET ORD, og koblingen er iboende i filparet - begge filene
 * er St1s, og de bruker samme vokabular. Derfor gjenkjennes gruppa paa
 * NAVNET og ikke bare paa koden: koden `120` er en observasjon fra en
 * kjede, navnet «Mat» er det St1 selv skriver i begge filene.
 */
export async function matbudsjettPerAar(
  supabase: Klient,
): Promise<Map<number, Map<string, number>>> {
  const { data: aarRader, error } = await supabase
    .from('bp_aar').select('id, stasjon_id, ar')
  if (error) throw new Error(`Kunne ikke lese BP-aargangene: ${error.message}`)
  const aargangene = (aarRader ?? []) as { id: string; stasjon_id: string; ar: number }[]
  if (aargangene.length === 0) return new Map()
  const info = new Map(aargangene.map((a) => [a.id, a]))

  const linjer = await hentAlle<{
    bp_aar_id: string; kode: string; post: string; belop_kr: number
  }>(() =>
    supabase
      .from('bp_linje')
      .select('bp_aar_id, kode, post, belop_kr')
      .eq('seksjon', 'omsetning')
      .in('bp_aar_id', [...info.keys()])
      .order('bp_aar_id'),
  )

  const ut = new Map<number, Map<string, number>>()
  for (const l of linjer) {
    const a = info.get(l.bp_aar_id)
    if (!a) continue
    if (!/\bmat\b/i.test(l.post) && l.kode !== '120') continue
    if (!ut.has(a.ar)) ut.set(a.ar, new Map())
    const per = ut.get(a.ar)!
    per.set(a.stasjon_id, (per.get(a.stasjon_id) ?? 0) + (Number(l.belop_kr) || 0))
  }
  return ut
}
