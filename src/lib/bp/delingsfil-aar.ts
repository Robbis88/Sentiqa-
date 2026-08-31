import type { Delingsrad } from '@/lib/parsere/delingsfil'

// =====================================================================
// HVILKET ÅR, OG HVILKEN STASJON?
//
// Delingsfila sier ingen av delene direkte. Den har ingen årskolonne og
// ingen butikknummer — bare et navn og noen tall.
//
// ---------------------------------------------------------------------
// NAVNET ER IKKE EN NØKKEL. BELØPET ER.
//
//   «det var navneendring i 2025 på slutten av året, fra shell til st1»
//                                            — Robert 2026-08-31
//
// Delingsfila for 2025 sier «SHELL LAGUNEPARKEN». Basen sier «St1
// Laguneparken». Første utgave av denne fila koblet på navnet uten
// kjedemerket, og det VILLE virket — men det er en kobling som ryker
// neste gang noen bytter merke, og den ryker i stillhet.
//
// `Budsjettert matomsetning` er derimot BP-ens Mat på krona:
//
//     Laguneparken   4 651 908
//     Varden         2 119 896
//     Bønes          1 700 096
//
// Tre tall som ikke kan forveksles, og som ikke endrer seg når skiltet
// på taket gjør det. Beløpet peker på både året og stasjonen på én gang.
//
// Navnet brukes fortsatt — som KRYSSJEKK. Sier navnet én stasjon og
// beløpet en annen, er det en ekte uenighet, og da kobles ingen av dem.
//
// ---------------------------------------------------------------------
// KRAVET ER STRENGT MED VILJE
//
// Et timebudsjett på feil stasjon eller feil år er verre enn ingen:
// bemanningsplanleggeren ville fordelt tallene, og planen ville sett
// helt normal ut. Derfor: eksakt beløp (én krones toleranse), entydig
// treff, og bare ÉN årgang som forklarer flest rader.
// =====================================================================

/** Mat-omsetningen per år og stasjon, slik den er budsjettert i BP-en. */
export type Matbudsjett = Map<number, Map<string, number>>

export type Aarssvar =
  | { ar: number; kobling: Map<string, string>; ukoblet: string[] }
  | { ar: null; grunn: string }

const KRONE = 1

/** Stasjonene i ett år hvis Mat-budsjett stemmer med beløpet. */
function treffIAar(perStasjon: Map<string, number>, belop: number): string[] {
  const ut: string[] = []
  for (const [stasjonId, mat] of perStasjon) {
    if (Math.abs(mat - belop) <= KRONE) ut.push(stasjonId)
  }
  return ut
}

/**
 * Finner året og hvilken stasjon hver rad hører til, eller sier hvorfor
 * det ikke lot seg gjøre.
 *
 * `navnekobling` er navnematchingen fra `koblePaaNavn`, og brukes bare
 * som kryssjekk. Den kan være tom — da svarer beløpene alene.
 */
export function finnAaret(
  rader: Delingsrad[],
  navnekobling: Map<string, string>,
  matbudsjett: Matbudsjett,
): Aarssvar {
  if (matbudsjett.size === 0) {
    return {
      ar: null,
      grunn:
        'Ingen forretningsplan er lastet inn ennå. Delingsfila plasseres ved å '
        + 'kjenne igjen budsjettert matomsetning i BP-en, så BP-en må komme først.',
    }
  }

  // Hvor mange rader kan hvert år forklare entydig?
  const kandidater: { ar: number; kobling: Map<string, string>; antall: number }[] = []
  for (const [ar, perStasjon] of matbudsjett) {
    const kobling = new Map<string, string>()
    const brukt = new Set<string>()
    let tvetydig = false
    for (const r of rader) {
      const treff = treffIAar(perStasjon, r.matomsetning)
      if (treff.length === 0) continue
      // To stasjoner med samme Mat-budsjett, eller to rader som peker på
      // samme stasjon: begge deler gjør koblingen til en gjetning.
      if (treff.length > 1 || brukt.has(treff[0])) { tvetydig = true; break }
      brukt.add(treff[0])
      kobling.set(r.butikknavn.trim().toLowerCase(), treff[0])
    }
    if (tvetydig || kobling.size === 0) continue
    kandidater.push({ ar, kobling, antall: kobling.size })
  }

  if (kandidater.length === 0) {
    return {
      ar: null,
      grunn:
        'Fant ingen BP-årgang der budsjettert matomsetning stemmer med delingsfila. '
        + 'Last opp forretningsplanen for samme år først — delingsfila plasseres ved '
        + 'å kjenne igjen tallene i den.',
    }
  }

  kandidater.sort((a, b) => b.antall - a.antall)
  if (kandidater.length > 1 && kandidater[0].antall === kandidater[1].antall) {
    const like = kandidater.filter((k) => k.antall === kandidater[0].antall).map((k) => k.ar)
    return {
      ar: null,
      grunn:
        `Delingsfila passer like godt til ${like.sort().join(' og ')}. `
        + 'Da kan den ikke plasseres uten å gjette, og et timebudsjett på feil år '
        + 'er verre enn ingen.',
    }
  }

  const { ar, kobling } = kandidater[0]

  // KRYSSJEKK MOT NAVNET. Sier navnet én stasjon og beløpet en annen, er
  // det en ekte uenighet — og da er én av dem feil, uten at vi vet hvilken.
  for (const [navn, viaBelop] of kobling) {
    const viaNavn = navnekobling.get(navn)
    if (viaNavn && viaNavn !== viaBelop) {
      return {
        ar: null,
        grunn:
          `«${navn}» peker på én stasjon etter navnet og en annen etter `
          + 'budsjettert matomsetning. Da er én av dem feil, og timene skrives ikke '
          + 'før det er avklart.',
      }
    }
  }

  const ukoblet = rader
    .map((r) => r.butikknavn)
    .filter((n) => !kobling.has(n.trim().toLowerCase()))
  return { ar, kobling, ukoblet }
}
