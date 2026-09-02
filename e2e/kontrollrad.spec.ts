import { test, expect, type Page, type Locator } from '@playwright/test'

// =====================================================================
// EN KONTROLLRAD JUSTERER KONTROLLER, IKKE BLOKKER
//
// To rader paa /produksjonsplan sto skjevt, av samme grunn i hver sin
// ende av samme akse:
//
//   `.sq-listetopp`   `align-items: center` sentrerte «Vis dagen» mot
//                     HELE naboen - etikett + felt, ~66px - i stedet for
//                     mot feltet. Knappens midte laa 11px for hoeyt.
//
//   `.pp-regelrad`    `align-items: flex-end` la BUNNENE paa linje.
//                     Hjelpeteksten under «Margin over forslaget» brytes
//                     til to linjer, saa den kolonnen dyttet sin egen
//                     etikett og sitt eget felt 29px opp.
//
// Ingen av dem var maalt noe sted. `knappesprak.spec.ts` maaler farge og
// trykkflate paa nettopp «Vis dagen», og var groenn hele veien -
// justering var utenfor det den ser paa. `design.test.ts` og
// `tilgjengelighet.test.ts` kjoerer i jsdom og kan per definisjon ikke
// se dette: det krever layout, altsaa en ekte nettleser.
//
// DERFOR MAALES POSISJON, IKKE REGELEN. En test som leste CSS-en etter
// «align-items: end» ville bestaatt uten at noe faktisk sto paa linje.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }
const PLAN = '/produksjonsplan?dato=2026-02-02'

/** Naar to bokser skal se ut som en linje, taaler oeyet omtrent dette. */
const SLINGRING = 2

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Boksen, med en paastand om at den finnes - ikke `null` i stillhet. */
async function boks(el: Locator, hva: string) {
  await expect(el, `${hva} finnes ikke - da maaler denne testen ingenting`).toBeVisible()
  const b = await el.boundingBox()
  expect(b, `${hva} har ingen boks`).not.toBeNull()
  return b!
}

const midte = (b: { y: number; height: number }) => b.y + b.height / 2

test.describe('kontrollrader staar paa linje', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  test('«Vis dagen» staar paa linje med datofeltet, ikke med etiketten', async ({ page }) => {
    await page.goto(PLAN)

    const felt = await boks(page.locator('input[name="dato"]'), 'Datofeltet')
    const knapp = await boks(page.getByRole('button', { name: 'Vis dagen' }), '«Vis dagen»')

    // KANARIFUGL. Hele feilen var at knappen ble sentrert mot etikett +
    // felt samlet. Er det ingen etikett over feltet, er senter og bunn
    // det samme punktet, og denne testen kan ikke skille dem fra
    // hverandre lenger.
    const etikett = await boks(page.locator('label:has(input[name="dato"]) > span').first(), 'Etiketten «Dag»')
    expect(etikett.y, 'Etiketten staar ikke lenger over feltet - da beviser maalingen under ingenting')
      .toBeLessThan(felt.y)

    expect(
      Math.abs(midte(knapp) - midte(felt)),
      'Knappen er ikke sentrert mot feltet den hoerer til',
    ).toBeLessThanOrEqual(SLINGRING)

    // Bunnjustering alene er ikke nok: `.felt input` er 44px og
    // `.sq-knapp` 40px, saa de ville fortsatt vaert to ulike bokser.
    expect(
      Math.abs(knapp.height - felt.height),
      'Knappen og feltet er ikke like hoeye',
    ).toBeLessThanOrEqual(SLINGRING)
  })

  test('driftsreglenes etiketter og felt staar paa hver sin linje', async ({ page }) => {
    await page.goto(PLAN)

    const rad = page.locator('.pp-regelrad')
    await expect(rad, 'Driftsreglene finnes ikke paa denne planen').toBeVisible()

    const kolonner = rad.locator('.pp-regel')
    await expect(kolonner, 'Raden har ikke to regelkolonner aa sammenligne').toHaveCount(2)

    // KANARIFUGL. Justeringen er bare et sporsmaal saa lenge de to
    // hjelpetekstene tar ULIKT antall linjer - det er den brutte teksten
    // under «Margin over forslaget» som skaper hele saken. Tar de like
    // mange, gir start, senter og bunn samme svar, og testen bestaar uten
    // aa maale noe. Da skal den si fra, ikke sove.
    //
    // MAALES SOM LINJEBOKSER, IKKE SOM HOEYDE. Foerste utgave sammenlignet
    // kolonnenes hoeyde, og det var aa gjoere et SYMPTOM paa feilen til
    // beviset paa at testen maaler: under den gamle flex-raden var
    // kolonnene ulike hoeye nettopp fordi justeringen var feil. Med
    // subgrid spenner begge over de samme tre radene og er like hoeye ved
    // konstruksjon - kanarifuglen slo ut paa selve rettingen. Et Range
    // over tekstinnholdet gir en rect per linjeboks, og det tallet er det
    // samme uansett hvordan kolonnen er lagt ut.
    const linjer = (k: Locator) =>
      k.locator('> span:last-child').evaluate((e) => {
        const r = document.createRange()
        r.selectNodeContents(e)
        return r.getClientRects().length
      })

    const [l0, l1] = [await linjer(kolonner.nth(0)), await linjer(kolonner.nth(1))]
    expect(l0, 'Foerste hjelpetekst har ingen linjer - da staar det ingen tekst der').toBeGreaterThan(0)
    expect(
      l1,
      `Hjelpetekstene tar like mange linjer (${l0}) - da kan ikke denne testen skille riktig justering fra feil`,
    ).not.toBe(l0)

    const etiketter = kolonner.locator('> span:first-child')
    const felt = rad.locator('.pp-regel-inn input')
    await expect(felt, 'Fant ikke begge prosentfeltene').toHaveCount(2)

    const [e0, e1] = [await boks(etiketter.nth(0), 'Foerste etikett'), await boks(etiketter.nth(1), 'Andre etikett')]
    const [f0, f1] = [await boks(felt.nth(0), 'Foerste felt'), await boks(felt.nth(1), 'Andre felt')]

    expect(Math.abs(e0.y - e1.y), 'Etikettene staar ikke paa samme linje').toBeLessThanOrEqual(SLINGRING)
    expect(Math.abs(f0.y - f1.y), 'Prosentfeltene staar ikke paa samme linje').toBeLessThanOrEqual(SLINGRING)
  })

  test('«Skriv over dagens tall» staar under reglene, ikke i raden med dem', async ({ page }) => {
    await page.goto(PLAN)

    const rad = await boks(page.locator('.pp-regelrad'), 'Regelraden')
    const knapp = await boks(page.getByRole('button', { name: 'Skriv over dagens tall' }), '«Skriv over dagens tall»')

    // Handlingen er ikke et tredje felt. Sto den i raden, hadde den ingen
    // etikett aa justere etter og la seg paa en tredje hoeyde uansett.
    expect(knapp.y, 'Handlingen ligger fortsatt inne i feltraden')
      .toBeGreaterThanOrEqual(rad.y + rad.height - SLINGRING)
  })
})
