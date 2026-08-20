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
  /** Rolle → alt rollen kan nå, meny og faner sett under ett. */
  naabart: Record<string, string[]>
  handlinger: Record<string, string[]>
  seksjoner: Record<string, string[]>
  lenker: Record<string, string[]>
}

/** `src/app/(beskyttet)/rutiner/oppsett/[id]/page.tsx` → `/rutiner/oppsett/[id]` */
export function rutenavn(filsti: string): string {
  const etter = filsti.replace(/\\/g, '/').split('/src/app/')[1]
  if (etter === undefined) return ''
  const deler = etter
    // Rot-siden er `page.tsx` UTEN skråstrek foran. Krevde mønsteret en,
    // ble forsiden hetende «/page.tsx» — og en rute som heter noe annet
    // enn den er, forsvinner stille neste gang noen sammenligner.
    .replace(/\/?page\.tsx$/, '')
    .split('/')
    // Rutegrupper — (beskyttet), (auth) — er organisering, ikke URL.
    .filter((d) => d !== '' && !/^\(.*\)$/.test(d))
  return `/${deler.join('/')}`
}

/**
 * Hva hver rolle kan nå — meny og faner sett under ett.
 *
 * Dette er det spørsmålet som betyr noe. Å flytte en side fra menyen til
 * en fane er en omorganisering; å ta den ut av begge er et tap. En fasit
 * som teller menylinjer ville ropt på det første og vært blind for
 * forskjellen.
 *
 * Leses fra kilden framfor å importeres: navigasjon.ts drar med seg
 * typer fra appen, og en fasit som krever at appen bygger er ubrukelig
 * akkurat når man har brekt noe.
 *
 * Kortnavnene (`A`, `B`, `T`) løses opp fra deklarasjonene i samme fil,
 * så fasiten inneholder ekte rollenavn og ikke bokstaver som kan bety
 * noe annet i morgen.
 */
export function naabarhet(navigasjonKilde: string): Record<string, string[]> {
  const alias = new Map<string, string>()
  for (const m of navigasjonKilde.matchAll(
    /const\s+(\w+)\s*:\s*Brukerrolle\s*=\s*'([^']+)'/g,
  )) {
    alias.set(m[1], m[2])
  }

  const ut: Record<string, Set<string>> = {}
  // Samme form i SEKSJONER og FANEGRUPPER — ett uttrykk dekker begge.
  const re = /\{\s*sti:\s*'([^']+)'\s*,\s*tekst:\s*'[^']*'\s*,\s*roller:\s*\[([^\]]*)\]/g
  for (const m of navigasjonKilde.matchAll(re)) {
    for (const raa of m[2].split(',')) {
      const t = raa.trim()
      if (!t) continue
      const rolle = alias.get(t) ?? t.replace(/^'|'$/g, '')
      ;(ut[rolle] ??= new Set()).add(m[1])
    }
  }

  return Object.fromEntries(
    Object.entries(ut).map(([rolle, stier]) => [rolle, [...stier].sort()]),
  )
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

/**
 * Overskriftene på en side. Rå kilde — `{uttrykk}` beholdes som skrevet.
 *
 * LESER OGSÅ `tittel`-PROPEN, ikke bare `<h2>`. Da pilot B flyttet tre
 * tabeller inn i `Datatabell`, forsvant tre overskrifter for denne
 * vakten — ikke fordi de var borte fra skjermen, men fordi de hadde
 * flyttet fra en tagg til en prop. Vakten meldte tap. Neste side ville
 * meldt det samme, og den etter der igjen, helt til noen sluttet å lese
 * meldingen. Da hadde en seksjon som FAKTISK forsvant sett ut som resten.
 *
 * `<Sidehode tittel=…>` telles ikke: det er sidas h1, ikke en seksjon.
 * Uten det unntaket ville hver migrerte side fått sitt eget navn inn i
 * seksjonslista, og fasiten blitt full av rader som ikke betyr noe.
 */
