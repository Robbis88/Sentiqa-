import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { maal, summer, utenKommentarer, vokst, SIGNALER, type Designmaal } from './design'

// =====================================================================
// Design-skrallen.
//
// Feiler hvis et av signalene har VOKST siden sist. Skal noe faktisk
// legges til med vilje - en inline-stil det ikke finnes token for -
// erklarer du det:
//
//     OPPDATER_FASIT=1 npx vitest run src/lib/redesign
//
// Da viser git at tallet gikk opp, og hvem som lot det skje. Det er
// forskjellen paa et unntak og en gradvis oppolsning.
// =====================================================================

const ROT = process.cwd()
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'designfasit.json')

function tsxFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsxFiler(sti))
    else if (rad.name.endsWith('.tsx')) ut.push(sti)
  }
  return ut
}

const filer = [
  ...tsxFiler(join(ROT, 'src', 'app')),
  ...tsxFiler(join(ROT, 'src', 'components')),
]
const naa = summer(filer.map((f) => maal(readFileSync(f, 'utf8'))))

// Enhetstestene foerst. En skralle som ikke forstaar det den teller, er
// et tall uten mening - og den ville vaert groenn hele veien.
describe('maalingen forstaar det den teller', () => {
  test('kommentarer teller ikke', () => {
    // Da emojiene ble ryddet i dag, ble det skrevet kommentarer om hva
    // som sto der foer - med emojien i. Teller vi dem, blir det dyrere
    // aa forklare enn aa slette i stillhet.
    const kilde = '// Sto med \u{1F947} paa topp tre\nconst a = 1\n'
    expect(maal(kilde).emoji).toBe(0)
  })

  test('men emoji i JSX teller', () => {
    expect(maal('<span>\u{1F947} Gull</span>').emoji).toBe(1)
  })

  test('funksjonelle glyffer er lov', () => {
    // Kryss, hake og dra-haandtak gjor en jobb ord ikke gjor paa en
    // knapp. De skal ikke telle som ikonografi.
    expect(maal('<button>✓</button><span>✕</span><i>⠿</i>').emoji).toBe(0)
  })

  test('variasjonsvelger avslorer emoji-utseende', () => {
    expect(maal('<span>⚠️</span>').emoji).toBe(1)
  })

  test('URL i en streng gjor ikke maalingen blind', () => {
    // En naiv //-stripping spiser resten av linja fra https:// og
    // dermed style-en etter den. Da synker tallene og alt ser bedre ut.
    const kilde = 'const u = "https://kart.no/x"\n<div style={{ margin: 0 }} />'
    expect(maal(kilde).inlineStil).toBe(1)
  })

  test('blokkommentar teller ikke, kode etter den gjor', () => {
    expect(maal('/* <table> i en kommentar */\n<table>').raaTabell).toBe(1)
  })

  test('escapet apostrof forskyver ikke resten av fila', () => {
    // Handteres ikke \' inne i en streng, lukkes strengen for tidlig.
    // Da tolkes «t'» som starten paa en NY streng, //-kommentaren under
    // blir aldri sett som kommentar, og <table> i den telles med.
    // Feilen ville gitt for HOEYE tall her - men samme forskyvning kan
    // like gjerne svelge ekte kode og gi for lave.
    const kilde = "const s = 'don\\'t'\n// kommentar med <table>\n<table>"
    expect(maal(kilde).raaTabell).toBe(1)
  })

  test('tekst i en streng teller - det er ogsaa brukergrensesnitt', () => {
    // Strenger fjernes IKKE. En emoji i `tekst: '🎉 Ferdig'` staar paa
    // skjermen like mye som en i JSX, og skal telle.
    expect(maal("const t = 'Ferdig \u{1F389}'").emoji).toBe(1)
  })

  test('hexfarge fanges, css-variabel ikke', () => {
    expect(maal('color: #13203b').hexFarge).toBe(1)
    expect(maal('color: var(--tekst)').hexFarge).toBe(0)
  })

  test('utenKommentarer beholder linjeskift', () => {
    // Ellers kollapser linjenumre, og en feilmelding peker feil sted.
    expect(utenKommentarer('a\n// b\nc\n').split('\n').length).toBe(4)
  })
})

describe('design-skrallen', () => {
  test('skanneren ser fortsatt filene', () => {
    // KANARIFUGL. To vakter i dette repoet har vaert groenne fordi de
    // ikke forsto noe - RLS-vakthunden i maanedsvis, rollevakten i en
    // time. En skralle som slutter aa lese filer, ser ut som en kodebase
    // uten problemer.
    expect(filer.length, 'Skanneren finner nesten ingen .tsx-filer.')
      .toBeGreaterThan(50)
    const total = SIGNALER.reduce((s, k) => s + naa[k], 0)
    expect(total, 'Skanneren teller null av alt. Leser den kilden riktig?')
      .toBeGreaterThan(0)
  })

  test('ingen av signalene har vokst', () => {
    if (process.env.OPPDATER_FASIT === '1' || !existsSync(FASIT)) {
      writeFileSync(FASIT, `${JSON.stringify(naa, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as Designmaal
    const opp = vokst(fasit, naa)
    expect(
      opp,
      'Designsignaler har vokst:\n'
      + opp.map((o) => `  ${o.signal}: ${o.fra} -> ${o.til}`).join('\n')
      + '\n\nBruk komponentene i src/components/ui/ i stedet, eller erklaer'
      + ' med OPPDATER_FASIT=1 npx vitest run src/lib/redesign',
    ).toEqual([])
  })

  test('fasiten foelger med naar tallene synker', () => {
    // En skralle som bare stopper vekst, men aldri strammes, er en
    // skralle som staar stille. Naar et tall har gaatt ned, skal fasiten
    // oppdateres - ellers er det ledig plass til aa skli tilbake.
    if (process.env.OPPDATER_FASIT === '1' || !existsSync(FASIT)) return
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as Designmaal
    const slakk = SIGNALER.filter((s) => naa[s] < fasit[s])
      .map((s) => `  ${s}: fasit ${fasit[s]}, faktisk ${naa[s]}`)
    expect(
      slakk,
      'Signaler har SUNKET - bra. Stram skrallen saa det ikke kan skli'
      + ' tilbake:\n' + slakk.join('\n')
      + '\n\n  OPPDATER_FASIT=1 npx vitest run src/lib/redesign',
    ).toEqual([])
  })
})
