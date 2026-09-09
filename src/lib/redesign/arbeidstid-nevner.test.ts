import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// «VI FANT INGENTING» OG «VI SÅ IKKE ETTER» GA SAMME TALL
//
// `/lonn` telte hvor mange som manglet arbeidstid slik:
//
//     const utenArbeidstid = [...avtale.values()].filter(...)
//
// `avtale` er raden i `ansatt_avtale`. Den som ALDRI har fått en rad var
// altså ikke med i tellingen i det hele tatt.
//
// `ansatt_avtale` hadde **én rad i hele basen**, mot ti ansatte på Bønes
// alene. Tallet ble 0. `SkiftFraSats` returnerer `null` på 0, så knappen
// forsvant — og sida så ferdig ut mens ingen hadde arbeidstid satt.
//
// Følgen er ikke kosmetisk: `finnOvertid` antar ordinær (37,5) når
// ordningen mangler, og to skift er 35,5. Hver to-skift-ansatt fikk
// derfor to timer i uka som aldri ble talt som overtid.
//
// ---------------------------------------------------------------------
// REGELEN
//
// Nevneren skal være de som FAKTISK JOBBET (`perAnsatt`), ikke de som
// tilfeldigvis hadde en rad. En telling over sitt eget utvalg måler
// ingenting — den bekrefter bare utvalget.
//
// Og en skjult knapp får ikke bety «ferdig»: de som ikke kan settes
// automatisk skal stå som en egen, synlig linje.
// =====================================================================

const SIDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'lonn', 'page.tsx'), 'utf8')

/** Uten kommentarer — teksten over siterer den gamle koden. */
const KODE = SIDE.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')

describe('målingen ser sida', () => {
  test('KANARIFUGL: fila er lest, og kommentarene er strippet', () => {
    expect(KODE.length, 'fant nesten ingenting').toBeGreaterThan(3000)
    expect(KODE, 'strippingen åt koden').toContain('const utenArbeidstid')
    expect(KODE, 'kommentarene ble ikke strippet').not.toContain('TALLET TALTE BARE')
  })
})

describe('nevneren er de som jobbet', () => {
  test('tellingen går ut fra perAnsatt, ikke fra avtale', () => {
    expect(KODE, 'utenOrdning bygges ikke på perAnsatt')
      .toMatch(/utenOrdning\s*=\s*\[\.\.\.perAnsatt\.keys\(\)\]/)
    expect(
      KODE,
      'Tellingen er tilbake på sitt eget utvalg: `[...avtale.values()]` ser '
      + 'bare dem som ALT har en rad i ansatt_avtale. Den som aldri fikk en '
      + 'rad telles ikke, og tallet blir 0 mens ingen har arbeidstid satt.',
    ).not.toMatch(/utenArbeidstid\s*=\s*\[\.\.\.avtale\.values\(\)\]/)
  })

  test('de som må velges manuelt har sin egen linje', () => {
    // `SkiftFraSats` returnerer null paa 0. Uten denne linja leses en
    // skjult knapp som «ingenting aa gjoere».
    expect(KODE, 'maaVelges regnes ikke ut').toMatch(/const maaVelges/)
    expect(SIDE, 'maaVelges vises ikke').toMatch(/maaVelges > 0 &&/)
  })

  test('de to gruppene er disjunkte og dekker alle uten ordning', () => {
    // `maaVelges` er resten, ikke et eget filter som kan overlappe eller
    // gaa glipp av noen. Skrives det om til et selvstendig filter, kan
    // summen bli noe annet enn `utenOrdning.length` uten at noe sier fra.
    expect(KODE).toMatch(/maaVelges\s*=\s*utenOrdning\.length\s*-\s*utenArbeidstid/)
  })

  test('knappen får bare dem satsen faktisk avgjør', () => {
    // `vurderSkiftordning(..., null)` - ikke `a.skiftordning`. Utvalget er
    // alt filtrert paa at ordningen mangler, saa aa sende inn den lagrede
    // verdien ville sammenlignet noe med seg selv.
    expect(KODE).toMatch(/vurderSkiftordning\(Number\(a\.timesats\), null\)\?\.slag === 'ikke_satt'/)
  })
})
