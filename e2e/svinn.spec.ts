import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Pilot B: /svinn etter migreringen til primitivene.
//
// HVA DENNE FILA FAKTISK MAALER, og hva den ikke maaler:
//
// Seeden har ingen svinndata, saa sida returnerer tidlig med
// tomtilstanden. Alt som ligger BAK den - nokkeltallene, terskeltabellen
// med Status, Forklaringen - rendres ikke i CI, og testene under hopper
// over dem med en grunn i stedet for aa late som de er groenne.
//
// Det som ER maalt er ikke ingenting: tomtilstanden er den forste
// skjermen en ny kunde ser, portneren skal fortsatt staa, og axe kjorer
// med kontrast i en ekte nettleser. Det var noyaktig den maalingen som
// fant den for lave menylenka i pilot A.
//
// Skal resten maales, maa seeden faa svinn- og matsalgsrader. Det er sitt
// eget stykke arbeid: `synlig_svinn` alene holder ikke, for svinn% deles
// paa matsalget, og da maa `daglig_salg` seedes i takt. Til da staar
// hullet her, synlig.
// =====================================================================

const BUTIKKSJEF = {
  epost: 'butikksjef@test.sentiqa.no',
  passord: 'test-butikksjef-2026',
}

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', BUTIKKSJEF.epost)
  await page.fill('input[name="passord"]', BUTIKKSJEF.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Sant naar sida viser tomtilstanden, altsaa naar basen er uten svinn. */
async function erTom(page: Page) {
  return (await page.locator('.sq-tom').count()) > 0
}

test.describe('/svinn etter pilot B', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
    await page.goto('/svinn')
  })

  test('siden laster uten klientfeil', async ({ page }) => {
    const feil: string[] = []
    page.on('pageerror', (e) => feil.push(e.message))
    await expect(page.locator('h1')).toHaveText('Synlig svinn')
    expect(feil, `Klientfeil:\n  ${feil.join('\n  ')}`).toEqual([])
  })

  test('tomtilstanden peker videre, den stopper ikke', async ({ page }) => {
    test.skip(!(await erTom(page)), 'Basen har svinndata, saa tomtilstanden vises ikke')
    // En tom skjerm som bare sier «ingen data» lar brukeren staa fast.
    // Denne skal si hva som mangler OG hvor man legger det inn.
    await expect(page.locator('.sq-tom')).toContainText(/Varetransaksjonsliste/i)
    await expect(page.getByRole('link', { name: /Import/i })).toBeVisible()
  })

  test('nokkeltall og terskeltabell naar det finnes data', async ({ page }) => {
    test.skip(await erTom(page), 'Ingen svinndata i seeden - se toppen av fila')

    // Nivaa 1 i analysemonsteret er svaret, ikke tabellen. Nokkeltallet
    // skal ha noe aa sammenligne med; et tall alene sier ingenting.
    const tall = page.locator('.sq-nokkeltall')
    await expect(tall.first()).toBeVisible()
    await expect(tall.first().locator('.sq-nokkeltall-mot')).toBeVisible()

    // Terskeltabellen skal bruke Status, ikke den gamle status-pipen.
    await expect(page.locator('.sq-datatabell').first()).toBeVisible()
    expect(await page.locator('.status-pip').count(),
      'Gammel status-pip henger igjen paa sida').toBe(0)
  })

  test('forklaringen er lukket til noen spor', async ({ page }) => {
    test.skip(await erTom(page), 'Ingen svinndata i seeden - se toppen av fila')
    // Nivaa 4: metoden skal vaere tilgjengelig, ikke i veien. Staar den
    // aapen, moter brukeren regnestykket for svaret.
    const f = page.locator('details.sq-forklaring').first()
    await expect(f).toBeVisible()
    expect(await f.evaluate((e: HTMLDetailsElement) => e.open),
      'Forklaringen staar aapen og skygger for svaret').toBe(false)
  })

  test('feil rolle faar ikke ny tilgang', async ({ page, context }) => {
    // Portneren staar i page.tsx og er lett aa miste naar en side skrives
    // om. Nettbrettrollen har aldri hatt /svinn.
    await context.clearCookies()
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    await page.goto('/svinn')
    await expect(page.locator('body')).toContainText(
      /ikke tilgang til svinn|Ingen tilgang|logg inn/i)
  })

  test('ingen axe-brudd, med kontrast', async ({ page }) => {
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})
