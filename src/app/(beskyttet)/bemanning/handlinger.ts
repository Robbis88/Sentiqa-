'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// RLS gjør den egentlige jobben — stasjonstilgang og rolle håndheves i
// policyene fra 0081. Sjekkene her gir bare et vennligere svar enn en
// tom skriveoperasjon.

const Tid = z.coerce.number().int().min(0).max(24)
const Ukedag = z.coerce.number().int().min(1).max(7)

const Vindu = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  ukedag: Ukedag,
  fra_time: Tid,
  til_time: Tid,
  min_bemanning: z.coerce.number().int().min(0).max(20),
  gjelder_fra: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { error: 'Ugyldig dato.' }),
}).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

const FastVakt = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  navn: z.string().min(1, { error: 'Skriv hvem vakten gjelder.' }),
  ukedager: z.array(Ukedag).min(1, { error: 'Velg minst én ukedag.' }),
  fra_time: Tid,
  til_time: Tid,
}).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

const Krav = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  ukedager: z.array(Ukedag).min(1, { error: 'Velg minst én ukedag.' }),
  fra_time: Tid,
  til_time: Tid,
  antall: z.coerce.number().int().min(2).max(20),
  begrunnelse: z.string().optional(),
}).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

export type Tilstand = { ok?: true; feil?: string } | undefined

async function klient() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return null
  return await lagSupabaseServerKlient()
}

const ukedagerFra = (fd: FormData) => fd.getAll('ukedag').map((u) => Number(u))

export async function lagreVindu(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Vindu.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ukedag: fd.get('ukedag'),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
    min_bemanning: fd.get('min_bemanning'),
    gjelder_fra: fd.get('gjelder_fra'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { error } = await supabase
    .from('bemanning_vindu')
    .upsert({ ...felt.data, oppdatert_tid: new Date().toISOString() },
      { onConflict: 'stasjon_id,ukedag,gjelder_fra' })
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return { ok: true }
}

export async function leggTilFastVakt(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = FastVakt.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    navn: fd.get('navn'),
    ukedager: ukedagerFra(fd),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  // Én rad per ukedag — «butikksjef 07–15 man–fre» blir fem rader.
  const { stasjon_id, navn, fra_time, til_time } = felt.data
  const { error } = await supabase.from('bemanning_fast_vakt').upsert(
    felt.data.ukedager.map((ukedag) => ({
      stasjon_id, navn, ukedag, fra_time, til_time, oppdatert_tid: new Date().toISOString(),
    })),
    { onConflict: 'stasjon_id,navn,ukedag' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return { ok: true }
}

export async function leggTilKrav(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Krav.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ukedager: ukedagerFra(fd),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
    antall: fd.get('antall'),
    begrunnelse: fd.get('begrunnelse'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { stasjon_id, fra_time, til_time, antall, begrunnelse } = felt.data
  const { error } = await supabase.from('bemanning_krav').insert(
    felt.data.ukedager.map((ukedag) => ({
      stasjon_id, ukedag, fra_time, til_time, antall,
      begrunnelse: begrunnelse || null,
    })),
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return { ok: true }
}

async function slett(tabell: string, fd: FormData) {
  const supabase = await klient()
  if (!supabase) return
  const id = String(fd.get('id') ?? '')
  if (!id) return
  await supabase.from(tabell).delete().eq('id', id)
  revalidatePath('/bemanning')
}

export async function slettFastVakt(fd: FormData) { await slett('bemanning_fast_vakt', fd) }
export async function slettKrav(fd: FormData) { await slett('bemanning_krav', fd) }
export async function slettVindu(fd: FormData) { await slett('bemanning_vindu', fd) }
