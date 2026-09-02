import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import {
  minusDager, sammenlikn, type Sammenlikning,
} from './vekst-ifjor'

type Klient = SupabaseClient

/**
 * Ett vindu sammenliknet mot fjoråret, med alt som trengs for å vise
 * det ærlig: vinduene selv, dagtellingen, og hvor mange dager fjoråret
 * mangler.
 *
 * Regnestykket ligger i `vekst-ifjor.ts` — rent, og felles av en test
 * som kjører på 20 ms.
 */
export type VekstMetrikk = {
  sisteDag: Sammenlikning
  maanedHittil: Sammenlikning
  streak: number // dager på rad over fjorårets samme ukedag (−364)
}
export type HjemData = {
  skills: { prosent: number; tekst: string } | null
  premie: { vunnet: number; brukt: number; igjen: number }
  produksjon: { antall: number; plan: number; lagd: number } | null
  vekst: {
    sisteDato: string
    metrikker: { matOgDrikke: VekstMetrikk; mat: VekstMetrikk; kaldDrikke: VekstMetrikk }
  } | null
}

function skillsTekst(p: number): string {
  if (p >= 100) return 'Helt perfekt! Hele teamet er på topp'
  if (p >= 90) return 'Sterkt — nesten på topp!'
  if (p >= 70) return 'Bra jobba — fortsett sånn'
  if (p >= 50) return 'På god vei'
  return 'Her er det rom for å løfte seg'
}

