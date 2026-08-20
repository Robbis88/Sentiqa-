import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Pilot C: /produksjonsplan - arbeidsflytmonsteret, maalt paa ekte tall.
//
// Samme oppsett som /svinn: Testkjeden er tom og gir tomtilstanden,
// Analysekjeden har en deterministisk fixture og gir planen.
//
// TALLENE FALLER UT AV MOTOREN, ikke av testen. Fixturen er 28 dager med
// konstant salg i januar; `lagProduksjonsplan` finner fire mandager i
// nylig-vinduet, har ingen fjoraarsdata aa matche mot, og lander paa
// snittet:
//
//   Grovbaguette 20 + Rundstykke grovt 12   = 32 stk  (1201 BAKEVARER)
//   Polse i lompe 8                         =  8 stk  (1216 VARMMAT)
//                                             40 stk  planlagt = forslag
//
// Uten vaervarsel gir motoren nøyaktig EN advarsel, og den er derfor
// telt: blir det flere, har noe i motoren endret seg, og det skal en
// test si fra om.
// =====================================================================

const TOM = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }
const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

/** Stasjon og dag fixturen er regnet for. Mandag 2026-02-02. */
const PLAN = '/produksjonsplan?butikknummer=5101&dato=2026-02-02'

async function loggInn(page: Page, bruker: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', bruker.epost)
  await page.fill('input[name="passord"]', bruker.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

const sifre = (s: string | null) => (s ?? '').replace(/\D/g, '')

const nokkeltall = (page: Page, merkelapp: string) =>
  page.locator('.sq-nokkeltall').filter({ hasText: merkelapp })

test.describe('/produksjonsplan uten salgsdata', () => {
  test('tomtilstanden forklarer hva som mangler', async ({ page }) => {
    await loggInn(page, TOM)
    await page.goto('/produksjonsplan')
    await expect(page.locator('h1')).toHaveText('Produksjonsplan')
    await expect(page.locator('.sq-tom')).toBeVisible()
    // Ikke «ingen data», men hvilken FIL som mangler og hvor den legges inn.
    await expect(page.locator('.sq-tom')).toContainText(/Salgsstatistikk/i)
    await expect(page.getByRole('link', { name: /Import/i })).toBeVisible()
  })

  test('stasjon og dag kan velges selv uten data', async ({ page }) => {
    // Filteret staar over tomtilstanden med vilje: det er slik man leter
    // seg fram til en dag som HAR data.
    await loggInn(page, TOM)
    await page.goto('/produksjonsplan')
    await expect(page.getByLabel('Stasjon')).toBeVisible()
    await expect(page.getByLabel('Dag')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Vis plan' })).toBeVisible()
  })
})

test.describe('/produksjonsplan med plan', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(PLAN)
  })

  test('NIVAA 1 - svaret staar i hodet, ikke metoden', async ({ page }) => {
    const feil: string[] = []
    page.on('pageerror', (e) => feil.push(e.message))

    await expect(page.locator('h1')).toHaveText('Produksjonsplan')
    // Tilstanden forst: utkast eller publisert, og hva det betyr.
    await expect(page.locator('.sq-sidehode')).toContainText('Utkast')
    await expect(page.locator('.sq-sidehode')).toContainText('40 enheter')
    await expect(page.locator('.sq-sidehode')).toContainText('Ikke synlig på nettbrettet ennå')

    // Metoden skal IKKE staa i toppen. Den hoerer til i Forklaring.
    await expect(page.locator('.sq-sidehode')).not.toContainText('median')

    expect(feil, `Klientfeil:\n  ${feil.join('\n  ')}`).toEqual([])
  })

  test('nokkeltallene viser planen mot forslaget', async ({ page }) => {
    const planlagt = nokkeltall(page, 'Planlagt')
    expect(sifre(await planlagt.locator('.sq-nokkeltall-verdi').textContent())).toBe('40')
    // Forslagstallet er ikke borte - det staar der det betyr noe.
    await expect(planlagt).toContainText('mot forslagets 40')

    const start = nokkeltall(page, 'Klart til morgenskift')
    expect(sifre(await start.locator('.sq-nokkeltall-verdi').textContent())).toBe('0')
    await expect(start).toContainText('av 40 planlagt')

    // INGEN DOM paa nokkeltallene: aa planlegge over eller under
    // forslaget er butikksjefens vurdering, ikke systemets.
    await expect(planlagt.locator('.sq-nokkeltall-mot')).not.toHaveClass(/god|darlig/)
  })

  test('NIVAA 3 - advarslene er signaler, ikke en punktliste', async ({ page }) => {
    const signaler = page.locator('.sq-signal')
    await expect(signaler).toHaveCount(1)
    await expect(signaler.first()).toContainText('Mangler værvarsel')
    // Tankestreken deler tilstand fra konsekvens, og begge skal staa.
    await expect(signaler.first()).toContainText('bruker kun salgshistorikk')
    // Alle staar rolig: motoren rangerer dem ikke, saa visningen skal
    // ikke finne paa en rangering heller.
    await expect(signaler.first()).toHaveClass(/sq-signal-informasjon/)
  })

  test('planen er gruppert med riktige summer', async ({ page }) => {
    const bake = page.locator('section.kort').filter({ hasText: 'BAKEVARER' })
    await expect(bake).toContainText('1201')
    await expect(bake.locator('.gruppe-sum')).toHaveText('32 stk')
    await expect(bake.locator('tbody tr')).toHaveCount(2)

    const varm = page.locator('section.kort').filter({ hasText: 'VARMMAT' })
    await expect(varm.locator('.gruppe-sum')).toHaveText('8 stk')
    await expect(varm.locator('tbody tr')).toHaveCount(1)

    // Forslag = planlagt naar ingen har rort planen.
    await expect(page.getByLabel('Planlagt Grovbaguette')).toHaveValue('20')
    await expect(page.getByLabel('Start Grovbaguette')).toHaveValue('0')
  })

  test('NIVAA 2 - neste steg er den ene knappen som ser sann ut', async ({ page }) => {
    const publiser = page.getByRole('button', { name: 'Publiser til nettbrettet' })
    await expect(publiser).toBeVisible()
    // Primar: den eneste handlingen sida sikter mot. Stepperne og
    // ekskluder-knappene er redigering, ikke neste steg.
    await expect(publiser).toHaveClass(/sq-knapp/)
    await expect(publiser).toHaveClass(/primar/)
    expect(await page.locator('.sq-knapp.primar').count(),
      'Flere likeverdige primaerknapper - da er ingen av dem neste steg').toBe(1)

    // Tilstanden staar ved siden av knappen, ikke bare i sidehodet.
    await expect(page.locator('.sq-status')).toContainText('Ikke publisert ennå')
    await expect(page.locator('.sq-status')).toHaveClass(/sq-status-handling/)
  })

  test('notatfeltet har en etikett en skjermleser finner', async ({ page }) => {
    // Feltet hadde en <h2> over seg og en plassholder inni. Ingen av
    // delene er en etikett: overskriften er ikke knyttet til feltet, og
    // plassholderen forsvinner idet man begynner aa skrive.
    await expect(page.getByLabel('Notat til de ansatte')).toBeVisible()
  })

  test('D - ingen axe-brudd paa planflaten, med kontrast', async ({ page }) => {
    await expect(page.locator('.pp-tabell').first()).toBeVisible()
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('E - planen flyter ikke ut i bredden paa desktop', async ({ page }) => {
    for (const bredde of [1280, 1440]) {
      await page.setViewportSize({ width: bredde, height: 900 })
      await expect(page.locator('.pp-tabell').first()).toBeVisible()
      const sol = await page.evaluate(() => ({
        scroll: document.documentElement.scrollWidth,
        klient: document.documentElement.clientWidth,
      }))
      expect(sol.scroll, `Vannrett rulling paa ${bredde}px`)
        .toBeLessThanOrEqual(sol.klient + 1)
    }
  })

  // MAA STAA SIST I FILA. Den skriver til produksjonsplan_hode, og
  // testene over leser tilstanden «ikke publisert». Basen er fersk per
  // CI-kjoring, saa rekkefolgen her er det eneste som holder dem fra
  // hverandre.
  test('arbeidsflyten naar fram - planen kan publiseres', async ({ page }) => {
    await page.getByRole('button', { name: 'Publiser til nettbrettet' }).click()

    // Etter publisering: tilstanden snur, og knappen tilbyr det som naa
    // er neste steg - aa publisere paa nytt.
    await expect(page.locator('.sq-status')).toContainText('Synlig på nettbrettet')
    await expect(page.locator('.sq-status')).toHaveClass(/sq-status-normal/)
    await expect(page.getByRole('button', { name: 'Publiser på nytt' })).toBeVisible()

    // Og den overlever en omlasting - det var en server, ikke bare state.
    await page.reload()
    await expect(page.locator('.sq-sidehode')).toContainText('Publisert')
  })
})
