import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 2: analysefamilien.
//
// Aatte ruter som alle svarer paa «hva skjedde, er det bra, hvorfor».
// Denne fila maaler at de bruker det SAMME analytiske spraaket - ikke at
// de ser like ut, for aerendet er ulikt fra rute til rute.
//
// TO AV DEM MAALES PAA EKTE TALL. /timesalg og /kasserer fikk
// deterministisk fixture i denne bolgen (port 0), saa de kan verifiseres
// med data og ikke bare i tomtilstand. Tallene under faller ut av
// produksjonsberegningen; ingenting er mocket.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }
const UNDERBY = '44444444-4444-4444-8444-111111111111'

/**
 * Rutene i bolgen som TESTBRUKEREN naar.
 *
 * /dekning og /analyse staar utenfor lista: de er eierens (roller [A] i
 * navigasjonen), og seeden har ingen eier - eierrollen tvinges gjennom
 * TOTP og trenger en seedet faktor. Det er notert i seed.sql fra
 * stemplingsrunden, og gjelder fortsatt.
 */
const FAMILIEN = [
  '/salg',
  '/timesalg',
  '/kasserer',
  '/rutiner/oversikt',
  '/salgsprognose',
  '/produksjonsplan/treffsikkerhet',
]

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

const sifre = (s: string | null) => (s ?? '').replace(/\D/g, '')

const nokkeltall = (page: Page, merkelapp: string | RegExp) =>
  page.locator('.sq-nokkeltall').filter({
    has: typeof merkelapp === 'string'
      ? page.getByText(merkelapp, { exact: true })
      : page.getByText(merkelapp),
  })

test.describe('bolge 2 - analysefamilien', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const sti of FAMILIEN) {
    test(`${sti} bruker familiens spraak`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      const svar = await page.goto(sti)
      expect(svar?.status()).toBeLessThan(400)
      await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)

      // De to handskrevne systemene skal vaere borte fra hele bolgen.
      // To sett som ser NESTEN like ut er dyrere enn ett som ser
      // annerledes ut.
      expect(await page.locator('.status-pip').count(), `${sti}: gammel status-pip`).toBe(0)
      expect(await page.locator('.kpi').count(), `${sti}: gammelt kpi-kort`).toBe(0)

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

  // -------------------------------------------------------------------
  // EKTE TALL
  // -------------------------------------------------------------------
  test('/timesalg viser doegnrytmen fra fixturen', async ({ page }) => {
    await page.goto(`/timesalg?stasjon=${UNDERBY}`)

    // 1000 + 3000 + 12000 + 6000 + 3000 = 25000, topp kl. 11-12.
    const topp = nokkeltall(page, 'Travleste time')
    await expect(topp.locator('.sq-nokkeltall-verdi')).toContainText('11-12')
    await expect(topp).toContainText('12 000')

    const dagen = nokkeltall(page, 'Hele dagen')
    expect(sifre(await dagen.locator('.sq-nokkeltall-verdi').textContent())).toBe('25000')
    await expect(dagen).toContainText('5 timer med salg')
  })

  test('/kasserer - RETNING OG DOM PEKER HVER SIN VEI', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)

    // Omsetning 60000 + 30000 + 10000 = 100000, bonger 1000.
    const oms = nokkeltall(page, 'Omsetning')
    expect(sifre(await oms.locator('.sq-nokkeltall-verdi').textContent())).toBe('100000')

    // Avvik 1200 + 800 + 500 = 2500 = 2,5 % > grensa paa 2 %.
    const avvik = nokkeltall(page, 'Retur, makulert og slettet')
    expect(sifre(await avvik.locator('.sq-nokkeltall-verdi').textContent())).toBe('2500')
    await expect(avvik).toContainText('2.5 % av omsetningen')

    // MER avvik er VERRE. Et hoyere tall er ikke en god nyhet, og
    // komponenten skal ikke behandle det som en.
    await expect(avvik.locator('.sq-nokkeltall-mot')).toHaveClass(/darlig/)
    await expect(avvik.locator('.sq-nokkeltall-mot')).not.toHaveClass(/god/)
  })

  test('kassereroppgjoret staar som sammenligningsmatrise', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)
    const t = page.locator('.sq-datatabell').first()
    await expect(t).toBeVisible()
    await expect(t.locator('thead th')).toHaveText(
      ['Kasserer', 'Omsetning', 'Bonger', 'Retur', 'Makulert', 'Slettet'])
    // Tre kasserere paa Underby.
    await expect(t.locator('tbody tr')).toHaveCount(3)
    await expect(t.locator('tbody tr').first()).toContainText('Kari Kasserer')
  })

  test('INGEN TILSTAND FINNES BARE SOM FARGE', async ({ page }) => {
    // Regelen fra /fokus i bolge 1, gjort til en maaling for hele
    // analysesystemet: hvert statusmerke maa ha lesbar tekst i seg.
    for (const sti of [`/kasserer?stasjon=${UNDERBY}`, '/rutiner/oversikt']) {
      await page.goto(sti)
      const tomme = await page.locator('.sq-status').evaluateAll(
        (noder) => noder
          .map((n) => (n.textContent ?? '').trim())
          .filter((t) => t.length === 0),
      )
      expect(tomme, `${sti}: statusmerke uten tekst - fargen baerer alene`).toEqual([])
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
})
