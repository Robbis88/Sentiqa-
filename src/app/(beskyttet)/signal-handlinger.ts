'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// =====================================================================
// Handlingene under et funn. Uten disse stopper innsikten ved «−63 %»,
// og butikksjefen må selv huske hvilken modul som lager en oppgave.
//
// Ingenting nytt lagres: dette skriver til oppgaver, fokuspunkter og
// tablet_meldinger — systemene som allerede finnes. RLS avgjør tilgangen;
// sjekkene her gir bare en vennligere melding enn en tom skriving.
// =====================================================================

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

const Felt = z.object({
  tittel: z.string().min(1).max(200),
  tekst: z.string().max(1000).optional(),
  stasjon_id: z.string().uuid().optional(),
})

export type SignalTilstand = { ok?: string; feil?: string } | undefined

// Signalet vet ikke alltid hvilken stasjon det gjelder — en butikksjef har
// som regel én, og da er svaret opplagt. Har brukeren flere og signalet ikke
// peker på noen, sier vi ifra i stedet for å gjette.
async function finnStasjon(supabase: Klient, oppgitt?: string): Promise<string | null> {
  if (oppgitt) return oppgitt
  const { data } = await supabase.from('stasjoner').select('id').is('slettet_tid', null).limit(2)
  const rader = (data ?? []) as { id: string }[]
  return rader.length === 1 ? rader[0].id : null
}

async function forbered(fd: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return { feil: 'Ikke tilgang.' as const }
  const felt = Felt.safeParse({
    tittel: fd.get('tittel'),
    tekst: fd.get('tekst') || undefined,
    stasjon_id: fd.get('stasjon_id') || undefined,
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const supabase = await lagSupabaseServerKlient()
  const stasjonId = await finnStasjon(supabase, felt.data.stasjon_id)
  if (!stasjonId) {
    return { feil: 'Velg stasjon — du har flere, og funnet peker ikke på én bestemt.' }
  }
  return { bruker, supabase, stasjonId, data: felt.data }
}

export async function opprettOppgave(_t: SignalTilstand, fd: FormData): Promise<SignalTilstand> {
  const k = await forbered(fd)
  if ('feil' in k) return { feil: k.feil }
  const { error } = await k.supabase.from('oppgaver').insert({
    retailer_id: k.bruker.retailerId,
    stasjon_id: k.stasjonId,
    tittel: k.data.tittel,
    beskrivelse: k.data.tekst ?? null,
    opprettet_av: k.bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/oversikt')
  revalidatePath('/oppgaver')
  return { ok: 'Oppgave opprettet' }
}

export async function settSomFokus(_t: SignalTilstand, fd: FormData): Promise<SignalTilstand> {
  const k = await forbered(fd)
  if ('feil' in k) return { feil: k.feil }
  // Fokuspunkter grupperes per måned — samme periode som resten av settet.
  const periode = `${new Date().toISOString().slice(0, 7)}-01`
  const { error } = await k.supabase.from('fokuspunkter').insert({
    retailer_id: k.bruker.retailerId,
    stasjon_id: k.stasjonId,
    periode,
    type: 'forbedring',
    tittel: k.data.tittel,
    tekst: k.data.tekst ?? k.data.tittel,
  })
  if (error) return { feil: error.message }
  revalidatePath('/oversikt')
  revalidatePath('/fokus')
  return { ok: 'Lagt som fokuspunkt' }
}

export async function sendTilTablet(_t: SignalTilstand, fd: FormData): Promise<SignalTilstand> {
  const k = await forbered(fd)
  if ('feil' in k) return { feil: k.feil }
  const { error } = await k.supabase.from('tablet_meldinger').insert({
    retailer_id: k.bruker.retailerId,
    stasjon_id: k.stasjonId,
    tekst: k.data.tekst ? `${k.data.tittel}: ${k.data.tekst}` : k.data.tittel,
    opprettet_av: k.bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/oversikt')
  revalidatePath('/meldinger')
  return { ok: 'Sendt til tableten' }
}
