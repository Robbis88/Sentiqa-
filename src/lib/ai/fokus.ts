import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import * as z from 'zod'
import { env } from '@/lib/env'
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { BUTIKKSJEF_KOSTNAD_KODER, BUTIKKSJEF_PERSONAL_KODER } from '@/lib/regnskap-tilgang'
import { SKJUL_OMS_KODER } from '@/lib/avdelinger'

// Auto-fokus er ikke-sanntid → Sonnet holder (PROSJEKT.md §8; batch-API senere).
const MODELL = 'claude-sonnet-4-6'

const PunktSchema = z.object({
  tittel: z.string(),
  beskrivelse: z.string(),
  kategori: z.enum(['svinn', 'kostnad', 'omsetning', 'brf', 'positivt']),
})
const FokusSchema = z.object({
  forbedring: z.array(PunktSchema),
  positivt: z.array(PunktSchema),
})
type Punkt = z.infer<typeof PunktSchema>

type Klient = SupabaseClient
type Linje = { post: string; kode: string | null; regnskap: number | null; budsjett: number | null; index_pct: number | null }
type Svinn = { kode: string | null; navn: string; usynlig_kr: number | null; kast: number | null }

async function forStasjon(
  anthropic: Anthropic,
  supabase: Klient,
  stasjonId: string,
  navn: string,
  periode: string,
): Promise<{ forbedring: Punkt[]; positivt: Punkt[] } | null> {
  const [{ data: omsRaw }, { data: brfRaw }, { data: svinn }, { data: kost }] = await Promise.all([
    supabase.from('regnskapslinjer').select('post, kode, regnskap, budsjett, index_pct').eq('periode', periode).eq('stasjon_id', stasjonId).eq('seksjon', 'omsetning').overrideTypes<Linje[]>(),
    supabase.from('regnskapslinjer').select('post, kode, regnskap, budsjett, index_pct').eq('periode', periode).eq('stasjon_id', stasjonId).eq('seksjon', 'bruttofortjeneste').overrideTypes<Linje[]>(),
    supabase.from('regnskap_usynlig_svinn').select('kode, navn, usynlig_kr, kast').eq('periode', periode).eq('stasjon_id', stasjonId).is('slettet_tid', null).overrideTypes<Svinn[]>(),
    supabase.from('regnskapslinjer').select('post, kode, regnskap, budsjett').eq('periode', periode).eq('stasjon_id', stasjonId).eq('seksjon', 'driftskostnader').overrideTypes<Linje[]>(),
  ])
  if (!omsRaw || omsRaw.length === 0) return null
  // Drivstoff, pant og «40 CR»-totalen utelates — ikke butikkdrift / dobbelteller.
  const oms = omsRaw.filter((l) => !SKJUL_OMS_KODER.has(l.kode ?? ''))
  const brf = (brfRaw ?? []).filter((l) => !SKJUL_OMS_KODER.has(l.kode ?? ''))

  // Kun butikksjef-påvirkbare kostnader (personal samlet) — aldri royalty/husleie/finans.
  const paavirkbar = (kost ?? []).filter((l) => BUTIKKSJEF_KOSTNAD_KODER.has(l.kode ?? ''))
  const personalSum = paavirkbar.filter((l) => BUTIKKSJEF_PERSONAL_KODER.has(l.kode ?? '')).reduce((a, l) => ({ r: a.r + (l.regnskap ?? 0), b: a.b + (l.budsjett ?? 0) }), { r: 0, b: 0 })
  const kostLinjer = [
    ...(personalSum.r || personalSum.b ? [{ navn: 'Personalkostnad', r: personalSum.r, b: personalSum.b }] : []),
    ...paavirkbar.filter((l) => !BUTIKKSJEF_PERSONAL_KODER.has(l.kode ?? '')).map((l) => ({ navn: l.post, r: l.regnskap ?? 0, b: l.budsjett ?? 0 })),
  ]
  const kostTekst = kostLinjer.length
    ? kostLinjer.map((k) => `${k.navn}: ${Math.round(k.r)} kr av budsjett ${Math.round(k.b)} kr (${k.b > 0 ? (((k.r - k.b) / k.b) * 100).toFixed(0) : '0'} % avvik)`).join('\n')
    : 'Ingen kostnadsdata.'

  // Aggreger svinn (kast + usynlig) pr avdeling (kode 12010 → avd 120).
  const svinnPerAvd = new Map<number, { kast: number; usynlig: number }>()
  for (const s of svinn ?? []) {
    const k = Number(s.kode)
    if (!Number.isFinite(k)) continue
    const avd = Math.floor(k / 100)
    const rad = svinnPerAvd.get(avd) ?? { kast: 0, usynlig: 0 }
    rad.kast += s.kast ?? 0
    rad.usynlig += s.usynlig_kr ?? 0
    svinnPerAvd.set(avd, rad)
  }

  const avdTekst = oms.map((l) => {
    const avd = Number(l.kode)
    const sv = svinnPerAvd.get(avd)
    const svDel = sv
      ? `; kast (synlig svinn) ${Math.round(sv.kast)} kr; usynlig ${Math.round(sv.usynlig)} kr (${sv.usynlig > 0 ? 'MANKO' : 'overskudd'})`
      : ''
    return `${l.post}: omsetning ${Math.round(l.regnskap ?? 0)} kr av budsjett ${Math.round(l.budsjett ?? 0)} kr (${(l.index_pct ?? 0).toFixed(1)} % avvik)${svDel}`
  }).join('\n')

  const totOms = oms.reduce((s, l) => s + (l.regnskap ?? 0), 0)
  const totOmsB = oms.reduce((s, l) => s + (l.budsjett ?? 0), 0)
  const totBrf = brf.reduce((s, l) => s + (l.regnskap ?? 0), 0)
  const totBrfB = brf.reduce((s, l) => s + (l.budsjett ?? 0), 0)

  const resp = await anthropic.messages.parse({
    model: MODELL,
    max_tokens: 1536,
    system:
      'Du er driftsrådgiver for en butikksjef på én bensinstasjon. Norsk bokmål. Vennlig, men konkret — bruk avdelingsnavn, kroner og %-avvik. ALDRI finn på tall; bruk kun tallene du får.\n' +
      'FORTEGN usynlig svinn: positivt tall = MANKO (penger/varer borte etter telling = dårlig). Negativt tall = OVERSKUDD (uforklart, oftest feilslag) — IKKE flagg overskudd som en forbedring. Kast = synlig svinn: positivt = kastet/svunnet (dårlig).\n' +
      'LØNN måles MOT LØNNSBUDSJETTET (St1 setter budsjettet) — ALDRI mot omsetning eller bruttofortjeneste. To viktige poeng: (a) bruker stasjonen MER lønn enn budsjett → be dem skjerpe bemanning/vaktplan; (b) bruker de (nær) hele lønnsbudsjettet MEN bruttofortjenesten ligger under budsjett → bemanningen leverer ikke nok, det er et forbedringspunkt.\n' +
      'Lag NØYAKTIG 3 forbedringspunkter — KUN på: høyt kast (synlig svinn), usynlig MANKO (positivt tall), kostnader over budsjett, lønn over lønnsbudsjett, eller lønnsbudsjett brukt uten å treffe brutto. ALDRI klag på lav omsetning eller BRF i seg selv (kun via lønn-koblingen over). Drivstoff og pant skal aldri med.\n' +
      'Lag NØYAKTIG 3 positive punkter — lavt/negativt svinn, kostnad eller lønn godt under budsjett, eller solid omsetning/BRF mot budsjett (her ER det lov å rose).\n' +
      'Hvert punkt: kort tittel + én konkret setning (beskrivelse) med tall, og riktig kategori.',
    messages: [{
      role: 'user',
      content:
        `Stasjon: ${navn}. Periode-tall (eks. drivstoff og pant):\n` +
        `Omsetning ${Math.round(totOms)} kr av budsjett ${Math.round(totOmsB)} kr. Bruttofortjeneste ${Math.round(totBrf)} kr av budsjett ${Math.round(totBrfB)} kr.\n` +
        `Lønn (personalkostnad) ${Math.round(personalSum.r)} kr mot lønnsbudsjett ${Math.round(personalSum.b)} kr.\n\n` +
        `Per avdeling:\n${avdTekst}\n\n` +
        `Påvirkbare kostnader:\n${kostTekst}\n\n` +
        'Gi nøyaktig 3 forbedringspunkter og nøyaktig 3 positive punkter.',
    }],
    output_config: { format: zodOutputFormat(FokusSchema) },
  })

  return resp.parsed_output ?? null
}

