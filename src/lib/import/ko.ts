import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { behandleJobbKjerne } from '@/lib/import/kjerne'

// =====================================================================
// Importkøen kjørt uten et menneske.
//
// Filene kommer automatisk om natten, men fram til nå stoppet kjeden rett
// før målstreken: en mottatt fil ble liggende til noen åpnet /import og
// trykket «Behandle». Automatikk som krever et klikk er ikke automatikk.
//
// To ting gjøres her, i denne rekkefølgen:
//
//   1) GJENOPPTA. En jobb settes til 'behandler' før arbeidet starter og
//      til 'parset'/'feilet' etterpå. Dør prosessen imellom — funksjonen
//      timer ut, deploy midt i, nettet ryker — kjører aldri catch-en, og
//      raden blir stående i 'behandler' for alltid. UI-et skjuler
//      knappen for nettopp den statusen, og sha256-dedupen svarer
//      «Allerede importert» om noen laster opp på nytt. Blindvei.
//
//      Med et menneske i loopen ble det oppdaget fordi noen sto og
//      ventet. Med automatikk er det ingen som ser det.
//
//   2) BEHANDLE. Alt som står 'mottatt', eldste først, med feilisolasjon
//      per fil — én korrupt fil skal ikke stoppe resten av natten.
// =====================================================================

type Klient = SupabaseClient

// Hvor lenge en jobb kan stå i 'behandler' før vi regner den som død.
// Importsiden setter maxDuration = 300 s, så 20 minutter er romslig nok
// til at vi aldri avbryter noe som faktisk kjører.
const DOD_ETTER_MIN = 20

// Etter tre forsøk er det ikke et uhell lenger. Da skal fila stå som
// feilet og synes i lista, ikke gå i evig løkke hver natt.
const MAKS_FORSOK = 3

export type KoResultat = { gjenopptatt: number; ok: number; feilet: number; oppgitt: number }

export async function behandleKoen(supabase: Klient): Promise<KoResultat> {
  const ut: KoResultat = { gjenopptatt: 0, ok: 0, feilet: 0, oppgitt: 0 }

  const grense = new Date(Date.now() - DOD_ETTER_MIN * 60_000).toISOString()
  const { data: dode } = await supabase
    .from('import_jobber')
    .select('id, forsok')
    .eq('status', 'behandler')
    .lt('oppdatert_tid', grense)
  for (const j of (dode ?? []) as { id: string; forsok: number }[]) {
    if (j.forsok >= MAKS_FORSOK) {
      await supabase.from('import_jobber').update({
        status: 'feilet',
        feilmelding: `Behandlingen ble avbrutt ${MAKS_FORSOK} ganger. Last opp fila på nytt, eller si fra.`,
      }).eq('id', j.id)
      ut.oppgitt++
      continue
    }
    await supabase.from('import_jobber')
      .update({ status: 'mottatt', forsok: j.forsok + 1 }).eq('id', j.id)
    ut.gjenopptatt++
  }

  const { data: koen } = await supabase
    .from('import_jobber')
    .select('id, retailer_id')
    .eq('status', 'mottatt')
    .order('opprettet_tid', { ascending: true })
    .limit(200)

  for (const j of (koen ?? []) as { id: string; retailer_id: string }[]) {
    try {
      await behandleJobbKjerne(supabase, j.retailer_id, j.id)
      ut.ok++
    } catch {
      // Kjernen setter selv status='feilet'. Dette er kun for at løkka
      // skal gå videre til neste fil.
      ut.feilet++
    }
  }

  return ut
}
