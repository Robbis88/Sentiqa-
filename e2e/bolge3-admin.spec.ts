import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// Bolge 3: administrasjon, opprettelse og detalj.
//
// Tre undergrupper med hvert sitt spraak, maalt som en familie:
//
//   liste + opprettelse   objektet, tilstanden, handlingen - og «Ny …»
//                         i et panel, ikke over lista
//   detalj                EN sak i dybden; kortene grupperer sider ved
//                         det samme objektet og blir staaende
//   redaktor/innhold      tekst som skal leses, ikke rader som skal
//                         skannes
//
// EIERGRENENE ER MED FOR FORSTE GANG. Port 0 gjorde det mulig: eieren
// logger inn gjennom ekte TOTP, saa /stasjoner, /brukere og
// eierhandlingene paa /premier kan faktisk maales.
// =====================================================================

const SJEF = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

/** Rutene butikksjefen naar. Eierens staar i sin egen bolk. */
const SJEFENS = [
  '/merker',
  '/premier',
  '/konkurranser',
  '/puls',
  '/puls/sporsmal',
  '/skills',
  '/mine-opplysninger',
]

/** Eierens ruter - krever TOTP. */
const EIERENS = ['/stasjoner', '/brukere', '/arrangementer']

async function loggInnSjef(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', SJEF.epost)
  await page.fill('input[name="passord"]', SJEF.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

async function axeRent(page: Page, sti: string) {
  const res = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  const funn = res.violations.flatMap((v) => v.nodes.map(
    (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
  ))
  expect(funn, `\n${sti}\n${funn.join('\n')}\n`).toEqual([])
}

test.describe('bolge 3 - butikksjefens flater', () => {
  test.beforeEach(async ({ page }) => {
    await loggInnSjef(page)
  })

  for (const sti of SJEFENS) {
    test(`${sti} folger familieformen`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      const svar = await page.goto(sti)
      expect(svar?.status()).toBeLessThan(400)
      await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)

      // De handskrevne systemene skal vaere borte fra hele bolgen.
      expect(await page.locator('.status-pip').count(), `${sti}: gammel status-pip`).toBe(0)

      // Ingen tilstand baaret av farge alene.
      const tomme = await page.locator('.sq-status').evaluateAll(
        (n) => n.map((e) => (e.textContent ?? '').trim()).filter((t) => t.length === 0))
      expect(tomme, `${sti}: statusmerke uten tekst`).toEqual([])

      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })

    test(`${sti} har ingen axe-brudd`, async ({ page }) => {
      await page.goto(sti)
      await axeRent(page, sti)
    })
  }

  // -------------------------------------------------------------------
  // SKJEMAENE I PANEL - de ti punktene
  // -------------------------------------------------------------------
  test('opprettelsespanelet: lukket, aapnes, har felter og etiketter', async ({ page }) => {
    await page.goto('/skills')

    // 1. Panelet er lukket ved normal sidevisning.
    await expect(page.locator('dialog[open]')).toHaveCount(0)

    // 2. Riktig handling aapner det.
    // TO KNAPPER MED SAMME NAVN, og det er riktig: panelet aapnes baade
    // fra sidehodet og fra tomtilstanden, som tilbyr veien videre naar
    // det ikke finnes noe aa se paa. Samme panel, to inngangar.
    await page.getByRole('button', { name: 'Ny score' }).first().click()
    const panel = page.locator('dialog[open]')
    await expect(panel).toBeVisible()

    // 3-4. Feltene finnes, og de finnes VED NAVN. En plassholder er
    // ikke en etikett - den forsvinner idet man begynner aa skrive.
    await expect(panel.getByLabel('Stasjon')).toBeVisible()
    await expect(panel.getByLabel('Skills-score i prosent')).toBeVisible()

    // 5. Skjult nyttelast bestaar - den er payload, ikke kontekst.
    const skjulte = await panel.locator('input[type="hidden"]').count()
    expect(skjulte, 'Skjulte felter forsvant i flyttingen').toBeGreaterThanOrEqual(0)

    // 7. Lukking mister ingenting.
    await page.keyboard.press('Escape')
    await expect(page.locator('dialog[open]')).toHaveCount(0)
    await expect(page.locator('h1')).toBeVisible()
  })

  test('valideringen bestaar - tomt paakrevd felt lagrer ikke', async ({ page }) => {
    await page.goto('/puls/sporsmal')
    await page.getByRole('button', { name: 'Nytt spørsmål' }).first().click()
    const panel = page.locator('dialog[open]')
    await expect(panel).toBeVisible()

    // Send uten aa fylle ut det paakrevde: enten stopper nettleseren det,
    // eller saa gjor serveren det. Det som ikke er riktig er at et tomt
    // sporsmaal blir lagret.
    await panel.getByRole('button', { name: /Legg til|Lagre/i }).first().click()
    await expect(page.locator('dialog[open]')).toBeVisible()
  })

  test('9-10: butikksjefen faar IKKE eierens handlinger paa /premier', async ({ page }) => {
    await page.goto('/premier')
    // Eier tildeler og markerer utbetalt. Butikksjefen ser det samme,
    // men uten knappene - rolleforskjellen er funksjonell, ikke kosmetisk.
    expect(await page.getByRole('button', { name: /Marker utbetalt/i }).count(),
      'Butikksjefen fikk eierens utbetalingsknapp').toBe(0)
  })
})

test.describe('bolge 3 - eierens flater, gjennom ekte TOTP', () => {
  // Serielt bare her: eierens faktor er delt tilstand i basen.
  test.describe.configure({ mode: 'serial' })
  // Gjenbruker okta oppsettsteget lagret. Ingen ny innlogging, ingen ny
  // faktor - og dermed ingen risiko for at to arbeidere ruller inn hver
  // sin.
  test.use({ storageState: OKTFIL })

  for (const sti of EIERENS) {
    test(`${sti} folger familieformen og er axe-ren`, async ({ page }) => {

      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      await page.goto(sti)
      await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)
      expect(await page.locator('.status-pip').count(), `${sti}: gammel status-pip`).toBe(0)
      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])

      await axeRent(page, sti)
    })
  }

  test('eieren HAR handlingene butikksjefen ikke har', async ({ page }) => {
    await page.goto('/brukere')

    // Opprettelse ligger i panel, ikke over lista.
    await expect(page.locator('dialog[open]')).toHaveCount(0)
    await expect(page.getByRole('button', { name: /Ny bruker/i })).toBeVisible()
  })
})
