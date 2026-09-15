import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// MORGENDAGEN SKAL ALDRI KUNNE SKRIVES PAA
// =====================================================================
//
// `loggLagd(stasjon, dato, varenavn, lagd)` tar datoen som ARGUMENT og
// sjekker aldri at den er i dag. `logg_lagd` i basen vokter stasjonen
// og at linja finnes - ikke datoen.
//
// Det betyr at fravaeret av knapper i `tablet-morgendag.tsx` ER vernet.
// Ikke stilen, ikke kommentaren, ikke at ingen har tenkt paa det.
//
// En stepper lagt til der i god tro ville skrevet produksjon paa en dag
// som ikke har begynt - og `lagd_hittil` er nettopp tallet
// `/produksjonsplan/treffsikkerhet` maaler planen mot. Feilen ville
// altsaa ikke vist seg som en feil, men som en plan som traff daarlig.
//
// Skal morgendagen noen gang bli klikkbar, maa datovernet inn i
// `logg_lagd` FOERST. Da skal denne testen endres bevisst, ikke slettes
// fordi den staar i veien.
// =====================================================================

const ROT = process.cwd()
const MAPPE = join(ROT, 'src', 'app', '(beskyttet)', 'produksjonsplan')
// KOMMENTARENE STRIPPES FOER HVER PAASTAND.
//
// Foerste utgave leste raa kildetekst, og paastanden om at loggLagd
// ikke kalles felte sin egen forklaring: kommentaren i
// tablet-morgendag.tsx NEVNER loggLagd, nettopp for aa si hvorfor den
// ikke kalles.
//
// Samme felle som design.test.ts er bygget rundt - og den er verre
// andre veien: en toContain kan bli OPPFYLT av en kommentar, og da
// staar vakten groenn uten aa ha sett paa koden i det hele tatt.
const les = (f: string) => utenKommentarer(readFileSync(join(MAPPE, f), 'utf8'))

describe('morgendagens plan er lesevisning ved konstruksjon', () => {
  const kilde = les('tablet-morgendag.tsx')

  it('KANARIFUGL: fila finnes og er lest', () => {
    // Uten denne ville en feilstavet sti gitt en tom streng, og hver
    // `not.toContain` under ville bestaatt. En vakt som ikke leser noe
    // ser noeyaktig ut som en vakt som ikke finner noe.
    expect(kilde.length).toBeGreaterThan(500)
    expect(kilde).toContain('TabletMorgendag')
  })

  it('kaller ikke loggLagd', () => {
    expect(kilde).not.toContain('loggLagd')
  })

  it('importerer ingenting fra handlinger', () => {
    // Bredere enn navnet over: ingen serverhandling herfra i det hele
    // tatt. En ny handling med et annet navn ville sluppet forbi en
    // sjekk som bare kjente `loggLagd`.
    expect(kilde).not.toMatch(/from\s+['"]\.\/handlinger['"]/)
  })

  it('har ingen knapper, stepper eller skjemafelt', () => {
    for (const m of ['<button', '<input', 'onClick', 'onChange']) {
      expect(kilde, `${m} hoerer ikke hjemme i morgendagens plan`).not.toContain(m)
    }
  })

  it('viser datoen den gjelder', () => {
    // To lister med tall paa samme skjerm, der den ene gjelder en annen
    // dag. Samme form som feilslippet der juni ble sluppet i stedet for
    // juli fordi ingen av dem sa hvilken maaned de var.
    expect(kilde).toContain('datoLang')
  })
})

describe('dagens plan er uendret', () => {
  const kilde = les('tablet-plan.tsx')

  it('KANARIFUGL: stepperen finnes fortsatt i dagens plan', () => {
    // Beviser at testene over maaler en FORSKJELL mellom de to filene,
    // ikke bare at ingen av dem har knapper. Forsvinner stepperen her,
    // er det dagens plan som er i stykker.
    expect(kilde).toContain('loggLagd')
    expect(kilde).toContain('stepper')
  })
})

describe('sida henter begge dagene foer den gir opp', () => {
  const kilde = les('page.tsx')

  it('en upublisert dag i dag skjuler ikke morgendagen', () => {
    // Her sto en tidlig `return` paa manglende publisering for i dag.
    // Den ville skjult morgendagen ogsaa - og da var funksjonen borte
    // noeyaktig de dagene ingen rakk aa publisere dagens plan.
    expect(kilde).toContain('if (!visIdag && !visImorgen)')
  })

  it('morgendagen gates paa publisering, som i dag', () => {
    // Et upublisert utkast er tall butikksjefen fortsatt kan endre.
    expect(kilde).toMatch(/visImorgen\s*=\s*Boolean\(imorgenHode\?\.publisert_tid\)/)
  })
})