export function seksjoner(kilde: string): string[] {
  const ut: string[] = []
  for (const m of kilde.matchAll(/<h[23][^>]*>([\s\S]{0,120}?)<\/h[23]>/g)) {
    ut.push(m[1])
  }
  for (const m of kilde.matchAll(/\btittel=(?:"([^"]{0,200})"|\{)/g)) {
    const foran = /<([A-Z]\w*)[^<]*$/.exec(kilde.slice(0, m.index))
    if (foran?.[1] === 'Sidehode') continue
    if (m[1] !== undefined) {
      ut.push(m[1])
      continue
    }
    // Malstreng: `Per stasjon · ${dato}`. Regex kommer til kort her,
    // fordi `${…}` inni strengen har sine egne backticks og klammer -
    // et uttrykk som `${a ? ` · ${b}` : ''}` har begge deler nostet to
    // niivaaer ned. Klammene telles i stedet, saa slutten blir funnet
    // uansett hvor dypt uttrykket gaar.
    const start = m.index + m[0].length
    let dybde = 1
    let i = start
    for (; i < kilde.length && i < start + 400; i++) {
      if (kilde[i] === '{') dybde++
      else if (kilde[i] === '}' && --dybde === 0) break
    }
    const raa = kilde.slice(start, i).trim()
    // DET MAA FINNES TEKST I DET. `tittel={tittel}` er en variabel, og
    // uten denne linja la vakten ordet «tittel» inn i seksjonslista som
    // om det stod paa skjermen. Pilot C skrev nettopp den formen.
    //
    // Kravet er at det finnes en streng et sted i uttrykket - ikke at
    // uttrykket ER en streng. `o('Ingen anvisninger ennaa')` og
    // `erAdmin ? 'A' : 'B'` har begge tekst som kan endres i stillhet,
    // og de skal fortsatt voktes. `g.navn` har ingen.
    if (!/['"`]/.test(raa)) continue
    // Bare backtickene strippes. Fnuttene inni et uttrykk er en del av
    // uttrykket - tar man dem, endrer teksten seg, og fasiten melder et
    // tap som ikke fant sted.
    ut.push(raa.replace(/^`|`$/g, ''))
  }
  return ut
    .map((t) => t.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .sort()
}

/**
 * Komponentene en fil både importerer LOKALT og faktisk RENDRER.
 *
 * To krav, og begge trengs:
 *
 * LOKALT betyr en relativ sti — `./plan-tabell`, `../ai-kontekst`. Alt
 * annet er utenfor: `@/components/ui` er primitivene (deres overskrifter
 * hører til komponenten, ikke til ruta, og ville dukket opp på hver
 * eneste side som bruker dem), `@/lib` er logikk uten UI, og en pakke fra
 * node_modules er ikke vår.
 *
 * RENDRER betyr at navnet står som `<Navn` et sted i fila. En fil kan
 * importere en type, en hjelpefunksjon eller en konstant fra naboen sin
 * uten at noe av naboens UI havner på skjermen — og da skal heller ikke
 * naboens seksjoner havne i rutas kontrakt.
 */
export function lokaleBarn(kilde: string): string[] {
  const ut: string[] = []
  // `type` FANGES, IKKE SPISES. Foerste utgave skrev `(?:type\s+)?` og
  // slapp dermed `import type { Gruppe } from './g'` gjennom som en
  // vanlig import. En ren typeimport rendrer ingenting. Kanarifuglen
  // under fant det - som er hele grunnen til at den staar der.
  const importer = /^import\s+(type\s+)?(\{[^}]*\}|[A-Za-z_$][\w$]*)[^'\n]*from\s+'(\.[^']+)'/gm
  for (const m of kilde.matchAll(importer)) {
    if (m[1]) continue
    const binding = m[2]
    const navn = binding.startsWith('{')
      ? binding.slice(1, -1).split(',')
          .map((d) => d.trim())
          .filter((d) => d.length > 0 && !d.startsWith('type '))
          .map((d) => d.split(/\s+as\s+/).pop()!.trim())
      : [binding]
    // Store forbokstaver er komponenter; `<Navn` sier at den rendres.
    if (navn.some((n) => /^[A-Z]/.test(n) && new RegExp(`<${n}[\\s/>]`).test(kilde))) {
      ut.push(m[3])
    }
  }
  return ut
}

/** Mappa til en fil, uansett hvilken skråstrek plattformen bruker. */
function mappe(sti: string): string[] {
  return sti.split(/[\\/]/).slice(0, -1)
}

/** `./plan-tabell` fra en fil → full sti, uten node:path. */
function loesSti(fra: string, spesifikator: string): string {
  const skille = fra.includes('\\') ? '\\' : '/'
  const deler = mappe(fra)
  for (const d of spesifikator.split('/')) {
    if (d === '.' || d === '') continue
    else if (d === '..') deler.pop()
    else deler.push(d)
  }
  return deler.join(skille)
}

/**
 * Alle filene som utgjør én rutes synlige flate.
 *
 * HVORFOR DETTE MÅTTE TIL: vakten leste bare `page.tsx`. På
 * /produksjonsplan ligger hele plantabellen — overskrifter, tabeller,
 * publiseringen — i `plan-tabell.tsx`, og var dermed aldri voktet. En
 * side kan flytte alt innholdet sitt inn i en klientkomponent og se helt
 * urørt ut for en vakt som bare ser inngangsdøra.
 *
 * `les` returnerer kildekoden, eller null når fila ikke finnes. Den er et
 * argument og ikke en `readFileSync` her inne nettopp for at testene skal
 * kunne bygge et lite filsystem i minnet og måle grensetilfellene —
 * sykler, dobbeltimport, dybde — uten å legge filer på disk.
 *
 * `rot` er gjerdet: en relativ sti kan i prinsippet klatre ut av
 * app-mappa med nok `../`, og da er vi ikke lenger i rutas UI.
 */
export function rutetre(
  inngang: string,
  les: (sti: string) => string | null,
  rot: string,
  maksDybde = 4,
): string[] {
  const sett = new Set<string>()
  const ut: string[] = []
  const koe: { sti: string; nivaa: number }[] = [{ sti: inngang, nivaa: 0 }]

  while (koe.length > 0) {
    const { sti, nivaa } = koe.shift()!
    // BESOEKT-SETTET ER SYKELVERNET. A → B → A terminerer her, og en
    // komponent som rendres to steder i treet leses bare én gang.
    if (sett.has(sti)) continue
    const kilde = les(sti)
    if (kilde == null) continue
    sett.add(sti)
    ut.push(sti)
    if (nivaa >= maksDybde) continue

    for (const spek of lokaleBarn(kilde)) {
      const base = loesSti(sti, spek)
      const skille = sti.includes('\\') ? '\\' : '/'
      // Bare .tsx. `./handlinger` er serverhandlinger og har ingen UI;
      // de voktes for seg, per mappe.
      for (const kandidat of [`${base}.tsx`, `${base}${skille}index.tsx`]) {
        if (kandidat.includes('.test.')) continue
        if (!kandidat.startsWith(rot)) continue
        if (sett.has(kandidat)) break
        if (les(kandidat) == null) continue
        koe.push({ sti: kandidat, nivaa: nivaa + 1 })
        break
      }
    }
  }
  return ut
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
