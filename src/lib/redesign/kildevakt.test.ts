import { describe, expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { KILDE, MAAL, generer, lesHode } from '../../../scripts/generer-0125.mjs'

// =====================================================================
// En generert fil skal ikke kunne skli fra kilden sin.
//
// `0125` er `0116` pluss én kolonne bakerst. Den ble generert, ikke
// skrevet av — men «generert fra 0116» var bare et løfte i en kommentar,
// og et løfte i en kommentar er nøyaktig like sterkt som hukommelsen til
// den som leser den.
//
// HVA SOM SKJER NÅR DE SKLIR. Migrasjonene kjøres om igjen fra bunn av
// og til. Da er 0125 den siste som rører viewet, altså den som vinner.
// Retter noen en feil i 0116 uten å regenerere, står feilen igjen i
// produksjon — og filen som har rettelsen ser ut til å være i orden.
//
// Det skjedde nesten samme dag: 0116 sa at differansen mellom kassa og
// tellingen ER kaffeavtalene og derfor ikke skal farges. Målingen viste
// at det ikke stemmer — utdelte kopper ligger allerede i kassatallet som
// PÅFYLL-linjer med negativ brutto. Rettelsen måtte inn i BEGGE.
//
// Denne vakten kjører generatoren i minnet og sammenlikner. Den leser
// ikke databasen og er rask.
// =====================================================================

const rot = process.cwd()
const les = (sti: string) => readFileSync(join(rot, sti), 'utf8')

describe('genererte migrasjoner', () => {
  test('0125 er nøyaktig det generatoren lager av 0116', () => {
    const paaDisk = les(MAAL)
    const laget = generer(les(KILDE), lesHode(paaDisk))

    expect(
      laget.split(/\r?\n/),
      '\n0125 er ikke lenger det generatoren lager av 0116.\n\n'
      + 'Ble 0116 endret uten at 0125 ble regenerert? Kjør:\n'
      + '  node scripts/generer-0125.mjs\n\n'
      + 'Migrasjonene kjøres om igjen fra bunn, og 0125 er den siste som '
      + 'rører viewet — altså den som vinner. En rettelse som bare står i '
      + '0116 når aldri produksjon.\n',
    ).toEqual(paaDisk.split(/\r?\n/))
  })

  test('KANARIFUGL: generatoren gjør faktisk noe', () => {
    // Returnerte den kilden uendret, ville testen over vært grønn for en
    // 0125 som ikke hadde kolonnen i det hele tatt.
    const kilde = les(KILDE)
    const laget = generer(kilde, lesHode(les(MAAL)))
    expect(kilde).not.toContain('bp_brutto_fast')
    expect(laget).toContain('as bp_brutto_fast')
    expect(laget).toContain('fast_margin as (')
    expect(laget.length).toBeGreaterThan(kilde.length)
  })

  test('KANARIFUGL: hodet hentes fra 0125, ikke fra 0116', () => {
    // Tok generatoren 0116 sitt hode, ville hver regenerering slettet
    // forklaringen på hvorfor kolonnen finnes — og det ville sett ut som
    // en ryddig diff.
    const hode = lesHode(les(MAAL))
    expect(hode.join('\n')).toContain('bp_brutto_fast')
    expect(hode.join('\n')).not.toContain('brutto mot BUDSJETT, ikke mot kassa')
  })

  test('rettelsen som utløste vakten står i BEGGE filene', () => {
    // 0116 sa at kassa-telling-differansen ER avtalene. Utdelte kopper
    // ligger allerede i kassatallet, så det som står igjen er
    // uregistrert svinn. Står den gamle teksten igjen ett sted, er det
    // det stedet som vinner ved en full gjenkjøring.
    for (const fil of [KILDE, MAAL]) {
      expect(les(fil), `${fil} har fortsatt den gamle paastanden`)
        .toContain('er IKKE avtalene')
    }
  })
})
