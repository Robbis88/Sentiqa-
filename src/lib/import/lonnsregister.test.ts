import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// REGISTERET SKAL SKRIVES, OG DET SKAL SKRIVES ATOMISK
//
// Satsen har alltid vært i lønnsgrunnlaget. Den ble brukt til å regne
// `belop_kr` og deretter kastet — `lonnsart_linje` har ingen kolonne for
// den. Motoren fra trinn 1 kunne derfor bare kjøre på en fil i hånden,
// aldri på det som lå i basen. `0218` ga den et sted å bo, og denne
// vakten holder koblingen på plass.
//
// ---------------------------------------------------------------------
// HVORFOR EN KILDELESENDE VAKT OG IKKE EN ATFERDSTEST
//
// `lagreRegister` og `behandleJobbKjerne` er ikke eksportert, og skal
// ikke bli det bare for å kunne testes. Det som kan regrere her er
// STRUKTUR: at kallet forsvinner, eller at noen bytter den atomiske
// RPC-en mot en delete + insert fra klienten. Begge deler er synlige i
// kilden, og begge ville vært usynlige i tallene.
//
// Samme form som `envei.test.ts`, av samme grunn: to rundturer er to
// transaksjoner, og feiler den andre står registeret TOMT for den
// stasjonsmåneden. Et tomt register ser ut som «ingen ansatte», ikke som
// «importen feilet».
// =====================================================================

const FIL = join(process.cwd(), 'src', 'lib', 'import', 'kjerne.ts')
const kilde = readFileSync(FIL, 'utf8').replace(/\r\n/g, '\n')

/** Kroppen til en `async function` på toppnivå. */
function kropp(navn: string): string {
  const start = kilde.indexOf(`async function ${navn}(`)
  if (start < 0) throw new Error(`fant ikke ${navn} i kjerne.ts`)
  const slutt = kilde.indexOf('\n}\n', start)
  if (slutt < 0) throw new Error(`fant ikke slutten på ${navn}`)
  return kilde.slice(start, slutt + 3)
}

/** Grenen i `behandleJobbKjerne` som håndterer lønnsgrunnlaget. */
function lonnsgrunnlagsgrenen(): string {
  const start = kilde.indexOf("case 'easyatwork_lonnsgrunnlag': {")
  if (start < 0) throw new Error('fant ikke lønnsgrunnlagsgrenen')
  const slutt = kilde.indexOf('\n      }\n', start)
  if (slutt < 0) throw new Error('fant ikke slutten på grenen')
  return kilde.slice(start, slutt)
}

describe('lønnsregisteret skrives ved import', () => {
  it('KANARI: begge utsnittene blir funnet', () => {
    // Byttes navn eller struktur, blir utsnittene tomme — og hver
    // påstand under ville vært sann fordi det ikke er noe å måle.
    expect(kropp('lagreRegister').length).toBeGreaterThan(400)
    expect(lonnsgrunnlagsgrenen().length).toBeGreaterThan(80)
  })

  it('lønnsgrunnlagsgrenen kaller lagreRegister', () => {
    // UTEN DETTE ER SATSEN TAPT IGJEN. Ingenting ville feilet: importen
    // melder grønt, `lonnsart_linje` fylles som før, og registeret
    // forblir tomt. Motoren ville rapportert hver time som ukoblet.
    // `toContain('lagreRegister(')` HOLDT IKKE. En injeksjon som byttet
    // kallet mot et dødt `void (async () => lagreRegister(...))` lot
    // vakten stå grønn: navnet var der, men ingen ventet på det.
    // Registeret ville ikke blitt skrevet, og ingenting ville sagt fra.
    expect(lonnsgrunnlagsgrenen()).toMatch(/const registernotat = await lagreRegister\(/)
  })

  it('grenen fører registernotatet videre til jobben', () => {
    // En handling som lykkes uten å si fra, ser ut som en som feilet.
    // Notatet er det eneste stedet importen kan forklare hva den skrev.
    expect(lonnsgrunnlagsgrenen()).toMatch(/registernotat\.notat/)
  })

  it('notatet kan ikke redde en jobb som ikke skrev noe', () => {
    // `status` settes av `antallRader === 0 && !notat`. Et notat som
    // alltid følger med ville gjort en fil uten en eneste kjent stasjon
    // til «parset» - og en import som ikke importerte noe ville sett ut
    // som en vellykket en.
    expect(lonnsgrunnlagsgrenen())
      .toMatch(/registernotat\.rader > 0 \|\| res\.antallRader > 0/)
  })

  it('skriver gjennom den atomiske RPC-en', () => {
    expect(kropp('lagreRegister')).toContain("supabase.rpc('lonnsregister_snapshot'")
  })

  it('skriver ALDRI mot tabellen direkte', () => {
    // En delete + insert fra klienten er to transaksjoner. Feiler den
    // andre, er stasjonsmåneden tom — og forrige snapshot er borte.
    expect(kropp('lagreRegister')).not.toContain("from('lonnsregister')")
  })

  it('sjekker feilen fra RPC-en', () => {
    // `supabase.rpc` KASTER IKKE. Den returnerer feilen i `error`, og en
    // try/catch rundt den fanger ingenting. 15 svelgede feil ble til 0
    // den gangen denne regelen ble skrevet.
    const k = kropp('lagreRegister')
    expect(k).toMatch(/const \{ data, error \} = await supabase\.rpc/)
    expect(k).toMatch(/if \(error\)[\s\S]{0,200}throw new Error/)
  })

  it('tar stasjon og måned fra én entydig stasjon, ikke fra et gjett', () => {
    // Snapshotet ERSTATTER hele stasjonsmåneden. Bar en fil to
    // stasjoner, ville en import av den ene slettet den andres register.
    const k = kropp('lagreRegister')
    expect(k).toContain('kjente.length !== 1')
    expect(k).toContain('p_stasjon_id: stasjonId')
  })

  it('skriver også dem uten timesats', () => {
    // UKJENT SATS ER IKKE FRAVÆR. Skrives de ikke, kan ingen skille
    // «easy@work mangler en sats her» fra «personen finnes ikke» — og
    // bare den første kan rettes.
    expect(kropp('lagreRegister')).toContain('a.utenSats.map(')
  })
})
