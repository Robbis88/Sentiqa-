import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 1: listefamilien.
//
// Aatte ruter migrert til samme monster. Denne fila maaler dem som en
// FAMILIE, ikke som aatte enkeltsider - det var hele poenget med aa
// migrere i bolger i stedet for en side av gangen.
//
// Det som maales er felles form: samme sidehode-hierarki, samme
// tomtilstand, samme statussemantikk, samme panelmonster. En side som
// har fått sin egen loesning paa noe de sju andre loeser likt, er ikke
// migrert - den er redesignet alene, og det er nettopp det vi unngaar.
//
// Innholdet varierer med vilje: aerendet er ulikt fra rute til rute, og
// da skal ikke sidene se identiske ut heller.
// =====================================================================

const BUTIKKSJEF = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }

/** De sju butikksjefen naar. /kunnskap er plattform-redaktorens. */
const FAMILIEN = [
  '/oppgaver',
  '/varsler',
  '/meldinger',
  '/nyheter',
  '/anvisninger',
  '/tilbakemeldinger',
  '/fokus',
]

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', BUTIKKSJEF.epost)
  await page.fill('input[name="passord"]', BUTIKKSJEF.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

test.describe('bolge 1 - listefamilien', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const sti of FAMILIEN) {
    test(`${sti} laster og folger familieformen`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      const svar = await page.goto(sti)
      expect(svar?.status(), `${sti} svarte ${svar?.status()}`).toBeLessThan(400)

      // ETT sidehode, EN h1. Hierarkiet er det samme paa alle aatte.
      await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)

      // Ingen gammel statusmerke-stil henger igjen. Den var det
      // handskrevne alternativet til Status, og to systemer som ser
      // nesten like ut er dyrere enn ett som ser annerledes ut.
      expect(await page.locator('.status-pip').count(),
        'Gammel status-pip henger igjen').toBe(0)

      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })

    test(`${sti} har ingen axe-brudd`, async ({ page }) => {
      await page.goto(sti)
      const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
      const funn = res.violations.flatMap((v) => v.nodes.map(
        (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
      ))
      expect(funn, `\n${sti}\n${funn.join('\n')}\n`).toEqual([])
    })
  }

  test('tomtilstandene forklarer, de stopper ikke', async ({ page }) => {
    // Seeden er tom, saa dette er tilstanden en NY kunde moeter. En tom
    // skjerm som bare sier «ingen data» lar henne staa fast.
    for (const sti of FAMILIEN) {
      await page.goto(sti)
      const tom = page.locator('.sq-tom')
      if (await tom.count() === 0) continue
      const tekst = await tom.first().innerText()
      expect(tekst.length, `${sti}: tomtilstanden er for kort til aa forklare noe`)
        .toBeGreaterThan(60)
    }
  })

  test('opprettelse skjer i sidepanel, ikke i et permanent skjema', async ({ page }) => {
    // Den sjeldneste handlingen paa sida skal ikke staa over lista.
    for (const sti of ['/oppgaver', '/meldinger', '/anvisninger']) {
      await page.goto(sti)
      const skjemaISida = await page.evaluate(() => {
        const s = document.querySelector('.sq-skjema')
        return s !== null && s.closest('dialog') === null
      })
      expect(skjemaISida, `${sti} viser opprettelsesskjemaet i sida`).toBe(false)
    }
  })

  test('treffomraadene holder maal i hele familien', async ({ page }) => {
    for (const sti of FAMILIEN) {
      await page.goto(sti)
      const smaa = await page.evaluate(() => {
        const ut: string[] = []
        for (const el of document.querySelectorAll('button, a[href], input, select')) {
          const r = el.getBoundingClientRect()
          if (r.width === 0 && r.height === 0) continue
          if (getComputedStyle(el).display === 'inline') continue
          if (r.height < 24 || r.width < 24) {
            ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 24)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
          }
        }
        return ut
      })
      expect(smaa, `For smaa paa ${sti}:\n  ${smaa.join('\n  ')}\n`).toEqual([])
    }
  })

  test('rolleporten staar: nettbrettet slipper ikke inn', async ({ page, context }) => {
    await context.clearCookies()
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    // /anvisninger er med VILJE aapen for nettbrettet - de ansatte slaar
    // opp prosedyrer der. De ovrige er lederens.
    for (const sti of ['/oppgaver', '/meldinger', '/tilbakemeldinger', '/fokus']) {
      await page.goto(sti)
      await expect(page.locator('body'), sti).toContainText(
        /ikke tilgang|Kun eier|logg inn/i)
    }
  })
})
