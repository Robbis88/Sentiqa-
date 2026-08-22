'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sokVarer, type VareTreff } from '@/lib/varehierarki'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

const ScopeRad = z.object({
  nivaa: z.enum(['avdeling', 'vareomrade', 'varegruppe', 'ean']),
  kode: z.string().min(1),
  navn: z.string().nullish(),
})

const Skjema = z.object({
  navn: z.string().min(2, { error: 'Gi målekortet et navn.' }),
  metrikk: z.enum(['omsetning', 'antall', 'brutto', 'snittpris_kunde', 'snittbong', 'kunder']),
  normalisering: z.enum(['per_kunde', 'vekst_pst']),
  periode: z.enum(['uke', 'maaned', 'rullende4uker']),
  retning: z.enum(['hoy', 'lav']),
  krev_fullstendig_periode: z.boolean(),
  vis_butikksjef: z.boolean(),
  vis_tablet: z.boolean(),
  anonymiser: z.boolean(),
  scope: z.array(ScopeRad).max(200),
})

export type MalekortTilstand = { feil?: string; ok?: boolean } | undefined

export async function opprettMalekort(
  _t: MalekortTilstand,
  formData: FormData,
): Promise<MalekortTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan lage målekort.' }
  }

  let scope: unknown = []
  try {
    scope = JSON.parse(String(formData.get('scope') ?? '[]'))
  } catch {
    return { feil: 'Ugyldig vareutvalg.' }
  }

  const felt = Skjema.safeParse({
    navn: formData.get('navn'),
    metrikk: formData.get('metrikk'),
    normalisering: formData.get('normalisering'),
    periode: formData.get('periode'),
    retning: formData.get('retning'),
    krev_fullstendig_periode: formData.get('krev_fullstendig_periode') === 'on',
    vis_butikksjef: formData.get('vis_butikksjef') === 'on',
    vis_tablet: formData.get('vis_tablet') === 'on',
    anonymiser: formData.get('anonymiser') === 'on',
    scope,
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const d = felt.data

  const supabase = await lagSupabaseServerKlient()
  const { data: kort, error } = await supabase
    .from('malekort')
    .insert({
      retailer_id: bruker.retailerId,
      navn: d.navn,
      metrikk: d.metrikk,
      normalisering: d.normalisering,
      periode: d.periode,
      retning: d.retning,
      krev_fullstendig_periode: d.krev_fullstendig_periode,
      vis_butikksjef: d.vis_butikksjef,
      vis_tablet: d.vis_tablet,
      anonymiser: d.anonymiser,
    })
    .select('id')
    .single<{ id: string }>()
  if (error || !kort) return { feil: 'Kunne ikke lagre målekortet.' }

  if (d.scope.length > 0) {
    const rader = d.scope.map((s) => ({
      malekort_id: kort.id,
      retailer_id: bruker.retailerId,
      nivaa: s.nivaa,
      kode: s.kode,
      navn: s.navn ?? null,
    }))
    const { error: sErr } = await supabase.from('malekort_scope').insert(rader)
    if (sErr) {
      // Rydd opp så vi ikke etterlater et målekort uten scopet brukeren valgte.
      maaLykkes(await supabase.from('malekort').delete().eq('id', kort.id), 'slette malekort')
      return { feil: 'Kunne ikke lagre vareutvalget.' }
    }
  }

  revalidatePath('/maaling')
  return { ok: true }
}

export async function slettMalekort(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('malekort').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette malekort',
    ok: 'Malekort slettet',
    oppfrisk: ['/maaling'],
  })
}

// Brukes av scope-velgeren (klient) til å søke opp individuelle varer (EAN).
export async function sokVarerAksjon(q: string): Promise<VareTreff[]> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return []
  const supabase = await lagSupabaseServerKlient()
  return sokVarer(supabase, q)
}
