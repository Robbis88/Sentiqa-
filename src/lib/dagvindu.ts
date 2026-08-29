import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { erDag, type Dag } from '@/lib/periode'

// =====================================================================
// HVILKE DAGER FINNES DET Å GÅ TIL?
//
// Samme regel som månedsvelgeren er bygget på, ett korn ned:
//
//   Kilden bestemmer hva som er gyldig. Velgeren bestemmer hvordan det
//   ser ut og heter.
//
// `/salg` leser `v_salg_per_stasjon_dag`, `/timesalg` leser `timesalg`.
// De har ikke de samme dagene — timesalgsrapporten lastes opp for seg,
// og har historisk ligget etter salgsstatistikken. En felles dagsliste
// ville lovet en dag den ene sida ikke kan vise.
//
// ---------------------------------------------------------------------
// FIRE SPØRRINGER, ÉN RAD HVER
//
// Alternativet var å hente alle datoer og regne i minnet. Det ville vært
// feil av to grunner:
//
//   `select('dato')` gir ÉN RAD PER STASJON PER DAG. To kalenderår ×
//   fem stasjoner er over tre tusen rader — forbi PostgREST-taket på
//   tusen. Lista hadde blitt stille avkortet, og «første dag» ville vært
//   den eldste av de tusen nyeste. Feil, og feil på en måte som ser
//   riktig ut.
//
//   Og nabodagen er ikke gårsdagen. Er det hull i dataene, skal pila
//   hoppe til forrige dag som FINNES, ikke til en tom side. Det er et
//   spørsmål bare basen kan svare på.
//
// Hver av de fire er `limit(1)` på en sortert, indeksert kolonne.
// =====================================================================

export type Dagvindu = {
  /** Eldste og nyeste dag kilden har. `min`/`max` i datofeltet. */
  forste: Dag | null
  siste: Dag | null
  /** Nærmeste dag med data på hver side. `null` når vi står ytterst. */
  forrige: Dag | null
  neste: Dag | null
}

const TOMT: Dagvindu = { forste: null, siste: null, forrige: null, neste: null }

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

/** Nyeste dagen kilden har, eller `null`. Det sidene faller tilbake på. */
export async function sisteDag(supabase: Klient, tabell: string): Promise<Dag | null> {
  const { data } = await supabase
    .from(tabell)
    .select('dato')
    .order('dato', { ascending: false })
    .limit(1)
    .maybeSingle<{ dato: string }>()
  return erDag(data?.dato) ? data!.dato : null
}

/**
 * Dagene rundt `dag` i `tabell`.
 *
 * `dag` skal være lest med `lesDag` først — vinduet stoler på at den er
 * gyldig, og en ugyldig dag ville gitt `forrige`/`neste` fra en
 * sammenligning ingen kan tolke.
 */
export async function hentDagvindu(
  supabase: Klient,
  tabell: string,
  dag: Dag | null,
): Promise<Dagvindu> {
  if (!dag) return TOMT

  const en = (b: { data: { dato: string } | null }) =>
    erDag(b.data?.dato) ? b.data!.dato : null

  const [forste, siste, forrige, neste] = await Promise.all([
    supabase.from(tabell).select('dato').order('dato', { ascending: true })
      .limit(1).maybeSingle<{ dato: string }>(),
    supabase.from(tabell).select('dato').order('dato', { ascending: false })
      .limit(1).maybeSingle<{ dato: string }>(),
    supabase.from(tabell).select('dato').lt('dato', dag)
      .order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>(),
    supabase.from(tabell).select('dato').gt('dato', dag)
      .order('dato', { ascending: true }).limit(1).maybeSingle<{ dato: string }>(),
  ])

  return { forste: en(forste), siste: en(siste), forrige: en(forrige), neste: en(neste) }
}
