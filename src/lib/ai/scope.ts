import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { Brukerrolle } from '@/lib/auth/typer'

// =====================================================================
// Autorisert scope for AI-en.
//
// SCOPET KOMMER FRA BASEN, ALDRI FRA PROMPTEN. `stasjoner` leses med
// brukerens egen klient, så RLS har allerede avgjort listen før vi ser
// den: butikksjefen får radene i `butikksjef_stasjoner`, eieren får hele
// sin retailer. Ingen andre får noe.
//
// Det betyr at denne fila ikke ER sikkerhetsgrensa — den leser den. Selv
// om alt her var feil, ville et oppslag mot en fremmed stasjon returnert
// null rader. Poenget med `velgStasjoner` er ÆRLIGHET, ikke vern: uten
// den blir «du har ikke tilgang til Lone» og «Lone har ingen data» til
// det samme tomme svaret, og modellen velger den mest hjelpsomme
// tolkningen — som er feil.
//
// Skriver butikksjefen «vis meg Lone», skal hun få vite at Lone ligger
// utenfor tilgangen hennes. Hun skal ikke få vite noe om Lone.
// =====================================================================

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export type Stasjon = {
  id: string
  butikknummer: string
  navn: string
  stasjonstype: string | null
}

export type Scope = {
  rolle: Brukerrolle
  stasjoner: Stasjon[]
  /** Sant for retailer_admin — den som kan spørre om hele clusteret. */
  erEier: boolean
}

export type Utvalg = {
  valgte: Stasjon[]
  /** Det brukeren skrev, som ikke traff noe i scopet. Aldri spurt om i basen. */
  utenfor: string[]
}

export async function hentScope(
  supabase: Klient,
  rolle: Brukerrolle,
): Promise<Scope | { feil: string }> {
  const { data, error } = await supabase
    .from('stasjoner')
    .select('id, butikknummer, navn, stasjonstype')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<Stasjon[]>()

  if (error) return { feil: `Kunne ikke lese stasjonslisten: ${error.message}` }

  return {
    rolle,
    stasjoner: data ?? [],
    erEier: rolle === 'retailer_admin',
  }
}

function normaliser(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, ' ')
}

/**
 * Oversetter det brukeren skrev til stasjoner i scopet.
 *
 * Tom liste inn = hele scopet. Det er det som gjør at eieren kan spørre
 * om clusteret uten å ramse opp fem butikknumre, og at butikksjefen får
 * sine egne uten å oppgi noe som helst — samme verktøy, samme vei.
 */
export function velgStasjoner(scope: Scope, onsket?: unknown): Utvalg {
  const liste = Array.isArray(onsket)
    ? onsket.map(String).filter((s) => s.trim().length > 0)
    : typeof onsket === 'string' && onsket.trim().length > 0
      ? [onsket]
      : []

  if (liste.length === 0) return { valgte: scope.stasjoner, utenfor: [] }

  const valgte: Stasjon[] = []
  const utenfor: string[] = []

  for (const rå of liste) {
    const n = normaliser(rå)
    const treff = scope.stasjoner.find(
      (s) =>
        s.butikknummer === rå.trim()
        || normaliser(s.navn) === n
        // «Dale» skal treffe «0142 Dale», men ikke matche på ett tegn.
        || (n.length >= 3 && normaliser(s.navn).includes(n)),
    )
    if (treff) {
      if (!valgte.some((v) => v.id === treff.id)) valgte.push(treff)
    } else {
      utenfor.push(rå.trim())
    }
  }

  return { valgte, utenfor }
}

/** Etikett for en stasjon i AI-svar. Butikknummer + navn, alltid begge. */
export function etikett(s: Stasjon): string {
  return `${s.butikknummer} ${s.navn}`
}

/** Oppslag id → etikett, for å oversette rader som bare bærer stasjon_id. */
export function etikettKart(stasjoner: Stasjon[]): Map<string, string> {
  return new Map(stasjoner.map((s) => [s.id, etikett(s)]))
}
