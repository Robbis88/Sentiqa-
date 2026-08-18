// =====================================================================
// Fasit over hva systemet KAN, målt fra kildekoden.
//
// Redesignet skal flytte, gruppere og forenkle — men ingenting skal
// forsvinne. Et løfte om det er verdiløst. Dette er målingen.
//
// Fasiten er delt i to, fordi de to halvdelene har ulik strenghet:
//
//   HARDT   ruter, roller, serverhandlinger. Forsvinner en av dem, har
//           systemet mistet noe det kunne. Skal aldri skje i stillhet.
//
//   MYKT    seksjoner og lenker. De ER meningen å endre — en side som
//           deles i faner får færre seksjoner, og det er poenget. Her
//           er verdien at ENDRINGEN BLIR SYNLIG i diffen, ikke at den
//           forhindres.
//
// Derfor forbyr ikke vakthunden endring. Den tvinger den til å bli
// erklært: du oppdaterer fasiten med vilje, og git viser nøyaktig hva
// du ga slipp på. Det er forskjellen på å flytte noe og å miste det.
// =====================================================================

export type Fasit = {
  ruter: string[]
  meny: string[]
  handlinger: Record<string, string[]>
  seksjoner: Record<string, string[]>
  lenker: Record<string, string[]>
}

/** `src/app/(beskyttet)/rutiner/oppsett/[id]/page.tsx` → `/rutiner/oppsett/[id]` */
export function rutenavn(filsti: string): string {
  const etter = filsti.replace(/\\/g, '/').split('/src/app/')[1]
  if (etter === undefined) return ''
  const deler = etter
    .replace(/\/page\.tsx$/, '')
    .split('/')
    // Rutegrupper — (beskyttet), (auth) — er organisering, ikke URL.
    .filter((d) => d !== '' && !/^\(.*\)$/.test(d))
  return `/${deler.join('/')}`
}

/**
 * Menypunktene, som «/sti roller:A,B».
 *
 * Leses fra kilden framfor å importeres, fordi layout.tsx drar med seg
 * halve appen ved import — og en fasit som krever at appen bygger, er
 * ubrukelig akkurat når man har brekt noe.
 */
export function menypunkter(layoutKilde: string): string[] {
  const ut: string[] = []
  const re = /\{\s*sti:\s*'([^']+)'\s*,\s*tekst:\s*'([^']*)'\s*,\s*roller:\s*\[([^\]]*)\]/g
  for (const m of layoutKilde.matchAll(re)) {
    const roller = m[3]
      .split(',')
      .map((r) => r.trim().replace(/^'|'$/g, ''))
      .filter(Boolean)
      .sort()
    ut.push(`${m[1]} roller:${roller.join(',')}`)
  }
  return ut.sort()
}

/**
 * Eksporterte serverhandlinger — det brukeren kan GJØRE.
 *
 * En knapp kan flyttes til et sidepanel uten at noe går tapt. Blir
 * handlingen bak den borte, er en evne borte.
 */
export function serverhandlinger(kilde: string): string[] {
  if (!/^\s*(['"])use server\1/.test(kilde.split('\n').find((l) => l.trim() !== '') ?? '')) {
    return []
  }
  return [...kilde.matchAll(/^export\s+async\s+function\s+(\w+)/gm)]
    .map((m) => m[1])
    .sort()
}

/** Overskriftene på en side. Rå kilde — `{uttrykk}` beholdes som skrevet. */
export function seksjoner(kilde: string): string[] {
  return [...kilde.matchAll(/<h2[^>]*>([\s\S]{0,120}?)<\/h2>/g)]
    .map((m) => m[1].replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .sort()
}

/**
 * Interne lenker ut av siden — navigasjonsveiene.
 *
 * Blir en vei borte, kan en side ha blitt uoppnåelig selv om ruta
 * fortsatt finnes. Det er den lumske varianten: alt er der, men ingen
 * kommer seg dit.
 */
export function lenker(kilde: string): string[] {
  const ut = new Set<string>()
  for (const m of kilde.matchAll(/href=(?:"([^"]+)"|\{`([^`]+)`\})/g)) {
    const h = (m[1] ?? m[2] ?? '').split('?')[0]
    // Bare interne sider. Ankere og utsiden er ikke navigasjon i systemet.
    if (h.startsWith('/') && !h.startsWith('//')) ut.add(h)
  }
  return [...ut].sort()
}

/** Hva som mangler i `ny` mot `gammel`. Rekkefølge er likegyldig. */
export function borte(gammel: string[], ny: string[]): string[] {
  const finnes = new Set(ny)
  return gammel.filter((x) => !finnes.has(x))
}

/** Samme, for et oppslag av lister. Returnerer bare nøkler som mistet noe. */
export function borteI(
  gammel: Record<string, string[]>,
  ny: Record<string, string[]>,
): Record<string, string[]> {
  const ut: Record<string, string[]> = {}
  for (const [nokkel, verdier] of Object.entries(gammel)) {
    const mangler = borte(verdier, ny[nokkel] ?? [])
    if (mangler.length > 0) ut[nokkel] = mangler
  }
  return ut
}
