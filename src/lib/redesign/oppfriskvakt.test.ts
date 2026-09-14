import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { execSync } from 'node:child_process'
import { utenKommentarer } from './skrivevakt'

// =====================================================================
// `oppfrisk` OG `revalidatePath` KAN IKKE STAA SAMMEN
// =====================================================================
//
// Maalt i produksjonssporet 2026-09-14, PR #281 paa `main`:
//
//   0,95 s  POST /maanedsplan   next-action: 60d9b560...
//   1,45 s  200  text/x-component   x-action-revalidated: 1
//   2,14 s  siste nettverkshendelse i hele sporet
//   20,99 s timeout - knappen fortsatt «Bygger …», ingen kvittering
//
// Handlingen LYKTES. Planene ble skrevet. Nettverket var stille i 19
// sekunder. Likevel kom kvitteringen aldri, og knappen forlot aldri
// ventetilstanden.
//
// ---------------------------------------------------------------------
// HVORFOR
// ---------------------------------------------------------------------
//
// `useActionState` holder `venter` sann gjennom HELE overgangen sin. Da
// #281 fjernet revalideringen av EGEN rute, trodde vi koblingen var
// borte. Den var ikke det:
//
//   **Next setter `x-action-revalidated: 1` og sender en fersk
//   flight-payload for ruta du STAAR PAA saa snart handlingen
//   revaliderer NOE SOM HELST.**
//
// `revalidatePath('/min-plan')` er en annen rute, men den purrer
// klientcachen (`revalidatePath`-doksene: «This will purge the Client
// Cache»), og da blir ruteroppdateringen av `/maanedsplan` en del av
// handlingens egen overgang igjen. Oppa det kaller `HandlingKnapp` sin
// `router.refresh()`. To ruteroppdateringer i samme overgang, og naar de
// fletter seg feil, committer React aldri - verken kvitteringen eller
// den aktive knappen naar skjermen.
//
// ---------------------------------------------------------------------
// HVORFOR DET ER TRYGT AA FJERNE REVALIDERINGEN
// ---------------------------------------------------------------------
//
// Hver side under `(beskyttet)` kaller `lagSupabaseServerKlient()`, som
// awaiter `cookies()`. Sidene er derfor DYNAMISKE - det finnes ingen
// cachet utgave aa invalidere. Og `staleTimes.dynamic` har vaert **0
// sekunder siden Next 15**, saa klienten henter `/min-plan` ferskt ved
// hver navigering uansett.
//
// Revalideringen kostet oss feilen og ga oss ingenting.
//
// ---------------------------------------------------------------------
// REGELEN
// ---------------------------------------------------------------------
//
// Bruker en rute `HandlingKnapp` med `oppfrisk`, skal handlingene i
// samme rute ikke revalidere NOEN sti - heller ikke en annen enn sin
// egen. Oppfriskningen gjoeres av klienten, i sin EGEN transition.
// =====================================================================

/** Bar `oppfrisk`-prop paa HandlingKnapp. Ikke `oppfrisk={...}`. */
const BRUKER_OPPFRISK = /\boppfrisk\b(?!\s*[:=?])/

/** `revalidatePath(...)` eller `oppfrisk: [...]` sendt til `kvitter`. */
const REVALIDERER = /\brevalidatePath\s*\(|\boppfrisk\s*:/

function tsxFiler(): string[] {
  const sporede = execSync('git ls-files "src/**/*.tsx"', { encoding: 'utf8' })
  const nye = execSync(
    'git ls-files --others --exclude-standard "src/**/*.tsx"',
    { encoding: 'utf8' },
  )
  return [...new Set(`${sporede}\n${nye}`.split('\n').filter(Boolean))]
}

/** Rutene som ber klienten friske opp sida etter en handling. */
function ruterMedOppfrisk(): { fil: string; handlinger: string }[] {
  const funn: { fil: string; handlinger: string }[] = []
  for (const fil of tsxFiler()) {
    // `handling-knapp.tsx` DEFINERER proppen. Den bruker den ikke.
    if (fil.endsWith('components/ui/handling-knapp.tsx')) continue
    const kilde = utenKommentarer(readFileSync(fil, 'utf8'))
    if (!BRUKER_OPPFRISK.test(kilde)) continue
    funn.push({ fil, handlinger: join(dirname(fil), 'handlinger.ts') })
  }
  return funn
}

describe('maalingen forstaar det den ser', () => {
  // KANARIFUGLENE. En vakt som slutter aa se, ser noeyaktig ut som en
  // vakt som ikke finner noe. Disse feiler hvis regexene slutter aa
  // treffe det de er skrevet for.
  test('kjenner igjen en bar oppfrisk-prop', () => {
    expect(BRUKER_OPPFRISK.test('  oppfrisk\n')).toBe(true)
    expect(BRUKER_OPPFRISK.test('<HandlingKnapp oppfrisk />')).toBe(true)
  })

  test('forveksler ikke proppen med definisjonen eller et objektfelt', () => {
    expect(BRUKER_OPPFRISK.test('oppfrisk?: boolean')).toBe(false)
    expect(BRUKER_OPPFRISK.test('oppfrisk = false')).toBe(false)
    expect(BRUKER_OPPFRISK.test("oppfrisk: ['/min-plan']")).toBe(false)
  })

  test('kjenner igjen begge formene for revalidering', () => {
    expect(REVALIDERER.test("revalidatePath('/min-plan')")).toBe(true)
    expect(REVALIDERER.test('revalidatePath ( x )')).toBe(true)
    expect(REVALIDERER.test("oppfrisk: ['/min-plan']")).toBe(true)
    expect(REVALIDERER.test('const oppfrisk = true')).toBe(false)
  })

  test('det finnes minst én rute som bruker oppfrisk', () => {
    // Uten en eneste treffende rute maaler regelen under ingenting, og
    // en tom liste ville sett ut som «alt er i orden».
    expect(ruterMedOppfrisk().length).toBeGreaterThan(0)
  })
})

describe('en rute som friskes opp av klienten revaliderer ikke paa serveren', () => {
  for (const { fil, handlinger } of ruterMedOppfrisk()) {
    test(`${fil} -> ${handlinger}`, () => {
      let kilde: string
      try {
        kilde = utenKommentarer(readFileSync(handlinger, 'utf8'))
      } catch {
        // Ingen handlinger.ts ved siden av. Da er det ingenting aa maale,
        // og det er et gyldig utfall - ikke en stille bestaatt.
        return
      }
      const treff = kilde.match(REVALIDERER)
      expect(
        treff,
        `${handlinger} revaliderer (${treff?.[0]}) mens ${fil} bruker `
        + '`oppfrisk`. Da setter Next `x-action-revalidated: 1`, og '
        + 'ruteroppdateringen blir en del av handlingens egen overgang '
        + '- sammen med klientens `router.refresh()`. Maalt 2026-09-14: '
        + 'kvitteringen kom aldri, knappen sto «Bygger …» i 20 sekunder '
        + 'etter at handlingen hadde lykkes. Fjern revalideringen; '
        + 'sidene er dynamiske og `staleTimes.dynamic` er 0.',
      ).toBeNull()
    })
  }
})
