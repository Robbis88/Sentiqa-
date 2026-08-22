import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { utenKommentarer } from './skrivevakt'

// =====================================================================
// En slett-knapp skal svare.
//
// Robert, 2026-08-22: «det er slette-knapper der, det er ikke noe som
// gir beskjed om at de er slettet».
//
// `skrivevakt` maaler serverhandlingen; denne maaler knappen. De to
// henger sammen: en handling som svarer med tekst hjelper ingen hvis
// skjemaet kaster svaret, og et `<form action={slettX}>` GJOER det -
// et rent skjema har ingen plass aa vise noe.
//
// FORMEN ER ENTYDIG AVGJOERBAR, og det er hele grunnen til at den
// maales: `<form action={slett...}>` eller `<form action={fjern...}>`.
// Enten gaar sletting gjennom `SlettKnapp`/`HandlingKnapp`, eller saa
// gjoer den ikke det.
//
// UNNTAKET, og det er ekte: `fjernKryss` i /rutiner er en av/paa-bryter
// som staar i en ternaer sammen med `kryssAv` og deler signatur med
// den. Krysset som forsvinner ER kvitteringen der. Unntaket staar
// navngitt under, ikke som et hull i regexen - et navngitt unntak kan
// leses og bestrides, et hull kan ikke det.
// =====================================================================

const UNNTAK = [
  // Av/paa-bryter, ikke en slett-knapp. Se /rutiner.
  'fjernKryss',
]

const SKJEMA = /<form\s+action=\{(?:\w+ \? )?((?:slett|fjern)[A-ZÆØÅ]\w*)/g

function sider(): { fil: string; kilde: string }[] {
  return execSync('git ls-files "src/**/*.tsx"', { encoding: 'utf8' })
    .split('\n').filter(Boolean)
    .map((fil) => ({ fil, kilde: utenKommentarer(readFileSync(fil, 'utf8')) }))
}

describe('maalingen forstaar det den ser', () => {
  test('kjenner igjen et rent slette-skjema', () => {
    const funn = [...'<form action={slettLenke}>'.matchAll(SKJEMA)]
    expect(funn).toHaveLength(1)
    expect(funn[0][1]).toBe('slettLenke')
  })

  test('KANARIFUGL: den ser faktisk filene', () => {
    // Peker stien feil, blir lista tom og vakten groenn uten aa ha lest
    // en eneste side.
    const s = sider()
    expect(s.length, 'fant nesten ingen .tsx-filer').toBeGreaterThan(40)
    expect(
      s.filter((x) => /<SlettKnapp/.test(x.kilde)).length,
      'fant ingen SlettKnapp - da maaler ikke denne vakten noe',
    ).toBeGreaterThan(15)
  })

  test('KANARIFUGL: et skjema som ikke sletter telles ikke', () => {
    // Halve appen er `<form action={lagreX}>`. Traff regexen dem, ville
    // vakten vaert roed fra foerste dag og dermed ubrukelig.
    expect([...'<form action={lagreVindu}>'.matchAll(SKJEMA)]).toHaveLength(0)
  })
})

describe('kvitteringsvakten', () => {
  test('ingen sletting gaar gjennom et rent skjema', () => {
    const funn: string[] = []
    for (const { fil, kilde } of sider()) {
      for (const m of kilde.matchAll(SKJEMA)) {
        if (UNNTAK.includes(m[1])) continue
        funn.push(`  ${fil}  ${m[1]}`)
      }
    }

    expect(funn, '\nDisse sletter gjennom et rent <form>, som ikke kan vise '
      + `et svar:\n${funn.join('\n')}\n\n`
      + 'Bruk <SlettKnapp handling={...} id={...} hva={...} /> i stedet. '
      + 'Handlingen tar da (tilstand, formData) og svarer med tekst via '
      + '`kvitter` i src/lib/kvittering.ts.\n')
      .toEqual([])
  })

  test('hver slett-knapp i en liste har sitt eget navn', () => {
    // TJUE KNAPPER SOM ALLE HETER «Slett» er tjue like knapper for en
    // skjermleser. Samme feil som de tolv identiske maanedsvelgerne paa
    // bemanningssida: riktig paa skjermen, ubrukelig uten den.
    const uten: string[] = []
    for (const { fil, kilde } of sider()) {
      for (const rad of kilde.split('\n')) {
        if (!/<SlettKnapp/.test(rad)) continue
        if (!/\shva=\{/.test(rad)) uten.push(`  ${fil}: ${rad.trim().slice(0, 80)}`)
      }
    }
    expect(uten, `\nDisse slett-knappene mangler \`hva\`, og faar dermed `
      + `ingen aria-label:\n${uten.join('\n')}\n\n`
      + 'Sett hva={x.navn} eller det som skiller raden fra naboen.\n')
      .toEqual([])
  })
})
