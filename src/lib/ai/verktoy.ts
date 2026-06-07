import 'server-only'
import type Anthropic from '@anthropic-ai/sdk'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

// Hvert verktøy: JSON-schema (det Claude ser) + en kjør-funksjon som henter
// data via brukerens Supabase-klient. RLS sørger for at en butikksjef kun når
// egne stasjoner — AI-en kan aldri omgå tenant-/rollegrensen (§8).
export type Verktoy = {
  schema: Anthropic.Tool
  kjor: (input: Record<string, unknown>, supabase: Klient) => Promise<unknown>
}

async function stasjonsNavn(supabase: Klient) {
  const { data } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn')
    .is('slettet_tid', null)
  return new Map((data ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
}

async function nrTilId(supabase: Klient, butikknummer?: string) {
  if (!butikknummer) return null
  const { data } = await supabase
    .from('stasjoner')
    .select('id')
    .eq('butikknummer', butikknummer)
    .is('slettet_tid', null)
    .maybeSingle<{ id: string }>()
  return data?.id ?? null
}

async function sisteDato(supabase: Klient, tabell: string): Promise<string | null> {
  const { data } = await supabase
    .from(tabell)
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()
  return data?.dato ?? null
}

export const VERKTOY: Record<string, Verktoy> = {
  list_stasjoner: {
    schema: {
      name: 'list_stasjoner',
      description:
        'List alle stasjonene brukeren har tilgang til (butikknummer, navn, type). Bruk for å finne butikknummer før andre oppslag.',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, supabase) {
      const { data } = await supabase
        .from('stasjoner')
        .select('butikknummer, navn, stasjonstype')
        .is('slettet_tid', null)
        .order('butikknummer')
      return data ?? []
    },
  },

  hent_salg: {
    schema: {
      name: 'hent_salg',
      description:
        'Hent daglig salg (omsetning eks. mva, antall) per stasjon og topp varegrupper for en dato. Utelat dato for siste tilgjengelige dag.',
      input_schema: {
        type: 'object',
        properties: {
          dato: { type: 'string', description: 'ISO-dato YYYY-MM-DD (valgfri)' },
        },
      },
    },
    async kjor(input, supabase) {
      const dato = (input.dato as string) || (await sisteDato(supabase, 'v_salg_per_stasjon_dag'))
      if (!dato) return { feil: 'Ingen salgsdata funnet.' }
      const navn = await stasjonsNavn(supabase)
      const [{ data: stasjon }, { data: varegrupper }] = await Promise.all([
        supabase.from('v_salg_per_stasjon_dag').select('stasjon_id, omsetning, antall, mat_omsetning').eq('dato', dato),
        supabase.from('v_salg_per_varegruppe_dag').select('varegruppe_navn, omsetning, antall').eq('dato', dato).order('omsetning', { ascending: false }).limit(8),
      ])
      return {
        dato,
        per_stasjon: (stasjon ?? []).map((r) => ({ stasjon: navn.get(r.stasjon_id), ...r })),
        topp_varegrupper: varegrupper ?? [],
      }
    },
  },

  hent_regnskap: {
    schema: {
      name: 'hent_regnskap',
      description:
        'Hent regnskap/resultat (omsetning, bruttofortjeneste, driftskostnader, resultat per regnskapskode med regnskap vs budsjett og avvik) for en måned. Utelat periode for siste.',
      input_schema: {
        type: 'object',
        properties: {
          periode: { type: 'string', description: 'YYYY-MM (valgfri)' },
        },
      },
    },
    async kjor(input, supabase) {
      let periode = input.periode ? `${input.periode}-01` : null
      if (!periode) {
        const { data } = await supabase.from('regnskapslinjer').select('periode').is('stasjon_id', null).order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
        periode = data?.periode ?? null
      }
      if (!periode) return { feil: 'Ingen regnskapsdata funnet.' }
      const { data } = await supabase
        .from('regnskapslinjer')
        .select('seksjon, kode, post, regnskap, budsjett, avvik, index_pct')
        .eq('periode', periode)
        .is('stasjon_id', null)
        .order('sortering')
      return { periode, linjer: data ?? [] }
    },
  },

  hent_svinn: {
    schema: {
      name: 'hent_svinn',
      description: 'Hent synlig svinn (kroner og antall) per stasjon for en dato. Utelat dato for siste.',
      input_schema: {
        type: 'object',
        properties: { dato: { type: 'string', description: 'YYYY-MM-DD (valgfri)' } },
      },
    },
    async kjor(input, supabase) {
      const dato = (input.dato as string) || (await sisteDato(supabase, 'synlig_svinn'))
      if (!dato) return { feil: 'Ingen svinndata funnet.' }
      const navn = await stasjonsNavn(supabase)
      const { data } = await supabase.from('synlig_svinn').select('stasjon_id, nettopris_total, antall').eq('dato', dato)
      const per = new Map<string, { sum: number; antall: number }>()
      for (const r of data ?? []) {
        const p = per.get(r.stasjon_id) ?? { sum: 0, antall: 0 }
        p.sum += r.nettopris_total ?? 0
        p.antall += r.antall ?? 0
        per.set(r.stasjon_id, p)
      }
      return { dato, per_stasjon: [...per.entries()].map(([id, p]) => ({ stasjon: navn.get(id), ...p })) }
    },
  },

  hent_timesalg: {
    schema: {
      name: 'hent_timesalg',
      description: 'Hent salg pr time for én stasjon på en dato (heatmap-data, til bemanning). Krever butikknummer.',
      input_schema: {
        type: 'object',
        properties: {
          butikknummer: { type: 'string', description: '4-sifret butikknummer' },
          dato: { type: 'string', description: 'YYYY-MM-DD (valgfri)' },
        },
        required: ['butikknummer'],
      },
    },
    async kjor(input, supabase) {
      const stasjonId = await nrTilId(supabase, input.butikknummer as string)
      if (!stasjonId) return { feil: 'Ukjent butikknummer.' }
      const dato = (input.dato as string) || (await sisteDato(supabase, 'timesalg'))
      if (!dato) return { feil: 'Ingen timesalgsdata funnet.' }
      const { data } = await supabase
        .from('timesalg')
        .select('time, salg, antall_kunder')
        .eq('stasjon_id', stasjonId)
        .eq('dato', dato)
      return { dato, butikknummer: input.butikknummer, timer: data ?? [] }
    },
  },
}

export const VERKTOY_SCHEMA: Anthropic.Tool[] = Object.values(VERKTOY).map((v) => v.schema)
