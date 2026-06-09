import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

type Klient = SupabaseClient

export type HjemData = {
  skills: { prosent: number; tekst: string } | null
  premie: { vunnet: number; brukt: number; igjen: number }
  vekst: {
    sisteDato: string | null
    sisteOms: number
    sisteIfjor: number
    mtdOms: number
    mtdIfjor: number
  } | null
}

function skillsTekst(p: number): string {
  if (p >= 100) return 'Helt perfekt! Hele teamet er på topp 🏆'
  if (p >= 90) return 'Sterkt — nesten på topp!'
  if (p >= 70) return 'Bra jobba — fortsett sånn'
  if (p >= 50) return 'På god vei'
  return 'Her er det rom for å løfte seg'
}
function minus(dato: string, dager: number): string {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - dager)
  return d.toISOString().slice(0, 10)
}

export async function hentHjemData(supabase: Klient, stasjonId: string): Promise<HjemData> {
  const [{ data: skill }, { data: vunne }, { data: tildelt }, { data: bruk }, { data: salg }] = await Promise.all([
    supabase.from('skills_score').select('prosent').eq('stasjon_id', stasjonId).order('registrert_tid', { ascending: false }).limit(1).maybeSingle<{ prosent: number }>(),
    supabase.from('konkurranser').select('premie_kr').eq('vinner_stasjon_id', stasjonId).eq('status', 'avsluttet').is('slettet_tid', null),
    supabase.from('pengepremie').select('belop_kr').eq('stasjon_id', stasjonId),
    supabase.from('pengepremie_bruk').select('belop_kr').eq('stasjon_id', stasjonId),
    supabase.from('v_salg_per_stasjon_dag').select('dato, omsetning').eq('stasjon_id', stasjonId).order('dato', { ascending: false }).limit(420).overrideTypes<{ dato: string; omsetning: number | null }[]>(),
  ])

  const skills = skill ? { prosent: Number(skill.prosent), tekst: skillsTekst(Number(skill.prosent)) } : null

  const vunnetKonk = ((vunne ?? []) as { premie_kr: number | null }[]).reduce((a, r) => a + (r.premie_kr ?? 0), 0)
  const vunnetTildelt = ((tildelt ?? []) as { belop_kr: number | null }[]).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
  const vunnet = vunnetKonk + vunnetTildelt
  const brukt = ((bruk ?? []) as { belop_kr: number | null }[]).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
  const premie = { vunnet, brukt, igjen: vunnet - brukt }

  // Vekst mot fjoråret: siste salgsdag + måneden hittil, mot samme ukedag/periode i fjor (−364 d).
  let vekst: HjemData['vekst'] = null
  const rader = (salg ?? []) as { dato: string; omsetning: number | null }[]
  if (rader.length > 0) {
    const omsFor = new Map(rader.map((r) => [r.dato, r.omsetning ?? 0]))
    const sisteDato = rader[0].dato
    const ifjorDato = minus(sisteDato, 364)
    const mndStart = `${sisteDato.slice(0, 7)}-01`
    const mndStartIfjor = minus(mndStart, 364)
    const sum = (fra: string, til: string) => rader.filter((r) => r.dato >= fra && r.dato <= til).reduce((a, r) => a + (r.omsetning ?? 0), 0)
    vekst = {
      sisteDato,
      sisteOms: omsFor.get(sisteDato) ?? 0,
      sisteIfjor: omsFor.get(ifjorDato) ?? 0,
      mtdOms: sum(mndStart, sisteDato),
      mtdIfjor: sum(mndStartIfjor, minus(sisteDato, 364)),
    }
  }

  return { skills, premie, vekst }
}
