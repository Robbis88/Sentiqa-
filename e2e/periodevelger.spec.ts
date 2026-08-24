import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// Månedsvelgeren er den samme overalt — og det skal måles.
//
// FØR DENNE BETYDDE `?maned=` TO TING:
//
//   /bemanning   ?maned=3&ar=2026     to felt, tallet er 1-12
//   /lonn        ?maned=3&ar=2026     to felt, tallet er 1-12
//   /svinn       ?maned=2026-03-01    ett felt, verdien er en dato
//   /kasserer    ?maned=2026-03-01    ett felt, verdien er en dato
//
// `Number('2026-03-01')` er NaN. En lenke fra /svinn limt inn paa /lonn
// falt derfor stille tilbake til standardmaaneden og viste trygt fram
// en ANNEN maaned enn lenka lovet - uten et ord om det. Det er den
// stillheten denne fila vokter.
//
// KANARIFUGLEN ER ISO-VERDIEN. En side som driver tilbake til sin egen
// velger vil nesten sikkert bruke maanedsnummer igjen, og da feiler
// `toHaveValue(/^\d{4}-\d{2}-01$/)` selv om alt annet ser likt ut.
// Uten den kunne fire sider hatt hver sin kontroll med samme etikett.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

const SIDER = ['/svinn', '/kasserer', '/bemanning', '/lonn']

test.describe('månedsvelgeren', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const sti of SIDER) {
    test(`${sti} har den felles kontrollen`, async ({ page }) => {
      await page.goto(sti)

      const velger = page.getByRole('combobox', { name: 'Måned' })
      await expect(velger, `${sti}: ingen månedsvelger`).toBeVisible()

      // ISO, ikke et månedsnummer. Dette er selve kontrakten.
      await expect(velger, `${sti}: verdien er ikke ISO`)
        .toHaveValue(/^\d{4}-\d{2}-01$/)

      // Samme ord på knappen overalt. «Vis» på to sider og «Vis måneden»
      // på to andre er den samme kontrollen lært to ganger.
      await expect(page.getByRole('button', { name: 'Vis måneden' }),
        `${sti}: knappen heter noe annet`).toBeVisible()

      // Årstallet lå i sitt eget felt fordi måneden var et tall 1-12.
      // Med ISO finnes det ikke lenger noe å skille.
      await expect(page.getByRole('spinbutton', { name: 'År' }),
        `${sti}: årsfeltet henger igjen`).toHaveCount(0)
    })
  }

  test('den gamle formen ?maned=3&ar=2026 virker fortsatt', async ({ page }) => {
    // Den har ligget i bokmerker og delte lenker siden /lonn ble bygget.
    // Aa bare slutte aa forstaa den ville gitt nøyaktig feilen vi fjernet:
    // en lenke som viser en annen maaned enn den lover.
    await page.goto('/lonn?maned=3&ar=2026')
    await expect(page.getByRole('combobox', { name: 'Måned' })).toHaveValue('2026-03-01')
    await expect(page.locator('h1')).toContainText('Lønnsgrunnlag')
  })

  test('en ISO-maaned faller ikke lenger stille tilbake', async ({ page }) => {
    // FEILEN SOM FANTES. /lonn leste `Number(sok.maned)` -> NaN ->
    // standardmaaneden. Sida viste trygt fram feil tall.
    await page.goto('/lonn?maned=2026-03-01')
    await expect(page.getByRole('combobox', { name: 'Måned' })).toHaveValue('2026-03-01')
  })

  test('et maanedsbytte tar ikke stasjonen med seg', async ({ page }) => {
    // Skjemaet sender bare sine egne felt. Uten skjulte felt forsvinner
    // alt annet i URL-en ved submit - og da bytter et maanedsbytte
    // stille stasjon.
    await page.goto('/svinn?stasjon=44444444-4444-4444-8444-111111111111')
    await page.selectOption('select[name="maned"]', '2026-01-01')
    await page.getByRole('button', { name: 'Vis måneden' }).click()
    await expect(page).toHaveURL(/stasjon=44444444-4444-4444-8444-111111111111/)
    await expect(page).toHaveURL(/maned=2026-01-01/)
  })
})
