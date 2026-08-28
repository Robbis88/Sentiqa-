// =====================================================================
// HVILKE SQL-OBJEKTER SUMMERER FRA `daglig_salg` I STEDET FOR
// `v_butikksalg`?
//
// Husregelen er at alt som summerer kroner eller antall skal lese
// `v_butikksalg`. Den regelen har vaert kontrollert for TypeScript
// (`grep "from('daglig_salg')" src/`), men aldri for SQL.
//
// `beregn_vaerprofil` (0068) og `beregn_kategori_vaerprofil` (0070) laa
// utenfor. De filtrerte selv - paa `avdeling_kode not in ('10','250')` -
// og saa dermed riktige ut. Baselinen 2026-08-28 viste at drivstoff har
// kode **1000**, saa filteret traff ingenting, og vaerprofilen laerte paa
// drivstoff i staden for butikk.
//
// ---------------------------------------------------------------------
// HVORFOR SISTE DEFINISJON, IKKE ALLE TREFF
//
// Migrasjonene kjoeres i rekkefoelge og `create or replace` vinner. Et
// view definert i `0004` og redefinert i `0124` er `0124`s definisjon.
// En vakt som talte hvert historisk treff ville meldt funn som ikke
// finnes, og en vakt med falske positive laerer folk aa se bort fra
// roedt. Samme grunn som `funksjoner.ts` respekterer `drop function`.
// =====================================================================

/** `create or replace function|view public.navn` — siste definisjon vinner. */
const DEF = /create\s+(?:or\s+replace\s+)?(function|view)\s+(?:public\.)?([a-z0-9_]+)/gi

/** Aggregat som betyr at objektet summerer kroner eller antall. */
const AGGREGAT = /\b(sum|avg|corr)\s*\(/i

function utenKommentarer(sql: string): string {
  return sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*/g, '')
}

/**
 * Kroppen til én definisjon: fra `create ...` til neste `create ...`
 * eller filslutt. Grovt, men presist nok — en definisjon som strekker
 * seg forbi neste `create` finnes ikke i dette repoet.
 */
function kropper(sql: string): { slag: string; navn: string; kropp: string }[] {
  const ren = utenKommentarer(sql)
  const treff = [...ren.matchAll(DEF)]
  return treff.map((m, i) => ({
    slag: m[1].toLowerCase(),
    navn: m[2].toLowerCase(),
    kropp: ren.slice(m.index!, i + 1 < treff.length ? treff[i + 1].index! : undefined),
  }))
}

export type Kilde = { navn: string; slag: string; fil: string }

/**
 * Objekter hvis SISTE definisjon bade aggregerer og leser
 * `public.daglig_salg` direkte.
 *
 * Filene maa komme i migrasjonsrekkefoelge.
 */
export function aggregerendeDaglige(
  filer: { fil: string; sql: string }[],
): Kilde[] {
  const siste = new Map<string, { slag: string; fil: string; kropp: string }>()
  for (const f of filer) {
    for (const d of kropper(f.sql)) {
      siste.set(d.navn, { slag: d.slag, fil: f.fil, kropp: d.kropp })
    }
  }
  const ut: Kilde[] = []
  for (const [navn, d] of siste) {
    if (/from\s+public\.daglig_salg\b/i.test(d.kropp) && AGGREGAT.test(d.kropp)) {
      ut.push({ navn, slag: d.slag, fil: d.fil })
    }
  }
  return ut.sort((a, b) => a.navn.localeCompare(b.navn))
}

/** Kroppen til siste definisjon av ett navngitt objekt. */
export function sisteDefinisjon(
  filer: { fil: string; sql: string }[], navn: string,
): { fil: string; kropp: string } | null {
  let funn: { fil: string; kropp: string } | null = null
  for (const f of filer) {
    for (const d of kropper(f.sql)) {
      if (d.navn === navn.toLowerCase()) funn = { fil: f.fil, kropp: d.kropp }
    }
  }
  return funn
}
