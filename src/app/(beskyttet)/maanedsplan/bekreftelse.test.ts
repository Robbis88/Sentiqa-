import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// BEKREFTELSEN MÅ NAVNGI MÅNEDEN
// =====================================================================
//
// 2026-09-14, målt i produksjon:
//
//   14:54:59.626   Laguneparken   juli   sluppet
//   14:55:04.947   Varden         juli   sluppet
//   14:55:07.086   Lone           JUNI   sluppet     <- feil maaned
//
// Slipp hadde ingen bekreftelse. Avvis hadde en, men den navnga bare
// stasjonen: «Avvise månedsplanen for Lone?». Den ville bestått som
// riktig også på juni — stasjonen var jo den man ville ha.
//
// **Et spørsmål som bare bekrefter det man allerede trodde, bekrefter
// også feilen.** Det er måneden som skiller de to radene, og derfor er
// det måneden spørsmålet må si.
//
// Vakten leser kilden fordi alternativet — å måle dialogteksten i
// nettleseren — bare kan kjøres i e2e, og da er regelen borte fra den
// raske porten. `e2e/maanedsplan.spec.ts` teller at dialogen FINNES;
// denne beviser hva den SIER.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'maanedsplan', 'plankort.tsx'),
  'utf8',
).replace(/\r\n/g, '\n') // CRLF ville brutt hvert `[^]*?`-anker under

/** Utsnittet for én `<HandlingKnapp …/>`, kjent igjen på handlingen sin. */
function knapp(kilde: string, handling: string): string {
  const biter = kilde.split('<HandlingKnapp')
  const treff = biter.filter((b) => b.includes(`handling={${handling}}`))
  if (treff.length !== 1) {
    throw new Error(
      `fant ${treff.length} knapper med handling={${handling}} — forventet 1`,
    )
  }
  // Fram til slutten av taggen. Spørsmålet er en flerlinjes uttrykk, så
  // vi kan ikke stoppe på første linjeskift.
  const slutt = treff[0].indexOf('/>')
  if (slutt < 0) throw new Error(`fant ingen slutt paa ${handling}-knappen`)
  return treff[0].slice(0, slutt)
}

/**
 * REGELEN, som én funksjon — så kanarifuglen kan prøve nøyaktig den.
 *
 * To krav, og det andre er det som betyr noe: spørsmålet må bruke
 * `maanedstekst`. En hardkodet måned ville vært verre enn ingen.
 */
function navngirMaaneden(utsnitt: string): boolean {
  if (!/\bsporsmaal=/.test(utsnitt)) return false
  const fra = utsnitt.indexOf('sporsmaal=')
  return /\{?\s*maanedstekst\s*\}?/.test(utsnitt.slice(fra))
}

describe('slipp og avvis bekrefter, og bekreftelsen sier hvilken maaned', () => {
  it('KANARIFUGL: begge knappene blir funnet i kilden', () => {
    // Byttes komponenten eller navnet, blir utsnittene tomme — og hver
    // paastand under ville vaert sann fordi det ikke er noe aa maale.
    expect(knapp(KILDE, 'slippPlan').length).toBeGreaterThan(40)
    expect(knapp(KILDE, 'avvisPlan').length).toBeGreaterThan(40)
  })

  it('Slipp har et spoersmaal', () => {
    expect(
      /\bsporsmaal=/.test(knapp(KILDE, 'slippPlan')),
      '\nSlipp sendte et brev til et menneske uten aa spoerre.\n'
      + 'Det var slik juniplanen gikk til Sandra 2026-09-14.\n',
    ).toBe(true)
  })

  it('Slipp-spoersmaalet NAVNGIR maaneden', () => {
    expect(
      navngirMaaneden(knapp(KILDE, 'slippPlan')),
      '\nSpoersmaalet nevner ikke maaneden.\n\n'
      + '«Slipp planen for Lone?» ville bestaatt ogsaa paa juni —\n'
      + 'stasjonen var riktig, maaneden var ikke.\n',
    ).toBe(true)
  })

  it('Avvis-spoersmaalet navngir ogsaa maaneden', () => {
    expect(navngirMaaneden(knapp(KILDE, 'avvisPlan'))).toBe(true)
  })

  it('Slipp sier at innholdet ikke kan skrives om etterpaa', () => {
    // `maanedsplan_laas_sluppet` (0200) laaser punkter, ingress og dom
    // naar status er sluppet eller sendt. Det er sant, og da skal det
    // staa i spoersmaalet — ikke oppdages etterpaa.
    expect(knapp(KILDE, 'slippPlan')).toMatch(/kan ikke\s*'?\s*\+?\s*'?\s*skrives om/)
  })

  // =================================================================
  // KANARIFUGL FOR SELVE REGELEN
  // =================================================================
  it('KANARIFUGL: regelen feller et spoersmaal uten maaned', () => {
    const utenMaaned = `
      handling={slippPlan}
      merke="Slipp"
      sporsmaal={\`Slipp månedsplanen for \${stasjon}?\`}
    `
    expect(navngirMaaneden(utenMaaned)).toBe(false)

    const utenSpoersmaal = 'handling={slippPlan} merke="Slipp"'
    expect(navngirMaaneden(utenSpoersmaal)).toBe(false)

    // Og den godtar den formen vi faktisk bruker.
    const med = 'sporsmaal={`Slipp for ${stasjon} — ${maanedstekst}?`}'
    expect(navngirMaaneden(med)).toBe(true)
  })

  it('KANARIFUGL: to knapper med samme handling er ogsaa et funn', () => {
    expect(() => knapp('<HandlingKnapp handling={slippPlan} />'
      + '<HandlingKnapp handling={slippPlan} />', 'slippPlan')).toThrow(/fant 2/)
  })
})
