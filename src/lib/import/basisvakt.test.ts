import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// ARBEIDSTIDEN SKAL SKRIVES, ATOMISK, OG VED SIDEN AV `stempling`
//
// `0219` ga Easy@Works arbeidstidsobservasjon et sted å bo. Denne vakten
// holder koblingen på plass — og holder den fra å spise den gamle.
//
// ---------------------------------------------------------------------
// DEN FARLIGSTE REGRESJONEN ER IKKE AT NOE FEILER
//
// Den er at `lagreStempling` blir borte fordi noen tenker at `basisvakt`
// «erstatter» den. Den gjør den ikke. `stempling` er Sentiqas egen
// arbeidstidsmodell og mater `/lonn`, vaktplanen og Visma-fila;
// `basisvakt` er kildeobservasjonen lønnsmotoren leser. To spørsmål, to
// tabeller, én fil — og differansen måles i notatet i stedet for å antas
// bort.
//
// Forsvinner `lagreStempling`, feiler ingenting med en gang: importen
// melder grønt, `basisvakt` fylles, og Visma-fila blir tom neste måned.
//
// ---------------------------------------------------------------------
// HVORFOR EN KILDELESENDE VAKT
//
// `lagreBasisvakt` og `behandleJobbKjerne` er ikke eksportert, og skal
// ikke bli det bare for å kunne testes. Det som kan regrere er STRUKTUR:
// at kallet forsvinner, at RPC-en byttes mot skriving fra klienten,
// eller at feilen svelges. Alt tre er synlig i kilden og usynlig i
// tallene. Samme form som `envei.test.ts` og `lonnsregister.test.ts`.
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

/** Grenen i `behandleJobbKjerne` som håndterer Basis Export. */
function stemplingsgrenen(): string {
  const start = kilde.indexOf("case 'easyatwork_stempling': {")
  if (start < 0) throw new Error('fant ikke stemplingsgrenen')
  const slutt = kilde.indexOf('\n      }\n', start)
  if (slutt < 0) throw new Error('fant ikke slutten på grenen')
  return kilde.slice(start, slutt)
}

describe('arbeidstiden skrives ved import', () => {
  it('KANARI: begge utsnittene blir funnet', () => {
    // Byttes navn eller struktur, blir utsnittene tomme — og hver
    // påstand under ville vært sann fordi det ikke er noe å måle.
    expect(kropp('lagreBasisvakt').length).toBeGreaterThan(800)
    expect(stemplingsgrenen().length).toBeGreaterThan(200)
  })

  it('grenen kaller lagreBasisvakt, og venter på den', () => {
    // `toContain` holder ikke: et dødt `void (async () => ...)` ville
    // latt navnet stå mens ingenting ble skrevet. Den fella tok meg på
    // lønnsregisteret.
    expect(stemplingsgrenen()).toMatch(/const basisnotat = await lagreBasisvakt\(/)
  })

  it('DEN VIKTIGSTE: lagreStempling er fortsatt der', () => {
    // `basisvakt` kommer I TILLEGG, ikke i stedet for. `/lonn`,
    // vaktplanen og Visma-fila leser `stempling`.
    expect(stemplingsgrenen()).toMatch(/await lagreStempling\(/)
  })

  it('grenen fører notatet videre', () => {
    expect(stemplingsgrenen()).toMatch(/basisnotat\.notat/)
  })

  it('notatet kan ikke redde en jobb som ikke skrev noe', () => {
    // `status` settes av `antallRader === 0 && !notat`.
    expect(stemplingsgrenen())
      .toMatch(/basisnotat\.rader > 0 \|\| res\.antallRader > 0/)
  })

  it('skriver gjennom den atomiske RPC-en', () => {
    expect(kropp('lagreBasisvakt')).toContain("supabase.rpc('basisvakt_snapshot'")
  })

  it('skriver ALDRI mot tabellen direkte', () => {
    // En delete + insert fra klienten er to transaksjoner. Feiler den
    // andre, er stasjonsmåneden tom — og en tom måned ser ut som «ingen
    // jobbet», ikke som «importen feilet».
    expect(kropp('lagreBasisvakt')).not.toContain("from('basisvakt')")
  })

  it('sjekker feilen fra RPC-en', () => {
    // `supabase.rpc` KASTER IKKE. En try/catch rundt den fanger ingenting.
    const k = kropp('lagreBasisvakt')
    expect(k).toMatch(/const \{ data, error \} = await supabase\.rpc/)
    expect(k).toMatch(/if \(error\)[\s\S]{0,200}throw new Error/)
  })

  it('bare CSV — PDF har ikke arbeidssted per rad', () => {
    // Uten `Lokasjon` per rad er hele poenget med kilden borte, og da
    // skrives ingenting heller enn noe halvt.
    expect(kropp('lagreBasisvakt')).toContain('erBasiseksportFil(tekst)')
  })

  it('krever én entydig kjent stasjon', () => {
    // Snapshotet ERSTATTER hele stasjonsmåneden. Bar en fil to
    // stasjoner, ville en import av den ene slettet den andres.
    const k = kropp('lagreBasisvakt')
    expect(k).toContain('kjente.length !== 1')
    expect(k).toContain('p_stasjon_id: stasjonId')
  })

  it('grupperer per måned, ikke per fil', () => {
    // En fil kan bære 19 måneder. Ett snapshot for hele fila ville gjort
    // hver måned til en del av et tall ingen kan erstatte alene.
    const k = kropp('lagreBasisvakt')
    expect(k).toContain('perMaaned')
    expect(k).toMatch(/p_maaned: maaned/)
  })

  it('lagrer også de avviste radene', () => {
    // En rad vi ikke kunne bruke skal ikke forsvinne: uten den kan
    // datagrunnlaget ikke vite at fila inneholdt noe ubrukelig.
    const k = kropp('lagreBasisvakt')
    expect(k).toContain('r.avvik.map(')
    expect(k).toMatch(/avvik_grunn: a\.grunn/)
  })

  it('sammenslåingen bruker fra_dato, ikke forretningsdatoen', () => {
    // DEN DYRESTE FEILEN I MODELLEN, gjort én gang før: med
    // forretningsdatoen som nøkkel forsvant 0,93 ekte timer på Dale 31.
    // juli, og avviket så BEDRE ut fordi data ble slettet. Målt over
    // kontrollfilene: 10 rader ville kollidert.
    const k = kropp('lagreBasisvakt')
    expect(k).toMatch(/\$\{x\.ansatt_nr\}\|\$\{x\.fra_dato\}\|\$\{x\.fra_tid\}/)
  })

  it('måler differansen mot stempling i stedet for å anta den bort', () => {
    // To lesninger av samme fil: `stempling` stoler på «Lengde», denne
    // kontrollerer den mot klokkeslettene. At de kan skille lag er ikke
    // en feil — men det skal være synlig.
    const k = kropp('lagreBasisvakt')
    expect(k).toContain('minutterStempling')
    expect(k).toContain('minutterBasis')
  })
})