// Genererer og lagrer fokuspunkter for alle stasjoner (siste regnskapsperiode)
// for ÉN kjede. Tar klient + retailerId → fungerer både fra import (auto) og UI.
export async function genererFokusForRetailer(
  supabase: Klient,
  retailerId: string,
): Promise<{ ok: true; antall: number; periode: string } | { ok: false; grunn: string }> {
  if (!env.ANTHROPIC_API_KEY) {
    return { ok: false, grunn: 'AI er ikke aktivert (mangler ANTHROPIC_API_KEY).' }
  }

  const { data: siste } = await supabase
    .from('regnskapslinjer')
    .select('periode')
    .eq('retailer_id', retailerId)
    .not('stasjon_id', 'is', null)
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()
  if (!siste) return { ok: false, grunn: 'Ingen regnskap per stasjon ennå. Behandle en regnskapsfil først.' }
  const periode = siste.periode

  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .eq('retailer_id', retailerId)
    .is('slettet_tid', null)

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })

  // Erstatt periodens fokuspunkter (idempotent).
  await supabase.from('fokuspunkter').delete().eq('retailer_id', retailerId).eq('periode', periode)

  const resultater = await Promise.all(
    (stasjoner ?? []).map(async (s) => {
      const pts = await forStasjon(anthropic, supabase, s.id, `${s.butikknummer} ${s.navn}`, periode)
      if (!pts) return []
      const lag = (p: Punkt, type: 'forbedring' | 'positivt') => ({
        retailer_id: retailerId, stasjon_id: s.id, periode, type,
        tekst: p.beskrivelse, tittel: p.tittel, kategori: p.kategori, opprettet_av_bot: true,
      })
      return [...pts.forbedring.slice(0, 3).map((p) => lag(p, 'forbedring')), ...pts.positivt.slice(0, 3).map((p) => lag(p, 'positivt'))]
    }),
  )

  const rader = resultater.flat()
  if (rader.length > 0) {
    const { error } = await supabase.from('fokuspunkter').insert(rader)
    if (error) return { ok: false, grunn: error.message }
  }
  return { ok: true, antall: rader.length, periode }
}

// UI-knappen: kjør for innlogget eiers egen kjede.
export async function genererAlleFokus(): Promise<
  { ok: true; antall: number; periode: string } | { ok: false; grunn: string }
> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { ok: false, grunn: 'Bare eier kan generere fokuspunkter.' }
  }
  const supabase = await lagSupabaseServerKlient()
  return genererFokusForRetailer(supabase, bruker.retailerId)
}
