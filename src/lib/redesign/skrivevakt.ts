// =====================================================================
//
// 2026-08-22: TALLET ER NULL. Alle 89 stedene tar naa imot svaret via
// `maaLykkes` i `src/lib/skriv-svar.ts`. Skrallen er dermed ikke lenger
// en nedstigning mot et maal - den er et gulv. Ett nytt kastet skriv
// gjoer den roed, og det er meningen.
//
// `maaLykkes(await supabase...)` telles ikke, og skal ikke telles:
// linja begynner ikke med `await`, og resultatet HAR en mottaker som
// ser paa `error`. Det er hele forskjellen denne vakten maaler.
// Skrivevakten: en serverhandling skal ikke kunne svelge feilen sin.
//
// PERMANENT KONTRAKT, satt av Robert 2026-08-21:
//
//   «Ingen skrivende serverhandling på denne flaten skal kunne returnere
//    som om alt gikk bra dersom Supabase faktisk returnerte en feil.»
//
// Bakgrunnen: `settDekning` returnerte `void` og ignorerte `{ error }`.
// En avvist lagring så nøyaktig ut som en vellykket — knappen ble
// trykket, siden lastet, ingenting hadde skjedd. Robert meldte «det går
// ikke an å lagre», og hadde ingenting å gå på, for det fantes ingenting
// å se. Feilsøkingen ble gjetting i stedet for observasjon.
//
// HVA DENNE MÅLER, OG HVA DEN IKKE KAN MÅLE.
//
// Å avgjøre om `error` faktisk BLIR SJEKKET krever å følge en variabel
// gjennom kontrollflyten. Det er en typeanalyse, ikke en skralle, og en
// halvgod versjon ville meldt falske funn på riktig kode — som er den
// sikreste måten å lære folk å ignorere en vakt på.
//
// Derfor måler den ett forhold som er entydig avgjørbart: er resultatet
// KASTET? `await supabase.from(...).insert(...)` som en frittstående
// setning har ingen mottaker. Da finnes `{ error }` ikke engang som en
// variabel, og kontrakten kan umulig være oppfylt.
//
// Det er en nedre grense, ikke en fasit. Den fanger ikke koden som tar
// imot `{ error }` og lar den ligge — men den fanger den formen som er
// vanlig, og som var feilen.
// =====================================================================

/** Kallene som skriver. `select` teller ikke — en lesefeil gir tom liste. */
const SKRIVER = /\.(insert|update|upsert|delete)\s*\(/

/**
 * Fjerner kommentarer, så et eksempel i en kommentar ikke telles.
 *
 * Samme grep som `design.ts` bruker, og av samme grunn: en vakt som
 * teller sine egne forklaringer måler seg selv.
 */
export function utenKommentarer(kilde: string): string {
  return kilde
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))
    .replace(/(^|[^:])\/\/[^\n]*/g, (_m, f: string) => f)
}

/**
 * Linjene der et skrivekall er kastet.
 *
 * KJENNETEGNET ER `await` FØRST PÅ LINJA. Da er hele uttrykket en
 * setning uten mottaker:
 *
 *     await supabase.from('x').insert({ … })        ← kastet
 *     const { error } = await supabase…insert(…)    ← tatt imot
 *     return await supabase…insert(…)               ← gitt videre
 *
 * `return`, `const`, `=` og `(` foran gjør at verdien går et sted.
 */
export function kastedeSkriv(kilde: string): number[] {
  const linjer = utenKommentarer(kilde).split('\n')
  const funn: number[] = []

  linjer.forEach((rad, i) => {
    if (!/^\s*await\s/.test(rad)) return

    // Kallet kan gå over flere linjer: `await supabase` på én,
    // `.insert({` på neste. Vi ser framover til setningen tar slutt.
    let bit = rad
    for (let j = i + 1; j < linjer.length && j < i + 12; j++) {
      if (/^\s*(await|const|let|return|if|}|\/)/.test(linjer[j])) break
      bit += '\n' + linjer[j]
    }
    if (SKRIVER.test(bit) && /supabase|klient|db\b/i.test(bit)) funn.push(i + 1)
  })

  return funn
}

/** Filer som skal måles: serverhandlinger og API-ruter. */
export function erServerfil(kilde: string): boolean {
  return /^\s*['"]use server['"]/m.test(kilde)
}
