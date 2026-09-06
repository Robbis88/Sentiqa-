'use server'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

const Ny = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg en stasjon.' }),
  tittel: z.string().min(1, { error: 'Skriv en tittel.' }),
  beskrivelse: z.string().optional(),
  frist: z.string().optional(),
})

export type OppgaveTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilOppgave(
  _t: OppgaveTilstand,
  formData: FormData,
): Promise<OppgaveTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return { feil: 'Du kan ikke opprette oppgaver.' }
  }
  const felt = Ny.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    tittel: formData.get('tittel'),
    beskrivelse: formData.get('beskrivelse'),
    frist: formData.get('frist'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const visPaaTablet = formData.get('vis_paa_tablet') === 'on'
  const bilde = String(formData.get('bilde_url') ?? '').trim() || null
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('oppgaver').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    tittel: felt.data.tittel,
    beskrivelse: felt.data.beskrivelse || null,
    frist: felt.data.frist || null,
    vis_paa_tablet: visPaaTablet,
    bilde_url: bilde,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  return { ok: true }
}

export async function slettOppgave(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('oppgaver').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette oppgave',
    ok: 'Oppgave slettet',
    oppfrisk: ['/oppgaver'],
  })
}

// Tablet: ansatte kvitterer «utført» på en vis_paa_tablet-melding (RPC m/ RLS-sjekk).
export async function kvitterTablet(oppgaveId: string, fullfort: boolean): Promise<void> {
  await hentInnloggetBruker() // sikrer innlogget sesjon
  if (!oppgaveId) return
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.rpc('kvitter_tablet_melding', {
    p_oppgave: oppgaveId, p_fullfort: fullfort,
  })
  // EN HAKE SOM IKKE BLE SKREVET SKAL IKKE SE SATT UT.
  //
  // Kallstedet setter raden optimistisk FØR handlingen kjører. Svelges
  // feilen, står meldingen som kvittert på skjermen mens ingenting er
  // lagret — og hun tror den er gjort til neste gang sida lastes.
  //
  // Det er den motsatte og verre varianten av «en handling som lykkes
  // uten å si fra»: en som feiler uten å si fra. Kastet ruller den
  // optimistiske raden tilbake.
  if (error) throw new Error(`Kunne ikke kvittere meldingen: ${error.message}`)
}

export async function veksleOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const id = String(formData.get('id') ?? '')
  const tilFullfort = String(formData.get('til') ?? '') === 'fullfort'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase
    .from('oppgaver')
    .update(
      tilFullfort
        ? { status: 'fullfort', fullfort_av: bruker.id, fullfort_tid: new Date().toISOString() }
        : { status: 'apen', fullfort_av: null, fullfort_tid: null },
    )
    .eq('id', id), 'oppdatere oppgaver')
}
