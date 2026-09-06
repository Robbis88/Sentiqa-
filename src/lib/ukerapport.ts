import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import Anthropic from '@anthropic-ai/sdk'
import { env } from '@/lib/env'

// Ukerapport er ikke-sanntid (lazy ved dashbord-aapning) → Sonnet holder.
const MODELL = 'claude-sonnet-4-6'
type Klient = SupabaseClient

export type UkeAvdeling = { kode: string; navn: string; omsetning: number; ifjor: number; vekstPst: number }
export type UkeRapport = {
  stasjonId: string
  navn: string
  ukeMandag: string
  omsetning: number
  omsetningIfjor: number
  brutto: number
  bruttoIfjor: number
  avdelinger: UkeAvdeling[]
  sammendrag: string | null
}

// Ukedag (0=søn) + dato-aritmetikk via UTC-middag (unngår tidssone-drift).
function ukedag(iso: string): number {
  return new Date(`${iso}T12:00:00Z`).getUTCDay()
}
function leggTil(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

type AvdRad = { avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number; brutto: number }

async function aggreger(supabase: Klient, stasjonId: string, fra: string, til: string): Promise<AvdRad[]> {
  const { data, error } = await supabase.rpc('uke_avdeling_aggregat', { p_stasjon: stasjonId, p_fra: fra, p_til: til })
  // EN UKERAPPORT UTEN AVDELINGER ER IKKE EN ROLIG UKE. Svelges feilen,
  // blir lista tom, og rapporten går ut som om stasjonen ikke solgte
  // noe — med en AI-oppsummering skrevet over ingenting.
  if (error) throw new Error(`uke_avdeling_aggregat feilet: ${error.message}`)
  return (data ?? []) as AvdRad[]
}

async function sammendragAI(anthropic: Anthropic, r: UkeRapport): Promise<string | null> {
  const pst = (n: number, i: number) => (i > 0 ? (((n - i) / i) * 100).toFixed(1) : '0')
  const sortert = [...r.avdelinger].filter((a) => a.ifjor > 0).sort((a, b) => b.vekstPst - a.vekstPst)
  const topp = sortert.slice(0, 2).map((a) => `${a.navn} +${a.vekstPst.toFixed(0)} %`).join(', ')
  const bunn = sortert.slice(-2).map((a) => `${a.navn} ${a.vekstPst.toFixed(0)} %`).join(', ')
  try {
    const resp = await anthropic.messages.create({
      model: MODELL,
      max_tokens: 400,
      system:
        'Du skriver en kort, varm ukesoppsummering til en butikksjef. Norsk bokmål. Nøyaktig 2–3 setninger. ' +
        'Anerkjenn det som gikk bra, og nevn ÉN ting å se på hvis noe drar ned — konkret med tall (kroner/prosent). ' +
        'Ingen emojis, ingen punktlister, ingen overskrift. Aldri finn på tall; bruk kun tallene du får.',
      messages: [{
        role: 'user',
        content:
          `Stasjon ${r.navn}, forrige uke mot samme uke i fjor:\n` +
          `Omsetning ${Math.round(r.omsetning)} kr (i fjor ${Math.round(r.omsetningIfjor)} kr, ${pst(r.omsetning, r.omsetningIfjor)} %).\n` +
          `Bruttofortjeneste ${Math.round(r.brutto)} kr (i fjor ${Math.round(r.bruttoIfjor)} kr, ${pst(r.brutto, r.bruttoIfjor)} %).\n` +
          `Sterkest vekst: ${topp || '—'}. Svakest: ${bunn || '—'}.`,
      }],
    })
    const blokk = resp.content.find((b) => b.type === 'text')
    return blokk && blokk.type === 'text' ? blokk.text.trim() : null
  } catch {
    return null
  }
}

type CacheRad = {
  stasjon_id: string
  omsetning: number | null
  omsetning_ifjor: number | null
  brutto: number | null
  brutto_ifjor: number | null
  avdelinger: UkeAvdeling[]
  ai_sammendrag: string | null
}

// Finner siste komplette uke (mandag–søndag) med data og returnerer rapport pr
// stasjon (cachet i uke_rapport). Lazy: regnes/AI-es kun første gang pr uke.
export async function hentEllerLagUkerapport(
  supabase: Klient,
  retailerId: string,
  stasjoner: { id: string; navn: string; butikknummer: string }[],
  medAi = false, // AI-sammendrag genereres KUN når eksplisitt bedt om (cron), aldri i dashbord-render
): Promise<UkeRapport[]> {
  if (stasjoner.length === 0) return []

  const { data: siste } = await supabase
    .from('v_butikksalg').select('dato').order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
  if (!siste) return []

  // Mest nylige søndag på/før siste dato; gå opptil 6 uker bakover etter data.
  let sondag = leggTil(siste.dato, -ukedag(siste.dato))
  let funnet = false
  for (let i = 0; i < 6; i++) {
    const { count } = await supabase.from('v_butikksalg').select('dato', { count: 'exact', head: true }).eq('dato', sondag)
    if ((count ?? 0) > 0) { funnet = true; break }
    sondag = leggTil(sondag, -7)
  }
  if (!funnet) return []

  const mandag = leggTil(sondag, -6)
  const mandagIfjor = leggTil(mandag, -364) // 52 uker → samme ukedager i fjor
  const sondagIfjor = leggTil(sondag, -364)

  const { data: cachet } = await supabase
    .from('uke_rapport')
    .select('stasjon_id, omsetning, omsetning_ifjor, brutto, brutto_ifjor, avdelinger, ai_sammendrag')
    .eq('uke_mandag', mandag)
    .in('stasjon_id', stasjoner.map((s) => s.id))
    .overrideTypes<CacheRad[]>()
  const cacheMap = new Map((cachet ?? []).map((c) => [c.stasjon_id, c]))

  const anthropic = env.ANTHROPIC_API_KEY ? new Anthropic({ apiKey: env.ANTHROPIC_API_KEY }) : null

  const rapporter = await Promise.all(stasjoner.map(async (s): Promise<UkeRapport | null> => {
    const navn = `${s.butikknummer} ${s.navn}`
    const c = cacheMap.get(s.id)
    if (c) {
      return {
        stasjonId: s.id, navn, ukeMandag: mandag,
        omsetning: c.omsetning ?? 0, omsetningIfjor: c.omsetning_ifjor ?? 0,
        brutto: c.brutto ?? 0, bruttoIfjor: c.brutto_ifjor ?? 0,
        avdelinger: c.avdelinger ?? [], sammendrag: c.ai_sammendrag,
      }
    }

    const [naa, ifjor] = await Promise.all([
      aggreger(supabase, s.id, mandag, sondag),
      aggreger(supabase, s.id, mandagIfjor, sondagIfjor),
    ])
    if (naa.length === 0) return null

    const ifjorMap = new Map(ifjor.map((a) => [a.avdeling_kode ?? '', a]))
    let oms = 0, brutto = 0
    const avdelinger: UkeAvdeling[] = []
    for (const a of naa) {
      const kode = a.avdeling_kode ?? ''
      const omsA = Number(a.omsetning)
      const ifA = Number(ifjorMap.get(kode)?.omsetning ?? 0)
      oms += omsA
      brutto += Number(a.brutto)
      avdelinger.push({ kode, navn: a.avdeling_navn ?? kode, omsetning: omsA, ifjor: ifA, vekstPst: ifA > 0 ? ((omsA - ifA) / ifA) * 100 : 0 })
    }
    const omsIf = ifjor.reduce((t, a) => t + Number(a.omsetning), 0)
    const bruttoIf = ifjor.reduce((t, a) => t + Number(a.brutto), 0)

    const rapport: UkeRapport = {
      stasjonId: s.id, navn, ukeMandag: mandag,
      omsetning: oms, omsetningIfjor: omsIf, brutto, bruttoIfjor: bruttoIf,
      avdelinger, sammendrag: null,
    }
    // Cache TALLENE først — så en treg/feilende AI aldri lar dashbordet time ut.
    await supabase.from('uke_rapport').upsert({
      retailer_id: retailerId, stasjon_id: s.id, uke_mandag: mandag,
      omsetning: oms, omsetning_ifjor: omsIf, brutto, brutto_ifjor: bruttoIf,
      avdelinger, ai_sammendrag: null, modell: null,
    }, { onConflict: 'stasjon_id,uke_mandag', ignoreDuplicates: true })

    // AI-sammendrag kun når eksplisitt bedt om (cron) — aldri i dashbord-render.
    if (medAi && anthropic) {
      const tekst = await sammendragAI(anthropic, rapport)
      if (tekst) {
        rapport.sammendrag = tekst
        await supabase.from('uke_rapport').update({ ai_sammendrag: tekst, modell: MODELL }).eq('stasjon_id', s.id).eq('uke_mandag', mandag)
      }
    }

    return rapport
  }))

  return rapporter.filter((r): r is UkeRapport => r !== null)
}
