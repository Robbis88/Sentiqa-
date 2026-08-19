import { test, expect } from '@playwright/test'
import { RUTEMONSTER } from '../src/lib/redesign/monstre'

// =====================================================================
// Slipper en uinnlogget inn noe sted?
//
// tilgang.test.ts leser portneren ut av KILDEN. Denne spor systemet.
// De to kan vaere uenige: en side kan ha riktig rollesjekk i koden og
// likevel svare 200 fordi middleware, layout eller en cache kom i veien.
//
// Dette er ogsaa den eneste vakten som tester en sikkerhetsegenskap slik
// en angriper ville motet den: uten oekt, rett paa URL-en.
//
// Ingen database trengs. hentInnloggetBruker() redirigerer til
// /logg-inn naar det ikke finnes en bruker, og det skjer for noen
// sporring gaar til Supabase.
// =====================================================================

// Ruter uten parameter. `[id]`-rutene kan ikke besokes uten en ekte id,
// og en gjettet uuid ville testet feilhaandtering, ikke tilgang.
const beskyttede = Object.entries(RUTEMONSTER)
  .filter(([sti, monster]) => monster !== 'utenfor' && !sti.includes('['))
  .map(([sti]) => sti)

test('vi tester faktisk et meningsfullt antall ruter', () => {
  // KANARIFUGL. Endrer monsterkartet form, kan filteret stille ende med
  // to ruter - og da er suiten gronn uten aa ha sjekket noe.
  expect(beskyttede.length).toBeGreaterThan(40)
})

for (const sti of beskyttede) {
  test(`uinnlogget blir sendt til innlogging fra ${sti}`, async ({ page }) => {
    await page.goto(sti)
    // Redirect kan gaa via flere hopp; det som betyr noe er hvor man endte.
    await expect(page).toHaveURL(/\/logg-inn/)
  })
}
