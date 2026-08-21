import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

type Klient = SupabaseClient

export type VekstMetrikk = {
  iDag: number
  iFjor: number
  mtd: number
  mtdIfjor: number
  streak: number // dager på rad over fjoråret (samme dato −364)
}
export type HjemData = {
  skills: { prosent: number; tekst: string } | null
  premie: { vunnet: number; brukt: number; igjen: number }
  produksjon: { antall: number; plan: number; lagd: number } | null
  vekst: {
    sisteDato: string
    metrikker: { samlet: VekstMetrikk; mat: VekstMetrikk; kaldDrikke: VekstMetrikk }
  } | null
}

function skillsTekst(p: number): string {
  if (p >= 100) return 'Helt perfekt! Hele teamet er på topp'
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
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  const [{ data: skill }, { data: tildelt }, { data: bruk }, { data: salg }, produksjon] = await Promise.all([
    supabase.from('skills_score').select('prosent').eq('stasjon_id', stasjonId).order('registrert_tid', { ascending: false }).limit(1).maybeSingle<{ prosent: number }>(),
    supabase.from('pengepremie').select('belop_kr').eq('stasjon_id', stasjonId),
    supabase.from('pengepremie_bruk').select('belop_kr').eq('stasjon_id', stasjonId),
    supabase.from('v_salg_per_stasjon_dag').select('dato, omsetning, mat_omsetning, kald_drikke_omsetning').eq('stasjon_id', stasjonId).order('dato', { ascending: false }).limit(760).overrideTypes<{ dato: string; omsetning: number | null; mat_omsetning: number | null; kald_drikke_omsetning: number | null }[]>(),
    // Dagens publiserte produksjonsplan (kun hvis publisert) — fremdrift til tableten.
    (async (): Promise<HjemData['produksjon']> => {
      const { data: hode } = await supabase.from('produksjonsplan_hode').select('publisert_tid').eq('stasjon_id', stasjonId).eq('dato', idag).maybeSingle<{ publisert_tid: string | null }>()
      if (!hode?.publisert_tid) return null
      const { data: linjer } = await supabase.from('produksjonsplan_linjer').select('planlagt, lagd_hittil').eq('stasjon_id', stasjonId).eq('dato', idag).eq('ekskludert', false).gt('planlagt', 0).overrideTypes<{ planlagt: number; lagd_hittil: number }[]>()
      const ls = linjer ?? []
      return { antall: ls.length, plan: ls.reduce((a, l) => a + l.planlagt, 0), lagd: ls.reduce((a, l) => a + l.lagd_hittil, 0) }
    })(),
  ])

  const skills = skill ? { prosent: Number(skill.prosent), tekst: skillsTekst(Number(skill.prosent)) } : null

  // Vunnet = alle tildelinger (konkurranse-vinnere oppretter tildeling automatisk)
  const vunnet = ((tildelt ?? []) as { belop_kr: number | null }[]).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
  const brukt = ((bruk ?? []) as { belop_kr: number | null }[]).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
  const premie = { vunnet, brukt, igjen: vunnet - brukt }

  // Vekst mot fjoråret (−364 d): i dag, måneden hittil, og streak (dager på rad
  // over fjoråret) — for Samlet og Mat. Engasjement på tableten.
  let vekst: HjemData['vekst'] = null
  const rader = (salg ?? []) as { dato: string; omsetning: number | null; mat_omsetning: number | null; kald_drikke_omsetning: number | null }[]
  if (rader.length > 0) {
    const sisteDato = rader[0].dato
    const mndStart = `${sisteDato.slice(0, 7)}-01`

    const beregn = (felt: (r: (typeof rader)[number]) => number): VekstMetrikk => {
      const m = new Map(rader.map((r) => [r.dato, felt(r)]))
      const sumRange = (fra: string, til: string) => [...m.entries()].reduce((a, [d, v]) => (d >= fra && d <= til ? a + v : a), 0)
      let streak = 0
      for (let i = 0; ; i++) {
        const d = minus(sisteDato, i)
        if (!m.has(d)) break
        const ifjor = m.get(minus(d, 364))
        if (ifjor == null) break // ingen fjorårsdata å sammenligne med
        if ((m.get(d) ?? 0) > ifjor) streak++
        else break
      }
      return {
        iDag: m.get(sisteDato) ?? 0,
        iFjor: m.get(minus(sisteDato, 364)) ?? 0,
        mtd: sumRange(mndStart, sisteDato),
        mtdIfjor: sumRange(minus(mndStart, 364), minus(sisteDato, 364)),
        streak,
      }
    }

    vekst = {
      sisteDato,
      metrikker: {
        samlet: beregn((r) => r.omsetning ?? 0),
        mat: beregn((r) => r.mat_omsetning ?? 0),
        kaldDrikke: beregn((r) => r.kald_drikke_omsetning ?? 0),
      },
    }
  }

  return { skills, premie, produksjon, vekst }
}
