import 'server-only'
import type Anthropic from '@anthropic-ai/sdk'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { BUTIKKSJEF_KOSTNAD_KODER } from '@/lib/regnskap-tilgang'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>
export type VerktoyKtx = { supabase: Klient; bruker: InnloggetBruker }

// Hvert verktøy: JSON-schema (det Claude ser) + en kjør-funksjon som henter/
// endrer data via brukerens Supabase-klient. RLS sørger for at en butikksjef
// kun når egne stasjoner — AI-en kan aldri omgå tenant-/rollegrensen (§8).
// kunAdmin-verktøy (handling) tilbys bare til eier.
export type Verktoy = {
  schema: Anthropic.Tool
  kunAdmin?: boolean
  kjor: (input: Record<string, unknown>, ktx: VerktoyKtx) => Promise<unknown>
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
    async kjor(_input, { supabase }) {
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
        properties: { dato: { type: 'string', description: 'ISO-dato YYYY-MM-DD (valgfri)' } },
      },
    },
    async kjor(input, { supabase }) {
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
        properties: { periode: { type: 'string', description: 'YYYY-MM (valgfri)' } },
      },
    },
    async kjor(input, { supabase, bruker }) {
      // Butikksjef ser kun EGEN stasjon + påvirkbare kostnader (aldri cluster/resultat).
      const erButikksjef = bruker.rolle === 'butikksjef'
      let periode = input.periode ? `${input.periode}-01` : null
      if (!periode) {
        let q = supabase.from('regnskapslinjer').select('periode').order('periode', { ascending: false }).limit(1)
        q = erButikksjef ? q.not('stasjon_id', 'is', null) : q.is('stasjon_id', null)
        const { data } = await q.maybeSingle<{ periode: string }>()
        periode = data?.periode ?? null
      }
      if (!periode) return { feil: 'Ingen regnskapsdata funnet.' }

      if (erButikksjef) {
        const { data } = await supabase
          .from('regnskapslinjer').select('stasjon_id, seksjon, kode, post, regnskap, budsjett, avvik, index_pct')
          .eq('periode', periode).not('stasjon_id', 'is', null).order('sortering')
          .overrideTypes<{ stasjon_id: string; seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }[]>()
        const navn = await stasjonsNavn(supabase)
        const synlig = (data ?? []).filter((l) => l.seksjon === 'omsetning' || l.seksjon === 'bruttofortjeneste' || (l.seksjon === 'driftskostnader' && BUTIKKSJEF_KOSTNAD_KODER.has(l.kode ?? '')))
        return {
          periode, niva: 'din stasjon',
          merk: 'Du ser kun omsetning, bruttofortjeneste og påvirkbare kostnader for din egen stasjon. Royalty, husleie, finans, varekost-detaljer og resultat ligger på admin-nivå — be Robert om det.',
          linjer: synlig.map((l) => ({ stasjon: navn.get(l.stasjon_id), seksjon: l.seksjon, post: l.post, regnskap: l.regnskap, budsjett: l.budsjett, avvik: l.avvik, index_pct: l.index_pct })),
        }
      }

      const { data } = await supabase
        .from('regnskapslinjer').select('seksjon, kode, post, regnskap, budsjett, avvik, index_pct')
        .eq('periode', periode).is('stasjon_id', null).order('sortering')
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
    async kjor(input, { supabase }) {
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
    async kjor(input, { supabase }) {
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

  list_konkurranser: {
    schema: {
      name: 'list_konkurranser',
      description: 'List pågående og avsluttede konkurranser mellom stasjonene.',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, { supabase }) {
      const { data } = await supabase
        .from('konkurranser')
        .select('id, navn, kpi, periode_start, periode_slutt, premie_kr, status')
        .is('slettet_tid', null)
        .order('opprettet_tid', { ascending: false })
        .limit(20)
      return data ?? []
    },
  },

  hent_fokus_status: {
    schema: {
      name: 'hent_fokus_status',
      description:
        'Hent aktive fokuspunkter (satt etter regnskapet) per stasjon, OG om svinn-tallene (kast + usynlig manko) knyttet til fokuset har bedret seg siden fokusmåneden. Bruk når noen spør «hvordan går det», om oppfølging, eller hvordan det ligger an med fokuset. RLS: admin ser alle stasjoner, butikksjef kun egne.',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, { supabase }) {
      const { data: sf } = await supabase
        .from('fokuspunkter').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
      if (!sf) return { feil: 'Ingen fokuspunkter ennå.' }
      const fokusPeriode = sf.periode
      const navn = await stasjonsNavn(supabase)
      const { data: punkter } = await supabase
        .from('fokuspunkter').select('stasjon_id, type, kategori, tittel, tekst').eq('periode', fokusPeriode)
        .overrideTypes<{ stasjon_id: string; type: string; kategori: string | null; tittel: string | null; tekst: string }[]>()

      const { data: sp } = await supabase
        .from('regnskap_usynlig_svinn').select('periode').order('periode', { ascending: false }).limit(1).maybeSingle<{ periode: string }>()
      const sistePeriode = sp?.periode ?? fokusPeriode

      const svinnFor = async (periode: string) => {
        const { data } = await supabase
          .from('regnskap_usynlig_svinn').select('stasjon_id, kast, usynlig_kr').eq('periode', periode).is('slettet_tid', null)
          .overrideTypes<{ stasjon_id: string; kast: number | null; usynlig_kr: number | null }[]>()
        const m = new Map<string, { kast: number; manko: number }>()
        for (const r of data ?? []) {
          const e = m.get(r.stasjon_id) ?? { kast: 0, manko: 0 }
          e.kast += r.kast ?? 0
          if ((r.usynlig_kr ?? 0) > 0) e.manko += r.usynlig_kr ?? 0
          m.set(r.stasjon_id, e)
        }
        return m
      }
      const [da, naa] = await Promise.all([
        svinnFor(fokusPeriode),
        sistePeriode !== fokusPeriode ? svinnFor(sistePeriode) : Promise.resolve(null),
      ])

      const perStasjon = new Map<string, { type: string; kategori: string | null; tittel: string | null; tekst: string }[]>()
      for (const p of punkter ?? []) {
        const e = perStasjon.get(p.stasjon_id) ?? []
        e.push({ type: p.type, kategori: p.kategori, tittel: p.tittel, tekst: p.tekst })
        perStasjon.set(p.stasjon_id, e)
      }
      const rund = (v?: { kast: number; manko: number }) => (v ? { kast: Math.round(v.kast), usynlig_manko: Math.round(v.manko) } : null)
      return {
        fokus_periode: fokusPeriode,
        siste_periode: sistePeriode,
        har_nyere_tall: sistePeriode !== fokusPeriode,
        merk: 'usynlig_manko og kast: lavere = bedre. + usynlig = manko (penger borte), kast = synlig svinn.',
        per_stasjon: [...perStasjon.entries()].map(([sid, pts]) => ({
          stasjon: navn.get(sid),
          fokuspunkter: pts,
          svinn_fokusmnd: rund(da.get(sid)),
          svinn_naa: naa ? rund(naa.get(sid)) : null,
        })),
      }
    },
  },

  // --- Handling-verktøy (kun eier, to-stegs bekreftelse §8A) ---
  opprett_konkurranse: {
    kunAdmin: true,
    schema: {
      name: 'opprett_konkurranse',
      description:
        'Opprett en konkurranse mellom stasjoner. To-stegs bekreftelse: kall først UTEN bekreftet for å vise oppsummering, deretter MED bekreftet=true når brukeren har sagt ja.',
      input_schema: {
        type: 'object',
        properties: {
          navn: { type: 'string' },
          kpi: { type: 'string', description: 'Hva måles, f.eks. "omsetning pølse"' },
          varegruppe_kode: { type: 'string', description: 'Varegruppekode som måles (utelat = total omsetning)' },
          maaltype: { type: 'string', enum: ['omsetning', 'antall'] },
          butikknummer: { type: 'array', items: { type: 'string' }, description: 'Deltakende stasjoner (utelat = alle)' },
          periode_start: { type: 'string', description: 'YYYY-MM-DD' },
          periode_slutt: { type: 'string', description: 'YYYY-MM-DD' },
          premie_kr: { type: 'number' },
          bekreftet: { type: 'boolean' },
        },
        required: ['navn', 'kpi', 'periode_start', 'periode_slutt'],
      },
    },
    async kjor(input, { supabase, bruker }) {
      const { navn, kpi, periode_start, periode_slutt, premie_kr } = input
      if (!input.bekreftet) {
        return {
          venter_paa_bekreftelse: true,
          oppsummering: `Opprette konkurranse «${navn}»: ${kpi}, ${periode_start}–${periode_slutt}${premie_kr ? `, premie ${premie_kr} kr` : ''}. Bekreft for å opprette.`,
        }
      }
      const numre = Array.isArray(input.butikknummer) ? (input.butikknummer as string[]) : []
      const stasjonIder: string[] = []
      for (const n of numre) {
        const id = await nrTilId(supabase, n)
        if (id) stasjonIder.push(id)
      }
      const { data, error } = await supabase
        .from('konkurranser')
        .insert({
          retailer_id: bruker.retailerId,
          navn, kpi,
          varegruppe_kode: (input.varegruppe_kode as string) ?? null,
          maaltype: (input.maaltype as string) ?? 'omsetning',
          stasjon_ids: stasjonIder,
          periode_start, periode_slutt,
          premie_kr: (premie_kr as number) ?? null,
          opprettet_av: bruker.id,
        })
        .select('id')
        .single()
      if (error) return { feil: error.message }
      return { opprettet: true, id: data.id }
    },
  },

  kar_vinner: {
    kunAdmin: true,
    schema: {
      name: 'kar_vinner',
      description:
        'Mål en konkurranse fra daglig salg og kår vinner. To-stegs bekreftelse: kall først UTEN bekreftet for å vise stillingen, deretter MED bekreftet=true for å avslutte og sette vinner.',
      input_schema: {
        type: 'object',
        properties: {
          konkurranse_id: { type: 'string' },
          bekreftet: { type: 'boolean' },
        },
        required: ['konkurranse_id'],
      },
    },
    async kjor(input, { supabase }) {
      const id = input.konkurranse_id as string
      const { data: k } = await supabase
        .from('konkurranser')
        .select('id, navn, varegruppe_kode, maaltype, stasjon_ids, periode_start, periode_slutt, status')
        .eq('id', id)
        .maybeSingle<{
          id: string; navn: string; varegruppe_kode: string | null; maaltype: string
          stasjon_ids: string[]; periode_start: string; periode_slutt: string; status: string
        }>()
      if (!k) return { feil: 'Fant ikke konkurransen.' }

      // Mål fra daglig_salg (AI gjetter aldri, §11)
      let q = supabase
        .from('daglig_salg')
        .select('stasjon_id, omsetning_eks_mva, antall')
        .gte('dato', k.periode_start)
        .lte('dato', k.periode_slutt)
        .is('slettet_tid', null)
      if (k.varegruppe_kode) q = q.eq('varegruppe_kode', k.varegruppe_kode)
      if (k.stasjon_ids.length > 0) q = q.in('stasjon_id', k.stasjon_ids)
      const { data: salg } = await q.overrideTypes<{ stasjon_id: string; omsetning_eks_mva: number | null; antall: number | null }[]>()

      const navn = await stasjonsNavn(supabase)
      const per = new Map<string, number>()
      for (const r of salg ?? []) {
        const v = k.maaltype === 'antall' ? (r.antall ?? 0) : (r.omsetning_eks_mva ?? 0)
        per.set(r.stasjon_id, (per.get(r.stasjon_id) ?? 0) + v)
      }
      const stilling = [...per.entries()]
        .map(([sid, verdi]) => ({ stasjon_id: sid, stasjon: navn.get(sid), verdi: Math.round(verdi) }))
        .sort((a, b) => b.verdi - a.verdi)

      if (stilling.length === 0) return { feil: 'Ingen salgsdata i konkurranseperioden ennå.' }
      const vinner = stilling[0]

      if (!input.bekreftet) {
        return { venter_paa_bekreftelse: true, stilling, foreslaatt_vinner: vinner.stasjon }
      }
      await supabase
        .from('konkurranser')
        .update({ status: 'avsluttet', vinner_stasjon_id: vinner.stasjon_id })
        .eq('id', id)
      return { kaaret: true, vinner: vinner.stasjon, stilling }
    },
  },

  list_oppgaver: {
    schema: {
      name: 'list_oppgaver',
      description: 'List åpne oppgaver (per stasjon).',
      input_schema: { type: 'object', properties: {} },
    },
    async kjor(_input, { supabase }) {
      const navn = await stasjonsNavn(supabase)
      const { data } = await supabase
        .from('oppgaver')
        .select('id, stasjon_id, tittel, frist, status')
        .is('slettet_tid', null)
        .eq('status', 'apen')
        .order('frist', { nullsFirst: false })
        .limit(30)
      return (data ?? []).map((o) => ({ ...o, stasjon: navn.get(o.stasjon_id) }))
    },
  },

  opprett_oppgave: {
    schema: {
      name: 'opprett_oppgave',
      description: 'Opprett en oppgave for en stasjon (f.eks. «bestill mer kaffe»). Krever butikknummer og tittel.',
      input_schema: {
        type: 'object',
        properties: {
          butikknummer: { type: 'string', description: '4-sifret butikknummer' },
          tittel: { type: 'string' },
          beskrivelse: { type: 'string' },
          frist: { type: 'string', description: 'YYYY-MM-DD (valgfri)' },
        },
        required: ['butikknummer', 'tittel'],
      },
    },
    async kjor(input, { supabase, bruker }) {
      const stasjonId = await nrTilId(supabase, input.butikknummer as string)
      if (!stasjonId) return { feil: 'Ukjent butikknummer.' }
      const { data, error } = await supabase
        .from('oppgaver')
        .insert({
          retailer_id: bruker.retailerId,
          stasjon_id: stasjonId,
          tittel: input.tittel as string,
          beskrivelse: (input.beskrivelse as string) ?? null,
          frist: (input.frist as string) || null,
          opprettet_av: bruker.id,
        })
        .select('id')
        .single()
      if (error) return { feil: error.message }
      return { opprettet: true, id: data.id }
    },
  },
}

export function verktoyForRolle(erAdmin: boolean): Anthropic.Tool[] {
  return Object.values(VERKTOY)
    .filter((v) => erAdmin || !v.kunAdmin)
    .map((v) => v.schema)
}
