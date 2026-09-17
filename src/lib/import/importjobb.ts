import type { SupabaseClient } from '@supabase/supabase-js'

/** En råfil kan overleve et avbrudd før jobbinnsetting. Retry reparerer samme fil. */
export async function sikreImportjobb(supabase: SupabaseClient, retailerId: string, filId: string) {
  const svar = await supabase.from('import_jobber').select('id')
    .eq('retailer_id', retailerId).eq('raa_fil_id', filId)
    .order('opprettet_tid', { ascending: false }).limit(1)
  if (svar.error || !svar.data) throw new Error(`Kunne ikke kontrollere importjobben: ${svar.error?.message ?? 'mangler svar'}`)
  const eksisterende = svar.data[0] as { id: string } | undefined
  if (eksisterende) return { jobbId: eksisterende.id, opprettet: false }
  // Samme råfil får samme nye jobbidentitet. Primærnøkkelen gjør også
  // samtidige reparasjoner idempotente uten å begrense gammel jobbhistorikk.
  const ny = await supabase.from('import_jobber')
    .insert({ id: filId, raa_fil_id: filId, retailer_id: retailerId }).select('id').single<{ id: string }>()
  if (ny.error?.code === '23505') {
    const samtidige = await supabase.from('import_jobber').select('id')
      .eq('retailer_id', retailerId).eq('raa_fil_id', filId).eq('id', filId).limit(1)
    if (samtidige.error) throw new Error(`Kunne ikke kontrollere samtidig import: ${samtidige.error.message}`)
    const annen = samtidige.data?.[0] as { id: string } | undefined
    if (annen) return { jobbId: annen.id, opprettet: false }
  }
  if (ny.error || !ny.data) throw new Error(`Kunne ikke opprette importjobb: ${ny.error?.message ?? 'mangler svar'}. Last opp fila på nytt for å prøve igjen.`)
  return { jobbId: ny.data.id, opprettet: true }
}

export async function finnRaaFil(supabase: SupabaseClient, retailerId: string, sha256: string) {
  const svar = await supabase.from('raa_filer').select('id')
    .eq('retailer_id', retailerId).eq('sha256', sha256).is('slettet_tid', null)
    .order('opprettet_tid', { ascending: false }).limit(1)
  if (svar.error || !svar.data) throw new Error(`Kunne ikke finne råfila: ${svar.error?.message ?? 'mangler svar'}`)
  const fil = svar.data[0] as { id: string } | undefined
  if (!fil) throw new Error('Råfila ble ikke funnet. Prøv opplastingen på nytt.')
  return fil.id
}
