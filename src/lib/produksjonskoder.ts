import type { SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// HVILKE VAREGRUPPER ER PRODUKSJONSVARER FOR DENNE KJEDEN?
//
// Var åtte hardkodede St1-koder i `PRODUKSJON_KODER`. Fra `0152` er det
// konfigurasjon per retailer, i `retailer_koderegel`.
//
// ---------------------------------------------------------------------
// HVORFOR DETTE IKKE RETURNERER EN TOM LISTE
//
// Den enkle formen — returner `string[]`, tom hvis ingenting er mappet —
// er nettopp formen som gjør skade. Kallstedet ville filtrert på null
// koder, fått null rader, og vist en plan uten forslag. **En tom plan er
// en gyldig plan:** «ingenting skal produseres i dag» er en setning
// systemet kan mene, og den ser identisk ut.
//
// Det er `0075`-formen: «Ingen stasjoner.» var sant, og beskrev noe helt
// annet enn det som skjedde.
//
// Derfor er `ikke_konfigurert` en egen tilstand som kallstedet er nødt
// til å håndtere. Typen tvinger fram valget.
//
// ---------------------------------------------------------------------
// HVORFOR DEN KASTER PÅ FEIL
//
// En spørring som feiler gir også null koder. Svelges feilen, er vi
// tilbake til en troverdig tom plan — bare med en annen årsak. Femten
// rpc-kall i denne kodebasen svelger allerede `error`; dette blir ikke
// det sekstende.
// =====================================================================

export type Produksjonsoppsett =
  | { status: 'mappet'; koder: string[] }
  | { status: 'ikke_konfigurert' }

/**
 * Produksjonskodene for den innloggedes kjede.
 *
 * RLS avgrenser til egen retailer, så oppslaget trenger ingen id.
 */
export async function hentProduksjonskoder(
  supabase: SupabaseClient,
): Promise<Produksjonsoppsett> {
  const { data, error } = await supabase
    .from('retailer_koderegel')
    .select('kode')
    .eq('rolle', 'produksjon')
    .eq('nivaa', 'varegruppe')
    .overrideTypes<{ kode: string | null }[]>()

  if (error) throw new Error(`retailer_koderegel: ${error.message}`)

  const koder = (data ?? []).map((r) => r.kode).filter((k): k is string => Boolean(k))
  return koder.length > 0 ? { status: 'mappet', koder } : { status: 'ikke_konfigurert' }
}

/**
 * Teksten kunden ser når kjeden ikke er mappet.
 *
 * Ett sted, så de to kallstedene ikke forklarer det samme på hver sin
 * måte — og så det ikke fristes til å skrive «ingen varer i dag».
 */
export const IKKE_KONFIGURERT_TEKST =
  'Produksjonsplanen er ikke satt opp for kjeden ennå. Sentiqa må først '
  + 'koble varegruppene deres til produksjonsvarer. Dette er ikke noe du '
  + 'kan gjøre selv, og det er ikke en feil i dagens tall.'
