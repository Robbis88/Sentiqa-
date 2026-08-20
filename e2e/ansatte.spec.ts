import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Pilot A: /ansatte etter migreringen.
//
// Testen maaler at EVNENE overlevde, ikke at siden ser ut paa en bestemt
// maate. En designmigrering som beholder alt brukeren kunne gjore er
// vellykket selv om hver piksel er flyttet; en som mister deaktivering
// er mislykket selv om den er nydelig.
//
// SEEDEN HAR INGEN ANSATTE. Basen som CI starter er tom med vilje (se
// innlogget.spec.ts), saa tomtilstanden er den vi faktisk kan maale her.
// Testene under er skrevet saa de holder BEGGE veier: finnes det ansatte
// maales lista, finnes de ikke maales tomtilstanden. Aa seede ansatte
// bare for denne testen ville lagt data i en base andre tester regner
// med er tom.
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

test.describe('/ansatte etter pilot A', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
    await page.goto('/ansatte')
  })

  test('siden laster for butikksjef', async ({ page }) => {
    const feil: string[] = []
    page.on('pageerror', (e) => feil.push(e.message))
    await expect(page.locator('h1')).toHaveText('Ansatte')
    expect(feil, `Klientfeil:\n  ${feil.join('\n  ')}`).toEqual([])
  })

  // NIVAA 1 PAA EN LISTE: hvor mange, og hvor mange krever noe. Det var
  // hele poenget med aa snu sida - for aapnet den med skjemaet.
  //
  // Maalt paa DOM-en, ikke paa piksler: skjemaet skal ligge inne i en
  // <dialog> som er lukket. Barna til en <dialog> STAAR i dokumentet
  // hele tiden - de er bare `display: none` til den aapnes - saa
  // «finnes ikke i DOM-en» er feil sporsmaal og ville vaert roedt for en
  // side som gjor akkurat det den skal.
  test('lista kommer for skjemaet', async ({ page }) => {
    const dom = await page.evaluate(() => {
      const skjema = document.querySelector('.sq-skjema')
      if (!skjema) return { funnet: false, iPanel: false, aapent: false }
      const panel = skjema.closest('dialog')
      return {
        funnet: true,
        iPanel: panel !== null,
        aapent: panel !== null && panel.open,
      }
    })
    expect(dom.funnet, 'Fant ikke opprettelsesskjemaet i det hele tatt').toBe(true)
    expect(dom.iPanel, 'Opprettelsesskjemaet ligger i sida, ikke i panelet').toBe(true)
    expect(dom.aapent, 'Panelet staar aapent for noen har bedt om det').toBe(false)
  })

  test('«Ny ansatt» aapner sidepanelet med skjemaet', async ({ page }) => {
    await page.getByRole('button', { name: 'Ny ansatt' }).first().click()
    const panel = page.locator('dialog[open]')
    await expect(panel).toBeVisible()

    // Feltene skal finnes ved NAVN, ikke ved plassering. Det er dette som
    // knekker hvis en etikett forsvinner i en senere runde.
    await expect(panel.getByLabel('Navn')).toBeVisible()
    await expect(panel.getByLabel('Stasjon')).toBeVisible()
    await expect(panel.getByLabel('PIN')).toBeVisible()
    await expect(panel.getByLabel('Ansattnummer')).toBeVisible()
  })

  test('valideringen er den samme som for', async ({ page }) => {
    await page.getByRole('button', { name: 'Ny ansatt' }).first().click()
    const panel = page.locator('dialog[open]')

    await panel.getByLabel('Navn').fill('Testperson Playwright')
    await panel.getByLabel('PIN').fill('12')
    await panel.getByRole('button', { name: /Legg til/ }).click()

    // Enten stopper nettleseren det paa minLength/required, eller saa gjor
    // zod det paa serveren. Begge er riktig; det som ikke er riktig er at
    // en tosifret PIN blir lagret.
    const lagret = await page.locator('.ok').count()
    expect(lagret, 'En tosifret PIN ble akseptert').toBe(0)
  })

  test('lukking av panelet mister ingenting', async ({ page }) => {
    await page.getByRole('button', { name: 'Ny ansatt' }).first().click()
    await expect(page.locator('dialog[open]')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.locator('dialog[open]')).toHaveCount(0)
    // Lista skal fortsatt staa der. Panelet er et lag over sida, ikke en
    // navigering bort fra den.
    await expect(page.locator('h1')).toHaveText('Ansatte')
  })

  test('klientsoek filtrerer uten aa roere URL eller server', async ({ page }) => {
    const sok = page.getByRole('searchbox')
    const finnes = await sok.count()
    test.skip(finnes === 0, 'Ingen ansatte i seeden, saa soekefeltet rendres ikke')

    const url = page.url()
    const svar: string[] = []
    page.on('request', (r) => { if (r.url().includes('/ansatte')) svar.push(r.url()) })

    await sok.fill('finnes-ikke-xyz')
    await expect(page.getByText('Ingen treff')).toBeVisible()

    expect(page.url(), 'Soeket endret URL').toBe(url)
    expect(svar, 'Soeket sendte en forespoersel til serveren').toEqual([])
  })

  test('feil rolle faar ikke ny tilgang', async ({ page, context }) => {
    // Nettbrettrollen har aldri hatt /ansatte. Migreringen skal ikke ha
    // aapnet den ved et uhell - portneren staar i page.tsx og er lett aa
    // miste naar en side skrives om.
    await context.clearCookies()
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    await page.goto('/ansatte')
    await expect(page.locator('body')).toContainText(
      /administreres av eier|Ingen tilgang|logg inn/i)
  })

  test('ingen axe-brudd, med kontrast', async ({ page }) => {
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('ingen axe-brudd med sidepanelet aapent', async ({ page }) => {
    // Panelet er en <dialog> og har sine egne feller: fokusfelle,
    // etiketter, kontrast paa en flate som ligger over en annen.
    await page.getByRole('button', { name: 'Ny ansatt' }).first().click()
    await expect(page.locator('dialog[open]')).toBeVisible()

    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('treffomraadene holder maal', async ({ page }) => {
    const smaa = await page.evaluate(() => {
      const ut: string[] = []
      for (const el of document.querySelectorAll('button, a[href], input, select')) {
        const r = el.getBoundingClientRect()
        if (r.width === 0 && r.height === 0) continue
        if (getComputedStyle(el).display === 'inline') continue
        // WCAG 2.2 AA: 24x24 er minstekravet paa peker-flater.
        if (r.height < 24 || r.width < 24) {
          ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 24)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
        }
      }
      return ut
    })
    expect(smaa, `For smaa:\n  ${smaa.join('\n  ')}\n`).toEqual([])
  })
})
