'use server'
import { revalidatePath } from 'next/cache'
import { randomUUID } from 'node:crypto'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const BUCKET = 'raa-filer'

export type Tilstand = { ok?: string; feil?: string } | undefined

// Malene lastes opp av eier og gjelder hele kjeden. Ansettelsesform,
// rolle og mindreårig avgjør hvilken som brukes — tariffbundet følger
// kjeden og velges ikke her.
const Mal = z.object({
  ansettelsesform: z.literal(['fast', 'midlertidig', 'tilkalling']),
  rolle: z.literal(['ansatt', 'ass_butikksjef', 'butikksjef']),
  mindreaarig: z.literal(['ja', 'nei']).transform((v) => v === 'ja'),
})

export async function lastOppMal(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan laste opp maler.' }
  }
  const felt = Mal.safeParse({
    ansettelsesform: fd.get('ansettelsesform'),
    rolle: fd.get('rolle'),
    mindreaarig: fd.get('mindreaarig') ?? 'nei',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const fil = fd.get('fil')
  if (!(fil instanceof File) || fil.size === 0) return { feil: 'Velg en .docx-fil.' }
  if (!fil.name.toLowerCase().endsWith('.docx')) {
    return { feil: 'Malen må være .docx — vi fyller ut originalen, ikke en kopi.' }
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: retailer } = await supabase
    .from('retailers').select('tariffbundet').maybeSingle<{ tariffbundet: boolean }>()
  const tariffbundet = retailer?.tariffbundet ?? true

  // Ny versjon hver gang, aldri overskriving. Du må kunne vise nøyaktig
  // hvilken tekst hun signerte, og da kan ikke malen endres under føttene.
  const { data: forrige } = await supabase
    .from('kontraktmal')
    .select('versjon')
    .eq('retailer_id', bruker.retailerId)
    .eq('ansettelsesform', felt.data.ansettelsesform)
    .eq('rolle', felt.data.rolle)
    .eq('mindreaarig', felt.data.mindreaarig)
    .eq('tariffbundet', tariffbundet)
    .order('versjon', { ascending: false })
    .limit(1)
    .maybeSingle<{ versjon: number }>()
  const versjon = (forrige?.versjon ?? 0) + 1

  const sti = `${bruker.retailerId}/kontraktmal/${randomUUID()}-${fil.name}`
  const opp = await supabase.storage.from(BUCKET)
    .upload(sti, fil, { contentType: fil.type || 'application/octet-stream' })
  if (opp.error) return { feil: `Opplasting feilet: ${opp.error.message}` }

  // Tidligere versjoner deaktiveres, men slettes ikke.
  await supabase.from('kontraktmal').update({ aktiv: false })
    .eq('retailer_id', bruker.retailerId)
    .eq('ansettelsesform', felt.data.ansettelsesform)
    .eq('rolle', felt.data.rolle)
    .eq('mindreaarig', felt.data.mindreaarig)
    .eq('tariffbundet', tariffbundet)

  const { error } = await supabase.from('kontraktmal').insert({
    retailer_id: bruker.retailerId,
    ...felt.data,
    tariffbundet,
    filnavn: fil.name,
    storage_sti: sti,
    versjon,
  })
  if (error) {
    await supabase.storage.from(BUCKET).remove([sti])
    return { feil: error.message }
  }
  revalidatePath('/kontrakt')
  return { ok: `Lagret som versjon ${versjon}` }
}

// Kjedens standardfelt — det som er likt i hver eneste kontrakt.
export async function lagreStandardfelt(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan endre dette.' }
  }
  const felt: Record<string, string> = {}
  for (const [k, v] of fd.entries()) {
    if (k.startsWith('felt.') && typeof v === 'string' && v.trim()) {
      felt[k.slice(5)] = v.trim()
    }
  }
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('retailers')
    .update({ kontrakt_standardfelt: felt }).eq('id', bruker.retailerId)
  if (error) return { feil: error.message }
  revalidatePath('/kontrakt')
  return { ok: `${Object.keys(felt).length} felt lagret` }
}

// Ansattkortets felt som kontrakten trenger, og som ikke fantes før.
const Ansatt = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
  fodselsdato: z.union([z.literal('').transform(() => null),
    z.string().regex(/^\d{4}-\d{2}-\d{2}$/)]),
  stillingstittel: z.union([z.literal('').transform(() => null), z.string().min(1)]),
  skiftordning: z.union([z.literal('').transform(() => null),
    z.literal(['ordinaer', 'to_skift'])]),
  har_rammeavtale: z.literal(['ja', 'nei']).default('nei').transform((v) => v === 'ja'),
})

export async function lagreAnsattkort(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const felt = Ansatt.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
    fodselsdato: fd.get('fodselsdato') ?? '',
    stillingstittel: fd.get('stillingstittel') ?? '',
    skiftordning: fd.get('skiftordning') ?? '',
    har_rammeavtale: fd.get('har_rammeavtale') ?? 'nei',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/kontrakt')
  return { ok: `${felt.data.navn} lagret` }
}
