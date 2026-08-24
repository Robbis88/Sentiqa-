import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 4B.1: /bemanning.
//
// AERENDET, IKKE RENDRINGEN. Testene her beviser at lederen kommer fra
// «har jeg riktige folk paa jobb» til «her maa jeg gjore noe» - ikke
// bare at sida tegnes uten aa krasje.
//
// Seeden har ingen bemanningsoppsett, saa sida moter oss i den forste
// blokkeringen: uten et bemannet vindu kan planen ikke lages i det hele
// tatt. Det er ikke en tomtilstand som unnskylder maalingen - det ER
// tilstanden en ny kunde faktisk moter, og den viktigste av de fem
// `nesteSteg` rangerer.
// =====================================================================

const SJEF = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', SJEF.epost)
  await page.fill('input[name="passord"]', SJEF.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

test.describe('/bemanning', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
    await page.goto('/bemanning')
    // VENT PAA SISTE SEKSJON, ikke paa `load`. Sida stromme-rendres, saa
    // `goto` kom tilbake mens bare skallet stod der - og en `count()`
    // rett etterpaa leste 0 knapper paa en side som fikk dem 65 ms
    // senere. Feilbildet var identisk med «knappen er borte».
    await expect(page.getByRole('heading', { name: 'Ferie og fravær' }))
      .toBeVisible({ timeout: 20_000 })
  })

  test('A - lederen ser HVA som krever oppmerksomhet, uten aa lete', async ({ page }) => {
    // Svaret staar i sidehodet, og det som stopper planen staar som et
    // signal over alt annet - ikke som en setning i seksjon tre mens
    // skjemaet ligger i seksjon seks.
    await expect(page.locator('.sq-sidehode h1')).toHaveText('Bemanning')

    const signal = page.locator('.sq-signal').first()
    await expect(signal).toBeVisible()
    const tekst = await signal.innerText()
    expect(tekst.length, 'Signalet sier ikke hva som stopper planen').toBeGreaterThan(30)
  })

  test('B - tilstanden kan forstaas uten farge', async ({ page }) => {
    // Hvert signal og hver status maa ha lesbar tekst i seg. Fargen
    // forsterker; den baerer ikke.
    const tomme = await page.locator('.sq-signal, .sq-status').evaluateAll(
      (n) => n.map((e) => (e.textContent ?? '').trim()).filter((t) => t.length === 0))
    expect(tomme, 'Signal eller status uten tekst').toEqual([])

    // Den gamle kortkanten som eneste alvorsmarkoer er borte.
    expect(await page.locator('.kort.oppmerksomhet').count(),
      'Alvoret ligger fortsatt i en kortkant').toBe(0)
  })

  test('C - veien videre ligger I situasjonen', async ({ page }) => {
    // Blokkeringen som krever data peker til Import; de ovrige peker til
    // skjemaet som loser dem. Uten en vei videre er analysen bare
    // rapportering.
    const signal = page.locator('.sq-signal').first()
    const lenker = await signal.locator('a, button').count()
    const panelKnapper = await page.getByRole('button', { name: /^N(y|ytt) / }).count()
    expect(lenker + panelKnapper,
      'Ingen vei fra blokkeringen til handlingen').toBeGreaterThan(0)
  })

  test('D - detaljene for sammenligning er der fortsatt', async ({ page }) => {
    // Oppsettet er fem lister som til sammen avgjor planen. Ingen av dem
    // skal ha forsvunnet i en sammenslaaing.
    const tekst = await page.locator('body').innerText()
    for (const overskrift of [
      'Når står det folk i butikken?',
      'Hvor mange får plass?',
      'Faste vakter',
      'Timer der én ikke holder',
      'Ferie og fravær',
    ]) {
      expect(tekst, `Seksjonen «${overskrift}» er borte`).toContain(overskrift)
    }
  })

  test('E - ingen handling er borte', async ({ page }) => {
    // De fire opprettelsespanelene og maaneds-filteret. Slett-knappene
    // finnes bare naar det finnes rader, saa de maales ikke her.
    for (const knapp of ['Nytt vindu', 'Ny fast vakt', 'Nytt krav', 'Nytt fravær']) {
      await expect(page.getByRole('button', { name: knapp }), knapp).toBeVisible()
    }
    // ROLLE, IKKE BARE ETIKETT. Da «Ny fast vakt» fikk et «Gjelder fra»-
    // felt, begynte getByLabel('Måned') å treffe to elementer: Chromium
    // eksponerer datofeltets indre måned-hjul med samme navn.
    //
    // Rollen skiller dem, og skjerper samtidig kontrollen: den sier nå
    // at det finnes en månedsVELGER, ikke bare noe som heter «Måned».
    await expect(page.getByRole('combobox', { name: 'Måned' })).toBeAttached()
    await expect(page.getByRole('button', { name: 'Vis måneden' })).toBeVisible()

    // ÅRSFELTET ER BORTE, og det er meningen. Måneden og året lå i to
    // felt fordi `?maned=` var et tall fra 1 til 12 - og det samme
    // parameternavnet betydde en ISO-dato på /svinn og /kasserer. Ett
    // felt, én betydning. Se src/lib/periode.ts.
    await expect(page.getByRole('spinbutton', { name: 'År' })).toHaveCount(0)
    // Verdien er ISO nå, ikke «9».
    await expect(page.getByRole('combobox', { name: 'Måned' }))
      .toHaveValue(/^\d{4}-\d{2}-01$/)
  })

  test('F - nettbrettet naar ikke bemanningen', async ({ page, context }) => {
    await context.clearCookies()
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })

    await page.goto('/bemanning')
    await expect(page.locator('body')).toContainText(/ikke tilgang|Kun eier|logg inn|eier/i)
  })

  test('G - ingen axe-brudd', async ({ page }) => {
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('stasjonskontrakten er urort - ingen lokal velger', async ({ page }) => {
    // Trinn 09 er laast. Bemanningen skal ikke ha gjeninnfort sin egen.
    expect(await page.locator('form.sq-listetopp [name="stasjon"], [name="butikknummer"]').count(),
      'Lokal stasjonsvelger er tilbake').toBe(0)

    // Skallet og sida skal vaere enige, som overalt ellers.
    const velger = page.locator('.sq-stasjonskontekst select')
    if (await velger.count() > 0) {
      const vist = (await velger.evaluate(
        (e) => (e as HTMLSelectElement).selectedOptions[0]?.textContent ?? '')).trim()
      const nr = vist.match(/\d{4}/)?.[0]
      if (nr) await expect(page.locator('.sq-sidehode')).toContainText(nr)
    }
  })

  test('ingen .tablet-klasse har lekket inn', async ({ page }) => {
    const lekkasje = await page.evaluate(() => [...document.querySelectorAll('[class]')]
      .flatMap((e) => [...e.classList])
      .filter((k) => k.startsWith('tablet-')))
    expect(lekkasje, 'Nettbrettets stiler paa lederens flate').toEqual([])
  })
})
