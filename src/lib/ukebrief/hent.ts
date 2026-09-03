import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { finnUtsolgt, type Kandidatrad } from '@/lib/utsolgt'
import { fordelBp, motpartsvindu, type Dagsrad } from '@/lib/salg/bp-per-dag'
import { delVakt, LONNSART } from '@/lib/lonn/tidsband'
import { skjemabilde, type Skjemabilde, type Skjemapost } from './skjema'
import type { Ukedata } from './type'

// =====================================================================
// Henter én ukes data for én stasjon.
//
// Alt her er lesing. Regelen om hva som blir et signal ligger i `bygg.ts`
// og er ren — så en brief kan etterprøves uten database. Denne fila har
// bare én jobb: å ikke lyve om hva den fant.
//
// Skillet betyr noe to steder. `treff: null` og `ukesramme: null` er
// IKKE nuller: de sier «ikke målt», og `bygg.ts` flytter dem til «hva vi
// ikke vet» i stedet for å regne på dem. Skrev vi 0 her, ville briefen
// meldt om 0 % treff og en ramme stasjonen sprengte med alt den gjorde.
// =====================================================================

type Klient = SupabaseClient

function leggTil(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

/** Månedene («YYYY-MM») uken berører. En uke kan ligge i to. */
function maanedeneI(mandag: string): string[] {
  const ut = new Set<string>()
  for (let i = 0; i < 7; i++) ut.add(leggTil(mandag, i).slice(0, 7))
  return [...ut]
}

function dageneIUken(mandag: string): string[] {
  return Array.from({ length: 7 }, (_, i) => leggTil(mandag, i))
}

type AvdRad = { avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number; brutto: number }

async function aggreger(supabase: Klient, stasjonId: string, fra: string, til: string): Promise<AvdRad[]> {
  const { data, error } = await supabase.rpc('uke_avdeling_aggregat', { p_stasjon: stasjonId, p_fra: fra, p_til: til })
  // Svelger vi denne, blir svaret `[]`, og sida skriver «Ingen data for
  // denne uken» — en sann setning om noe helt annet enn det som skjedde.
  // Det er nøyaktig formen `rpc-feil.test.ts` finnes for.
  if (error) throw new Error(`uke_avdeling_aggregat feilet: ${error.message}`)
  return (data ?? []) as AvdRad[]
}

async function utsolgtKandidater(supabase: Klient, stasjonId: string): Promise<Kandidatrad[]> {
  const { data, error } = await supabase.rpc('utsolgt_kandidater', { p_stasjon: stasjonId, p_dager: 35 })
  if (error) throw new Error(`utsolgt_kandidater feilet: ${error.message}`)
  return (data ?? []) as Kandidatrad[]
}

/**
 * Ukens andel av BP.
 *
 * Månedens BP fordeles på dagene med `fordelBp` — samme funksjon som
 * salgssiden, etter ukedagsmedianen i motpartsvinduet. Så summeres bare
 * dagene som ligger i uken. Ligger uken i to måneder, gjøres det for
 * begge og summeres.
 *
 * Finnes det ingen BP for en av månedene, returneres `null` for HELE
 * uken. En halv uke mot budsjett er verre enn ingen: den ser ut som et
 * krav stasjonen bommet på, og er egentlig bare de dagene vi hadde tall for.
 */
async function bpForUken(supabase: Klient, stasjonId: string, mandag: string): Promise<number | null> {
  const dager = new Set(dageneIUken(mandag))
  let sum = 0

  for (const maaned of maanedeneI(mandag)) {
    const { data: linjer } = await supabase
      .from('regnskapslinjer')
      .select('budsjett')
      .eq('periode', maaned)
      .eq('stasjon_id', stasjonId)
      .is('slettet_tid', null)
      .in('seksjon', ['omsetning', 'bp_omsetning'])
      .overrideTypes<{ budsjett: number | null }[]>()

    const bpMnd = (linjer ?? []).reduce((a, r) => a + (r.budsjett ?? 0), 0)
    if (bpMnd <= 0) return null

    const vindu = motpartsvindu(maaned)
    const { data: fjor } = await supabase
      .from('v_butikksalg')
      .select('dato, omsetning')
      .eq('stasjon_id', stasjonId)
      .gte('dato', vindu.fra)
      .lte('dato', vindu.til)
      .overrideTypes<{ dato: string; omsetning: number | null }[]>()

    const perDag = new Map<string, number>()
    for (const r of fjor ?? []) perDag.set(r.dato, (perDag.get(r.dato) ?? 0) + (r.omsetning ?? 0))
    const ifjor: Dagsrad[] = [...perDag].map(([dato, omsetning]) => ({ dato, omsetning }))

    for (const d of fordelBp(maaned, bpMnd, ifjor)) {
      if (dager.has(d.dato)) sum += d.bp
    }
  }
  return sum > 0 ? sum : null
}

/**
 * Timer stemplet i uken, og ukens andel av månedsrammen.
 *
 * Minuttene kommer fra `delVakt` — samme funksjon som lønnsfila og
 * lønnssiden. Regnet vi dem her, ville pausevinduet vært trukket fra to
 * steder med hver sin utregning.
 *
 * Rammen er FLATT fordelt på månedens dager. Bemanningsplanleggeren
 * fordeler etter ukedag og klokketime, som er riktigere — men den formen
 * handler om hvor timene skal ligge, ikke om hvor mange uken skal ha.
 * Flat fordeling er grov, og signalet er merket `indikasjon` nettopp
 * derfor.
 */
async function timerForUken(
  supabase: Klient, stasjonId: string, mandag: string,
): Promise<{ brukt: number; ukesramme: number | null }> {
  const sondag = leggTil(mandag, 6)
  const { data: stempler } = await supabase
    .from('v_stempling_aktiv')
    .select('dato, fra_tid, til_tid, pause_fra, pause_til')
    .eq('stasjon_id', stasjonId)
    .gte('dato', mandag)
    .lte('dato', sondag)
    .overrideTypes<{
      dato: string; fra_tid: string; til_tid: string
      pause_fra: string | null; pause_til: string | null
    }[]>()

  let minutter = 0
  for (const r of stempler ?? []) {
    minutter += delVakt({
      dato: r.dato,
      fraTid: r.fra_tid.slice(0, 5),
      tilTid: r.til_tid.slice(0, 5),
      pauseFraTid: r.pause_fra?.slice(0, 5) ?? null,
      pauseTilTid: r.pause_til?.slice(0, 5) ?? null,
    }).get(LONNSART.timelonn) ?? 0
  }

  let ramme = 0
  let mangler = false
  for (const maaned of maanedeneI(mandag)) {
    const [ar, mnd] = maaned.split('-').map(Number)
    const { data } = await supabase
      .from('bemanning_maned')
      .select('disponible_timer')
      .eq('stasjon_id', stasjonId).eq('ar', ar).eq('maned', mnd)
      .maybeSingle<{ disponible_timer: number }>()
    if (!data) { mangler = true; continue }
    const dagerIMnd = new Date(Date.UTC(ar, mnd, 0)).getUTCDate()
    const dagerAvUken = dageneIUken(mandag).filter((d) => d.startsWith(maaned)).length
    ramme += (data.disponible_timer / dagerIMnd) * dagerAvUken
  }

  return { brukt: minutter / 60, ukesramme: mangler ? null : ramme }
}

type SkjemaSvar = { skjema: Skjemabilde[]; kritiskeNei: number }

/**
 * Rutiner og sjekkpunkter for uken.
 *
 * Skjemaene hentes UTEN `slettet_tid is null`. En rutine som ble slettet
 * paa onsdag var et krav mandag og tirsdag, og aa filtrere den bort her
 * ville gjort mandagens prosent hoeyere enn den var. `skjemabilde()`
 * avgjoer hvilke dager hver av dem gjaldt.
 */
async function hentSkjema(
  supabase: Klient, stasjonId: string, mandag: string, sondag: string,
): Promise<SkjemaSvar> {
  const [rutiner, utforinger, punkter, svar] = await Promise.all([
    supabase.from('rutiner').select('opprettet_tid, slettet_tid')
      .eq('stasjon_id', stasjonId)
      .or(`slettet_tid.is.null,slettet_tid.gte.${mandag}`)
      .overrideTypes<{ opprettet_tid: string; slettet_tid: string | null }[]>(),
    supabase.from('rutine_utforinger').select('dato')
      .eq('stasjon_id', stasjonId).gte('dato', mandag).lte('dato', sondag)
      .overrideTypes<{ dato: string }[]>(),
    supabase.from('sjekkpunkter').select('opprettet_tid, slettet_tid')
      .eq('stasjon_id', stasjonId)
      .or(`slettet_tid.is.null,slettet_tid.gte.${mandag}`)
      .overrideTypes<{ opprettet_tid: string; slettet_tid: string | null }[]>(),
    supabase.from('sjekkpunkt_svar').select('dato, svar, sjekkpunkter!inner(kritisk)')
      .eq('stasjon_id', stasjonId).gte('dato', mandag).lte('dato', sondag)
      .overrideTypes<{ dato: string; svar: boolean; sjekkpunkter: { kritisk: boolean } }[]>(),
  ])

  const post = (r: { opprettet_tid: string; slettet_tid: string | null }): Skjemapost =>
    ({ opprettet: r.opprettet_tid, slettet: r.slettet_tid })

  const tell = (rader: { dato: string }[]) => {
    const m = new Map<string, number>()
    for (const r of rader) m.set(r.dato, (m.get(r.dato) ?? 0) + 1)
    return m
  }

  const skjema: Skjemabilde[] = []
  if ((rutiner.data ?? []).length > 0) {
    skjema.push(skjemabilde({
      navn: 'Rutiner', poster: (rutiner.data ?? []).map(post),
      utfortPerDato: tell(utforinger.data ?? []), ukeMandag: mandag,
    }))
  }
  if ((punkter.data ?? []).length > 0) {
    skjema.push(skjemabilde({
      navn: 'Sjekkpunkt', poster: (punkter.data ?? []).map(post),
      utfortPerDato: tell(svar.data ?? []), ukeMandag: mandag,
    }))
  }

  const kritiskeNei = (svar.data ?? []).filter((r) => !r.svar && r.sjekkpunkter?.kritisk).length
  return { skjema, kritiskeNei }
}

export async function hentUkedata(
  supabase: Klient,
  stasjon: { id: string; navn: string; butikknummer: string },
  mandag: string,
): Promise<Ukedata | null> {
  const sondag = leggTil(mandag, 6)
  const mandagIfjor = leggTil(mandag, -364)
  const sondagIfjor = leggTil(sondag, -364)

  const [naa, ifjor] = await Promise.all([
    aggreger(supabase, stasjon.id, mandag, sondag),
    aggreger(supabase, stasjon.id, mandagIfjor, sondagIfjor),
  ])
  if (naa.length === 0) return null

  const ifjorMap = new Map(ifjor.map((a) => [a.avdeling_kode ?? '', a]))
  let omsetning = 0
  const avdelinger = naa.map((a) => {
    const kode = a.avdeling_kode ?? ''
    const oms = Number(a.omsetning)
    const iF = Number(ifjorMap.get(kode)?.omsetning ?? 0)
    omsetning += oms
    return {
      kode, navn: a.avdeling_navn ?? kode, omsetning: oms, ifjor: iF,
      vekstPst: iF > 0 ? ((oms - iF) / iF) * 100 : 0,
    }
  })
  const omsetningIfjor = ifjor.reduce((t, a) => t + Number(a.omsetning), 0)

  const [bpUke, timer, utsolgtRaa, treffRader, meldinger, salgsdager, skjema] = await Promise.all([
    bpForUken(supabase, stasjon.id, mandag),
    timerForUken(supabase, stasjon.id, mandag),
    utsolgtKandidater(supabase, stasjon.id),
    supabase.from('prognose_treff').select('treff')
      .eq('stasjon_id', stasjon.id).gte('dato', mandag).lte('dato', sondag)
      .overrideTypes<{ treff: number | null }[]>(),
    supabase.from('tilbakemelding').select('alvorlighet, lest_tid')
      .eq('stasjon_id', stasjon.id)
      .gte('hendelse_tid', `${mandag}T00:00:00Z`).lte('hendelse_tid', `${sondag}T23:59:59Z`)
      .overrideTypes<{ alvorlighet: string; lest_tid: string | null }[]>(),
    supabase.from('v_butikksalg').select('dato')
      .eq('stasjon_id', stasjon.id).gte('dato', mandag).lte('dato', sondag)
      .overrideTypes<{ dato: string }[]>(),
    hentSkjema(supabase, stasjon.id, mandag, sondag),
  ])

  // Utsolgt regnes med SØNDAGEN som «i dag». Ser vi bakover fra dagens
  // dato på en uke som ligger tre uker tilbake, ville hullet vært lukket
  // for lengst og briefen sagt at ingenting skjedde.
  const utsolgt = finnUtsolgt(utsolgtRaa, sondag, 35)
    .filter((u) => u.til >= mandag && u.fra <= sondag)
    .map((u) => ({ navn: u.varenavn, taptKr: u.tapt_kr, dager: u.dager }))

  const treffTall = (treffRader.data ?? []).map((r) => r.treff).filter((t): t is number => t !== null)
  const treff = treffTall.length === 0 ? null : {
    antall: treffTall.length,
    snittTreffPst: treffTall.reduce((a, b) => a + b, 0) / treffTall.length,
  }

  const mld = meldinger.data ?? []
  const ALVORLIGE = new Set(['uhell', 'nestenuhell', 'krenkelse'])

  const dagerMedSalg = new Set((salgsdager.data ?? []).map((r) => r.dato))
  const manglerSalg = dageneIUken(mandag).filter((d) => !dagerMedSalg.has(d)).length

  return {
    stasjonNavn: `${stasjon.butikknummer} ${stasjon.navn}`,
    ukeMandag: mandag,
    omsetning,
    omsetningIfjor,
    bpUke,
    avdelinger,
    utsolgt,
    treff,
    timer,
    tilbakemeldinger: {
      antall: mld.length,
      ulest: mld.filter((m) => m.lest_tid === null).length,
      harAlvorlig: mld.some((m) => ALVORLIGE.has(m.alvorlighet)),
    },
    skjema: skjema.skjema,
    kritiskeNei: skjema.kritiskeNei,
    hull: manglerSalg > 0 ? [{ kilde: 'Salgsdata', dagerMangler: manglerSalg }] : [],
  }
}

/** Mandagene det finnes salg for, nyeste først — til ukevelgeren. */
export async function tilgjengeligeUker(
  supabase: Klient, stasjonId: string, antall = 12,
): Promise<string[]> {
  const { data } = await supabase
    .from('v_butikksalg')
    .select('dato').eq('stasjon_id', stasjonId)
    .order('dato', { ascending: false }).limit(antall * 14)
    .overrideTypes<{ dato: string }[]>()

  const mandager = new Set<string>()
  for (const r of data ?? []) {
    const d = new Date(`${r.dato}T12:00:00Z`)
    // 0 = søndag → mandagen er seks dager tilbake, ikke én dag fram.
    mandager.add(leggTil(r.dato, -((d.getUTCDay() + 6) % 7)))
  }
  return [...mandager].sort().reverse().slice(0, antall)
}
