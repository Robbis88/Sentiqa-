import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { hentAlle } from '@/lib/supabase/sider'

// =====================================================================
// HVILKE MAANEDER HAR EN LOKAL A1-KILDE?
//
// EN OPPGAVE, OG BARE EN. Den oppdager maaneder. Den avgjoer ingenting.
//
// ---------------------------------------------------------------------
// HVORFOR DEN FINNES
//
// `/lonnskost` har ingen valgt maaned - `type Sok = { stasjon?: string }`
// - og siden viser en SERIE. Alternativene var aa innfoere `?maned=` paa
// en side som ikke har det, eller aa kalle `hentKilder` blindt for tolv
// maaneder. Begge er verre enn en billig oppdagelsesspoerring.
//
// ---------------------------------------------------------------------
// EN MAANED FINNES DERSOM STASJONEN HAR EN EGEN KILDE I DEN
//
//   basisvakt(stasjon, maaned)      finnes
//   ELLER
//   lonnsregister(stasjon, maaned)  finnes
//
// KRYSSREGISTER TELLER IKKE. En registerrad paa Lone som laanes av en
// Boenes-ansatt gjoer ikke en ny Boenes-maaned eksisterende - da ville
// oppdagelsen smittet mellom stasjoner, og en stasjon uten en eneste
// egen kilde kunne dukket opp med en maaned den ikke har.
//
// ---------------------------------------------------------------------
// DEN AVGJOER IKKE KILDEKONTRAKTEN
//
// `hentKilder` er fortsatt eneste port for det. Denne sier bare hvor det
// er verdt aa spoerre. Maalt mot produksjon 2026-09-16:
//
//   Boenes       2026-08   basisvakt OG register   -> hentKilder: begge
//   Laguneparken 2026-08   bare basisvakt          -> mangler_register
//   Lone         2026-08   bare register           -> mangler_arbeidstid
//
// Alle tre skal oppdages her. Forskjellen paa dem er ikke denne filas
// jobb, og aa la den avgjoere ville gitt to steder som kan skille lag.
// =====================================================================

type Klient = SupabaseClient

const MAANED = /^\d{4}-(0[1-9]|1[0-2])$/

/**
 * ISO-maanedene stasjonen har minst en egen A1-kilde i.
 *
 * Unik og sortert, nyeste foerst. Tom liste betyr at stasjonen ikke har
 * en eneste arbeidstids- eller registerrad - ikke at den koster null.
 */
export async function hentA1Maaneder(
  supabase: Klient,
  stasjonId: string,
): Promise<string[]> {
  type Rad = { kilde_maaned: string }

  // SIDER, IKKE ETT KALL. To rader per maaned i dag; det er naar det
  // slutter aa vaere sant at en avkortet liste ville skjult en maaned.
  const [vakter, register] = await Promise.all([
    hentAlle<Rad>(() => supabase
      .from('basisvakt')
      .select('kilde_maaned')
      .eq('stasjon_id', stasjonId)),
    hentAlle<Rad>(() => supabase
      .from('lonnsregister')
      .select('kilde_maaned')
      .eq('stasjon_id', stasjonId)),
  ])

  const funnet = new Set<string>()
  for (const r of [...(vakter ?? []), ...(register ?? [])]) {
    // Basen har check-constraint paa formen i baade 0218 og 0219, saa en
    // annen verdi kan ikke finnes. Sjekken staar likevel: en kolonne kan
    // utvides i en senere migrasjon uten at denne lesingen blir roed.
    if (MAANED.test(r.kilde_maaned)) funnet.add(r.kilde_maaned)
  }
  return [...funnet].sort().reverse()
}
