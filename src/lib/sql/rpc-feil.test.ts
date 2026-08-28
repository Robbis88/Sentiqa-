import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// ET RPC-KALL SOM SVELGER FEILEN SIN.
//
// `const { data } = await supabase.rpc('malekort_stasjoner')` er
// billigere å skrive enn å sjekke `error`. Prisen betales et helt annet
// sted: da `0075` aldri ble kjørt mot produksjon, viste `/maaling`
// «Ingen stasjoner.» — en sann setning som beskriver noe helt annet enn
// det som skjedde. **En kjede uten stasjoner og et kall som feiler ser
// helt like ut.**
//
// Samme dag fant vi at `0065` var kjørt halvveis: `svinn_sum` manglet.
// To flater kaller den, begge svelger, og svinnvarslene hadde vært
// stille i månedsvis uten et eneste spor.
//
// ---------------------------------------------------------------------
// HVORFOR SKRALLE OG IKKE PORT
//
// Tjueén kallsteder svelget da denne ble skrevet; femten står igjen
// etter at de fire flatene vi VET var ødelagte ble rettet. Å kreve null
// med én gang ville betydd én stor PR gjennom hele kodebasen, og en vakt
// som blokkerer arbeid som ikke gjør ting verre blir slått av.
//
// Tallet får aldri gå opp. Nye kall må sjekke `error`; de gamle rettes
// når noen er i fila likevel. Samme mekanikk som fargevakten, og den
// virker av samme grunn.
//
// ---------------------------------------------------------------------
// HVA DEN IKKE SER
//
// Den leser tekst, ikke typer. Et kall som destrukturerer `error` og så
// ignorerer variabelen teller som sjekket. Det er greit: vakten er der
// for å fange formen der feilen ikke engang er TILGJENGELIG — og et
// ubrukt `error` synes i lint.
// =====================================================================

const SRC = join(process.cwd(), 'src')

/**
 * Antall kallsteder som ikke har `error` tilgjengelig.
 *
 * SKAL BARE NED. Rettes et kall, senk tallet i samme PR — ellers
 * beskytter skrallen en gjeld som alt er betalt.
 */
const FASIT = 15

function kildefiler(katalog: string): string[] {
  const ut: string[] = []
  for (const navn of readdirSync(katalog)) {
    const sti = join(katalog, navn)
    if (statSync(sti).isDirectory()) ut.push(...kildefiler(sti))
    else if (/\.tsx?$/.test(navn) && !/\.test\.tsx?$/.test(navn)) ut.push(sti)
  }
  return ut
}

/**
 * Kallsteder i én fil som ikke ser `error`.
 *
 * VINDUET ER FEM LINJER BAKOVER, ikke bare linja selv. Halvparten av
 * kallene ligger inne i en `Promise.all([...])` der destruktureringen
 * står på linja over — en sjekk på samme linje ville meldt hvert av dem
 * som svelget, og en vakt med falske positive lærer folk å se bort fra
 * rødt.
 */
export function svelgendeKall(kilde: string): number[] {
  const linjer = kilde.split('\n')
  const ut: number[] = []
  for (let i = 0; i < linjer.length; i++) {
    if (!/\.rpc\(/.test(linjer[i])) continue
    // Kommentarer teller ikke - denne fila og funksjoner.ts omtaler
    // formen i prosa, og en omtale er ikke et kall.
    if (/^\s*(\/\/|\*|\/\*)/.test(linjer[i])) continue
    const vindu = linjer.slice(Math.max(0, i - 5), i + 1).join('\n')
    if (!/\berror\b/.test(vindu)) ut.push(i + 1)
  }
  return ut
}

const treff = kildefiler(SRC).flatMap((f) =>
  svelgendeKall(readFileSync(f, 'utf8')).map((l) => `${f.slice(SRC.length + 1).replace(/\\/g, '/')}:${l}`))

describe('rpc-kall som svelger feilen sin', () => {
  it(`er ${FASIT} eller færre — tallet skal bare ned`, () => {
    expect(
      treff.length,
      `Et nytt rpc-kall sjekker ikke \`error\`:\n${treff.join('\n')}\n\n`
      + 'Skriv `const { data, error } = await supabase.rpc(...)` og gjor noe '
      + 'med feilen. Uten den kan et kall mot en funksjon som ikke finnes '
      + 'gi tom liste i stedet for en feilmelding - og da ser «ingen data» '
      + 'ut som «alt er som det skal». Rettet du et gammelt kall: senk FASIT.',
    ).toBeLessThanOrEqual(FASIT)
  })

  it('KANARIFUGL: den finner faktisk kall, og kjenner begge formene', () => {
    // Slutter regexen aa treffe, blir lista tom - og null svelgende kall
    // ser noeyaktig ut som en ryddig kodebase.
    expect(svelgendeKall("const { data } = await supabase.rpc('x')")).toEqual([1])
    expect(svelgendeKall("const { data, error } = await supabase.rpc('x')")).toEqual([])
    expect(svelgendeKall("const { error } = await supabase.rpc('x')")).toEqual([])
    // Promise.all: destruktureringen staar over kallet.
    expect(svelgendeKall(
      'const [{ data: a }, { data: b }] = await Promise.all([\n'
      + "  supabase.rpc('x'),\n"
      + "  supabase.rpc('y'),\n"
      + '])',
    )).toEqual([2, 3])
    expect(svelgendeKall(
      'const [{ data: a, error: e }] = await Promise.all([\n'
      + "  supabase.rpc('x'),\n"
      + '])',
    )).toEqual([])
  })

  it('KANARIFUGL: den leser en kodebase som finnes', () => {
    // Et gulv paa null ville bestaatt ogsaa hvis SRC var tom eller
    // filfilteret sluttet aa treffe.
    expect(kildefiler(SRC).length).toBeGreaterThan(100)
  })

  it('de fire vi VET var oedelagte er rettet', () => {
    // malekort_stasjoner (to steder) og svinn_sum (to steder). Der er
    // gjelden ikke teoretisk - der har tall vaert borte fra skjermen.
    const uspesifikk = treff.join('\n')
    expect(uspesifikk).not.toContain('maaling/page.tsx')
    expect(uspesifikk).not.toContain('vaar-stasjon/page.tsx')
    expect(uspesifikk).not.toContain('regnskap-varsler.ts')
    expect(uspesifikk).not.toContain('ai/regnskapsanalyse.ts')
  })
})
