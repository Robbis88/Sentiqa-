// Stasjonsfasiten: butikknummer til navn, ett sted.
//
// =====================================================================
// FIRE FIKSTURFILER BAR HVER SIN KOPI, OG FIRE AV FEM PAR VAR GALE
// =====================================================================
//
// `regnskap.ts`, `salgsstatistikk.ts`, `kassererstatistikk.ts` og
// `varetransaksjon.ts` skrev hver sin liste. Alle fire sa 9145 = Dale og
// 9467 = Varden. Målt mot arknavnene i kildefila 2026-09-13 — identisk i
// januar- og julifila, og bekreftet mot `public.stasjoner` i produksjon:
//
//     4177 ST1 Lone          9145 ST1 Varden
//     4185 ST1 Dale          9467 ST1 Bønes
//     9038 ST1 Laguneparken  9900 Admin
//
// Fiksturene er syntetiske, så produksjonstallene var aldri feil —
// parserne nøkler på nummeret, ikke på navnet. Men et falskt kart i
// repoet bekrefter feilen for den som slår opp der, og det gjorde det:
// P2-rapporten byttet Varden og Bønes, og satsene fulgte med. En stasjon
// under budsjett ble fortalt at den lå over.
//
// ---------------------------------------------------------------------
// ÉN LISTE, IKKE FEM
//
// Derfor bor listen her, og de fire filene importerer den. En femte kopi
// er en femte sjanse til å bytte to rader uten at noe blir rødt.
//
// `stasjonsfasit.test.ts` feller enhver ny håndskrevet kopi i
// `src/lib/parsere/fixtures/`.

/** Butikknummer → navnet slik St1 skriver det i arkene. */
export const STASJONSFASIT: readonly (readonly [string, string])[] = [
  ['4177', 'Lone'],
  ['4185', 'Dale'],
  ['9038', 'Laguneparken'],
  ['9145', 'Varden'],
  ['9467', 'Bønes'],
] as const

/**
 * Navnet med kjedeprefiks, slik det står i arknavn og topptekster.
 *
 * St1 skriver «ST1 Lone» i regnskapsarkene og «St1 Lone» i
 * salgsstatistikken — samme navn, ulik kasus. Fiksturene skal bruke den
 * formen filen faktisk har, så parserne testes mot det de møter.
 */
export function medPrefiks(store: boolean): [string, string][] {
  return STASJONSFASIT.map(([nr, navn]) => [nr, `${store ? 'ST1' : 'St1'} ${navn}`])
}

/** Navnet uten prefiks. «9467» → «Bønes». */
export function navnFor(butikknummer: string): string {
  const treff = STASJONSFASIT.find(([nr]) => nr === butikknummer)
  if (!treff) throw new Error(`Ukjent butikknummer i fiksturene: ${butikknummer}`)
  return treff[1]
}

// =====================================================================
// NORMALISERING: Å KJENNE IGJEN ET NAVN, UTEN Å MISTE DET
// =====================================================================
//
// «Bønes», «Bones», «ST1 BØNES» og «Shell Bønes» er samme stasjon i fire
// systemer. En vanlig `RegExp` ser dem ikke som like: `ø` og `o` er
// ulike tegn, og en kanarifugl som matchet `/Bones/i` mot «Bønes» ville
// vært grønn fordi den aldri traff, ikke fordi den stemte.
//
// `normaliser` folder dem til én nøkkel. Den er til GJENKJENNING —
// visningsnavnet er og blir `navnFor()`, med ø.
//
// Foldingen er eksplisitt og norsk. Unicode-NFD ville tatt ø feil: den
// dekomponerer ikke i alle kilder, og «Bønes» ville blitt «Bnes».
//
// ---------------------------------------------------------------------
// TO FOLDINGER, IKKE ÉN
//
// «Bønes» skrives på to måter ute i systemene: `Boenes` (translitterert,
// slik filnavn og eldre eksporter gjør det) og `Bones` (ø-en er bare
// falt bort). De folder til ULIKE nøkler — `boenes` og `bones` — og
// ingen av dem er en delstreng av den andre.
//
// Derfor gir `noekler()` begge, og `sammeStasjon` spør om settene
// overlapper. Én folding alene ville sluppet gjennom nøyaktig den
// skrivemåten som er vanligst i et system uten æøå.
function grunnform(navn: string): string {
  return navn.toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, '')
    .replace(/^(st1|shell)/, '')
}

/** Den norske foldingen: æ→ae, ø→oe, å→aa. */
export function normaliser(navn: string): string {
  return grunnform(navn)
    .replace(/æ/g, 'ae').replace(/ø/g, 'oe').replace(/å/g, 'aa')
    .replace(/ö/g, 'oe').replace(/ä/g, 'ae')
    .replace(/[^a-z0-9]/g, '')
}

/** Den tapte foldingen: æ→a, ø→o, å→a. «Bønes» → «bones». */
export function normaliserTapt(navn: string): string {
  return grunnform(navn)
    .replace(/æ/g, 'a').replace(/ø/g, 'o').replace(/å/g, 'a')
    .replace(/ö/g, 'o').replace(/ä/g, 'a')
    .replace(/[^a-z0-9]/g, '')
}

/** Begge foldingene. Tomme nøkler tas ut. */
export function noekler(navn: string): Set<string> {
  return new Set([normaliser(navn), normaliserTapt(navn)].filter((n) => n.length > 0))
}

/** Er dette navnet den samme stasjonen? Tåler «Bones» mot «Bønes». */
export function sammeStasjon(a: string, b: string): boolean {
  const na = [...noekler(a)]
  const nb = [...noekler(b)]
  if (na.length === 0 || nb.length === 0) return false
  return na.some((x) => nb.some((y) => x === y || x.includes(y) || y.includes(x)))
}
