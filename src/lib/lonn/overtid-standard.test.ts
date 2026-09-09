import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import { SKIFTNAVN, TIMER_PER_UKE, type Skiftordning } from './tariff'
import { UKJENT_ORDNING } from './overtid'

// =====================================================================
// TO KOMMENTARER LØY SAMME VEI
//
// `overtid.ts` sto med to påstander om hva som antas når skiftordningen
// ikke er satt:
//
//     «velges den laveste forsvarlige grensen»
//     «vi antok den strengeste»
//
// Koden gjør `TIMER_PER_UKE[ordning ?? 'ordinaer']` = **37,5**, som er
// den HØYESTE av de fire (37,5 / 36,5 / 35,5 / 33,5). En høyere grense
// finner FÆRRE timer. Begge kommentarene beskrev altså det motsatte av
// koden, og i retningen fila selv kaller den dyre feilen.
//
// To kommentarer som lyver samme vei er ikke slurv. Det er den formen
// som gjør at en gjennomlesing BEKREFTER feilen i stedet for å finne
// den — samme som «123 rutiner igjen», der kommentaren sa «i dag» ved
// siden av kode som summerte en måned.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER
//
// Ikke hvilken grense som er RIKTIG — det er en tariffavgjørelse, og
// modulen sier selv «gjett aldri på satser». Den måler at teksten og
// koden sier det samme:
//
//   `UKJENT_ORDNING` er en navngitt konstant koden faktisk bruker.
//   Kommentaren øverst navngir grensen den gir.
//
// Byttes standarden uten at teksten følger med, blir dette rødt.
// =====================================================================

const KILDE = readFileSync(join(process.cwd(), 'src', 'lib', 'lonn', 'overtid.ts'), 'utf8')

/**
 * Koden uten kommentarer.
 *
 * EN KOMMENTAR ER IKKE KODE. Første utgave felte sin egen forklaring:
 * teksten øverst i `overtid.ts` SITERER det gamle uttrykket for å
 * forklare hva som ble rettet. Uten strippingen melder vakten en feil
 * som er borte — og en vakt med falske funn lærer folk å se bort fra
 * rødt.
 *
 * Tredje gang samme lekse i dette repoet: drivstoffvakten, etiketten på
 * /import, og denne.
 */
const KODE = KILDE.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*/g, '')

describe('målingen ser fila', () => {
  test('KANARIFUGL: konstanten og kilden er lest', () => {
    expect(KILDE.length, 'fant nesten ingenting i overtid.ts').toBeGreaterThan(3000)
    expect(UKJENT_ORDNING, 'UKJENT_ORDNING er ikke en kjent ordning')
      .toBeOneOf(Object.keys(TIMER_PER_UKE) as Skiftordning[])
  })
})

describe('standarden står skrevet der den brukes', () => {
  test('koden slår opp UKJENT_ORDNING, ikke en løs streng', () => {
    // `?? 'ordinaer'` inne i et uttrykk kan ikke leses av en vakt, og
    // det var nettopp derfor teksten kunne skli fra koden.
    expect(KODE, 'grensen velges ikke via UKJENT_ORDNING')
      .toMatch(/TIMER_PER_UKE\[ordning \?\? UKJENT_ORDNING\]/)
    expect(
      KODE,
      'den løse strengen er tilbake — da kan teksten og koden skille lag igjen',
    ).not.toMatch(/ordning \?\? 'ordinaer'/)
  })

  test('teksten navngir BÅDE ordningen og grensen den gir', () => {
    // TALLET ALENE ER FOR SVAKT. Første utgave krevde bare at «37,5»
    // sto i fila — men fila nevner alle fire grensene når den forklarer
    // valget, så påstanden var nesten alltid sann. Byttet standarden til
    // to skift, ville testen stått grønn fordi «35,5» også står der.
    //
    // Paret er det som binder: ordningens NAVN rett foran grensen den
    // gir. Det kan ikke stemme ved et uhell.
    const navn = SKIFTNAVN[UKJENT_ORDNING]
    const norsk = String(TIMER_PER_UKE[UKJENT_ORDNING]).replace('.', ',')
    expect(
      KILDE.toLowerCase(),
      `Fila sier ikke «${navn} (${norsk})». Standarden er endret uten at `
      + 'forklaringen fulgte med, og da lyver fila igjen.',
    ).toContain(`${navn.toLowerCase()} (${norsk})`)
  })

  test('KANARIFUGL: strippingen fjerner kommentarer, ikke kode', () => {
    // Uten denne kunne `KODE` blitt tom — og «den løse strengen er
    // borte» ville vært sant fordi ingenting var igjen å lese.
    expect(KODE, 'strippingen åt koden').toContain('export function finnOvertid')
    expect(KODE, 'kommentarene ble ikke strippet').not.toContain('UKJENT SKIFTORDNING')
  })

  test('KANARIFUGL: 37,5 ER den høyeste, ikke den strengeste', () => {
    // Selve premisset for funnet. Slutter det å stemme — fordi
    // tariffoversikten endres — måler testene over noe annet enn de tror.
    const alle = Object.values(TIMER_PER_UKE)
    expect(TIMER_PER_UKE[UKJENT_ORDNING]).toBe(Math.max(...alle))
    expect(
      TIMER_PER_UKE.to_skift,
      'to skift skal være lavere enn ordinær — ellers er hele funnet feil',
    ).toBeLessThan(TIMER_PER_UKE.ordinaer)
  })
})