export async function hentHjemData(supabase: Klient, stasjonId: string): Promise<HjemData> {
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  // TO TALL, IKKE TO RADER (0165).
  //
  // Foer leste denne `skills_score` og `pengepremie_bruk` direkte, og med
  // `prosent` fulgte `kommentar` - butikksjefens skriftlige vurdering av
  // stasjonen - mens `belop_kr` dro med seg `beskrivelse`, altsaa hva
  // pengene gikk til. Nettbrettet er en DELT enhet i butikken.
  //
  // `hjem_stasjonstall` er `security definer` med eget tenantpredikat og
  // returnerer noeyaktig de to tallene. Lederflatene leser tabellene som
  // foer - de skal se kommentaren.
  //
  // OG FEILEN LESES. Et `rpc`-kall som ikke sjekker `error` gjoer «funksjonen
  // finnes ikke» om til «ingen data» - det var nettopp den formen som lot
  // `/maaling` staa og si «Ingen stasjoner» i maanedsvis fordi `0075` aldri
  // var kjoert. Her ville symptomet vaert et hjemskjermkort som bare uteble.
  const [{ data: tall, error: tallFeil }, { data: tildelt }, { data: salg }, produksjon] = await Promise.all([
    supabase.rpc('hjem_stasjonstall', { p_stasjon_id: stasjonId })
      .maybeSingle<{ skills_prosent: number | null; premie_brukt_kr: number | null }>(),
    supabase.from('pengepremie').select('belop_kr').eq('stasjon_id', stasjonId),
    supabase.from('v_salg_per_stasjon_dag').select('dato, mat_omsetning, kald_drikke_omsetning').eq('stasjon_id', stasjonId).order('dato', { ascending: false }).limit(760).overrideTypes<{ dato: string; mat_omsetning: number | null; kald_drikke_omsetning: number | null }[]>(),
    // Dagens publiserte produksjonsplan (kun hvis publisert) — fremdrift til tableten.
    (async (): Promise<HjemData['produksjon']> => {
      const { data: hode } = await supabase.from('produksjonsplan_hode').select('publisert_tid').eq('stasjon_id', stasjonId).eq('dato', idag).maybeSingle<{ publisert_tid: string | null }>()
      if (!hode?.publisert_tid) return null
      const { data: linjer } = await supabase.from('produksjonsplan_linjer').select('planlagt, lagd_hittil').eq('stasjon_id', stasjonId).eq('dato', idag).eq('ekskludert', false).gt('planlagt', 0).overrideTypes<{ planlagt: number; lagd_hittil: number }[]>()
      const ls = linjer ?? []
      return { antall: ls.length, plan: ls.reduce((a, l) => a + l.planlagt, 0), lagd: ls.reduce((a, l) => a + l.lagd_hittil, 0) }
    })(),
  ])

  // Kaster, framfor aa vise en stasjon uten tall som om den var tom.
  // `hentHjemData` kalles fra en serverkomponent, saa feilgrensa tar den
  // og sier fra - i motsetning til et kort som bare ikke er der.
  if (tallFeil) {
    throw new Error(`Fikk ikke stasjonstallene til hjemskjermen: ${tallFeil.message}`)
  }

  // `null` er ikke 0: en stasjon uten registrert score skal vise
  // ingenting, ikke «0 %». Funksjonen gir ogsaa null naar stasjonen ikke
  // er min - da er det riktig at kortet uteblir.
  const prosent = tall?.skills_prosent
  const skills = prosent != null
    ? { prosent: Number(prosent), tekst: skillsTekst(Number(prosent)) }
    : null

  // Vunnet = alle tildelinger (konkurranse-vinnere oppretter tildeling automatisk)
  const vunnet = ((tildelt ?? []) as { belop_kr: number | null }[]).reduce((a, r) => a + (r.belop_kr ?? 0), 0)
  const brukt = Number(tall?.premie_brukt_kr ?? 0)
  const premie = { vunnet, brukt, igjen: vunnet - brukt }

  // Vekst mot fjoråret (−364 d): siste salgsdag, måneden hittil, og streak
  // (dager på rad over fjoråret). Engasjement på tableten.
  //
  // KORTET MAALER MAT OG KALD DRIKKE, IKKE HELE BUTIKKEN.
  //
  // «Mat og drikke» var summen av `omsetning` — alt butikksalg uten
  // drivstoff. Da lå kiosk, tobakk, bilvask, bil, fritid og pant inne i
  // tallet stasjonen skulle måles på, og en god uke på tobakk kunne
  // dekke over en dårlig uke på mat.
  //
  // Robert 2026-08-24: «det skal kun være mat og drikke som måles her
  // mot salget i fjor». Avdeling 120 + 140, som er nøyaktig de to
  // fanene ved siden av.
  //
  // `omsetning` hentes derfor ikke lenger: ingenting her skal kunne
  // summere hele butikken ved et uhell.
  let vekst: HjemData['vekst'] = null
  const rader = (salg ?? []) as { dato: string; omsetning: number | null; mat_omsetning: number | null; kald_drikke_omsetning: number | null }[]
  if (rader.length > 0) {
    const sisteDato = rader[0].dato
    const mndStart = `${sisteDato.slice(0, 7)}-01`

    const beregn = (felt: (r: (typeof rader)[number]) => number): VekstMetrikk => {
      const dagsrader = rader.map((r) => ({ dato: r.dato, verdi: felt(r) }))
      const m = new Map(dagsrader.map((r) => [r.dato, r.verdi]))

      // STREAK: dager på rad over fjorårets SAMME UKEDAG, ikke samme
      // dato. Stopper når fjorårsdagen mangler — uten den sjekken teller
      // en manglende dag som en seier.
      let streak = 0
      for (let i = 0; ; i++) {
        const d = minusDager(sisteDato, i)
        if (!m.has(d)) break
        const ifjor = m.get(minusDager(d, 364))
        if (ifjor == null) break
        if ((m.get(d) ?? 0) > ifjor) streak++
        else break
      }

      return {
        // Ett vindu på én dag: siste salgsdag mot fjorårets samme ukedag.
        sisteDag: sammenlikn(dagsrader, sisteDato, sisteDato),
        maanedHittil: sammenlikn(dagsrader, sisteDato, mndStart),
        streak,
      }
    }

    vekst = {
      sisteDato,
      metrikker: {
        matOgDrikke: beregn((r) => (r.mat_omsetning ?? 0) + (r.kald_drikke_omsetning ?? 0)),
        mat: beregn((r) => r.mat_omsetning ?? 0),
        kaldDrikke: beregn((r) => r.kald_drikke_omsetning ?? 0),
      },
    }
  }

  return { skills, premie, produksjon, vekst }
}
