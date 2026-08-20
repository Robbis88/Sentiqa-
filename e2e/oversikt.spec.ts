import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// Bolge 4B.2: /oversikt - systemets ansikt.
//
// Ruta har tre ansikter bak samme URL, og de skal ikke ligne hverandre:
// butikksjefen spor «hva krever noe av meg i dag», eieren «hvor i
// portefoljen skal blikket», og nettbrettet er en helt annen verden.
//
// FIXTUREN GAAR GJENNOM MOTOREN. Seeden legger inn en krenkelse, en
// oppgave over frist og to varsler - og motoren, ikke seeden, avgjor at
// de havner paa 1000, 500 og 50 poeng. Bevisene under sammenligner mot
// den rekkefolgen; ingen av dem stoler paa insert-rekkefolgen.
// =====================================================================

const SJEF = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }
const TOM_SJEF = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }
const NETTBRETT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }

async function loggInn(page: Page, b: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', b.epost)
  await page.fill('input[name="passord"]', b.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

/** Venter til sida faktisk er tegnet - ikke bare til `load`. */
async function tilOversikten(page: Page) {
  await page.goto('/oversikt')
  await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })
}

const NIVAAORD = ['Haster', 'Følg med', 'Til orientering']

/** Stasjonene i Analysekjeden, og en fra en kjede sjefen ikke har. */
const UNDERBY = '44444444-4444-4444-8444-111111111111'   // 5101
const GRENSEBY = '44444444-4444-4444-8444-222222222222'  // 5102
const FREMMED = '22222222-2222-4222-8222-222222222222'   // Testkjeden

/** Hva toppstripen staar paa. */
async function skallet(page: Page): Promise<string> {
  const velger = page.locator('.sq-stasjonskontekst select')
  return (await velger.evaluate(
    (e) => (e as HTMLSelectElement).selectedOptions[0]?.textContent ?? '')).trim()
}

async function axeRent(page: Page, hva: string) {
  const res = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  const funn = res.violations.flatMap((v) => v.nodes.map(
    (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
  ))
  expect(funn, `\n${hva}\n${funn.join('\n')}\n`).toEqual([])
}

// ---------------------------------------------------------------------
// BUTIKKSJEFEN
// ---------------------------------------------------------------------
test.describe('/oversikt for butikksjefen', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, SJEF)
    await tilOversikten(page)
  })

  test('A - det hoyest prioriterte staar forst', async ({ page }) => {
    const saker = page.locator('.sq-sak')
    await expect(saker.first()).toBeVisible()

    // Krenkelsen er den ene tingen som alltid skal staa oeverst.
    await expect(saker.first()).toContainText('Melding om krenkelse')
    await expect(saker.first()).toHaveAttribute('data-niva', 'kritisk')

    // ALT KRITISK STAAR OVER ALT ANNET. Det er det motoren faktisk
    // garanterer - 1000 grunnpoeng er over baade folg-taket paa 900 og
    // info-taket paa 650 (bevist i signaler.test.ts).
    //
    // Testen krevde foer at HELE lista var ikke-stigende i alvor. Den
    // var groenn, men den maalte et loefte motoren ikke gir: et tungt
    // info-funn kan gaa foran et nakent folg-funn, med vilje. En test
    // som laaser en oppforsel produktet ikke har lovt, blokkerer en
    // riktig endring senere - og den ville gjort det uten aa forklare
    // hvorfor.
    const nivaaer = await saker.evaluateAll(
      (n) => n.map((e) => e.getAttribute('data-niva') ?? ''))
    expect(nivaaer.length, 'Fixturen gir ingen signaler').toBeGreaterThan(2)
    const sisteKritisk = nivaaer.lastIndexOf('kritisk')
    const forsteIkkeKritisk = nivaaer.findIndex((n) => n !== 'kritisk')
    if (sisteKritisk >= 0 && forsteIkkeKritisk >= 0) {
      expect(sisteKritisk, `Kritisk under noe mildere: ${nivaaer.join(' -> ')}`)
        .toBeLessThan(forsteIkkeKritisk)
    }

    // Og merkelappen skal beskrive den sorteringen som finnes.
    await expect(page.locator('.sq-seksjon-hode'))
      .toContainText('Etter alvor, konsekvens og varighet')
  })

  test('A2 - lista staar OVER tallene, ikke under', async ({ page }) => {
    // Kjernen i hele bolgen. Sakene laa tidligere under pulsen, altsaa
    // under to omsetningstall hun ikke kan gjore noe med i dag.
    const saker = await page.locator('.sq-sak').first().boundingBox()
    expect(saker, 'Ingen saker aa maale').not.toBeNull()
    const puls = await page.locator('.sq-puls').first().boundingBox()
    if (puls) {
      expect(saker!.y, 'Oppmerksomheten ligger under omsetningstallene').toBeLessThan(puls.y)
    }
  })

  test('B - alvoret kan leses uten farge', async ({ page }) => {
    // Hver sak maa si alvoret sitt i ord. Stripen og fargen forsterker.
    const ord = await page.locator('.sq-sak .sq-status').evaluateAll(
      (n) => n.map((e) => (e.textContent ?? '').trim()))
    expect(ord.length, 'Ingen saker har alvor i ord').toBeGreaterThan(0)
    for (const o of ord) expect(NIVAAORD, `Ukjent alvorsord: «${o}»`).toContain(o)

    // Og ingen status paa sida staar tom - da ville fargen baaret alene.
    const tomme = await page.locator('.sq-status, .sq-signal').evaluateAll(
      (n) => n.map((e) => (e.textContent ?? '').trim()).filter((t) => t.length === 0))
    expect(tomme, 'Status eller signal uten tekst').toEqual([])
  })

  test('B2 - rangeringen kan forstaas uten aa lese algoritmen', async ({ page }) => {
    // «1 oppgave over frist» staar over varselet fordi den har ligget i
    // dager. Ligger grunnlaget bak et klikk, maa man TRO paa
    // rekkefolgen i stedet for aa se den.
    const oppgave = page.locator('.sq-sak', { hasText: 'over frist' }).first()
    await expect(oppgave.locator('.sq-bevis')).toContainText(/dager? på rad/)
  })

  test('C - handlingen i signalet virker', async ({ page }) => {
    const sak = page.locator('.sq-sak', { hasText: 'Melding om krenkelse' }).first()
    await sak.getByRole('link', { name: 'Undersøk' }).click()
    await expect(page).toHaveURL(/\/tilbakemeldinger/)
  })

  test('C2 - de ovrige handlingene er i behold', async ({ page }) => {
    // Opprett oppgave, sett som fokus, send til tablet, skjul. De
    // ENDRER noe, og ligger derfor bak utvidelsen - men de skal finnes.
    const sak = page.locator('.sq-sak').first()
    await sak.getByText('Flere handlinger').click()
    for (const t of ['Opprett oppgave', 'Sett som fokus', 'Send til tablet', 'Skjul i 7 dager']) {
      await expect(sak.getByRole('button', { name: t }), t).toBeVisible()
    }
  })

  test('D - et skjult signal holder seg skjult', async ({ page }) => {
    const tekst = await page.locator('body').innerText()
    // Soesknene er identiske bortsett fra skjulingen. Uten det synlige
    // kunne dette beviset ikke skille «skjuling virker» fra «varsler
    // vises ikke i det hele tatt».
    expect(tekst, 'Det synlige varselet mangler - fixturen naar ikke fram')
      .toContain('Bemanningen er innenfor rammen')
    expect(tekst, 'Et lukket signal er tilbake i lista')
      .not.toContain('Skjult varsel som ikke skal vises')
  })

  test('F - butikksjefen ser ikke eierens portefoljebilde', async ({ page }) => {
    const tekst = await page.locator('body').innerText()
    for (const eiers of ['Stasjonene mot hverandre', 'Mot budsjett denne måneden', 'Stasjonsrangering']) {
      expect(tekst, `Butikksjefen fikk eierens «${eiers}»`).not.toContain(eiers)
    }
  })

  test('H - axe er ren med flere signalnivaaer', async ({ page }) => {
    await axeRent(page, 'butikksjefens oversikt')
  })

  test('I - skallet og sida er enige om stasjonen', async ({ page }) => {
    const vist = await skallet(page)
    const skallnr = vist.match(/\d{4}/)?.[0]
    const hode = await page.locator('.sq-sidehode').first().innerText()
    const paaSida = [...new Set(hode.match(/(5101|5102|5103)/g) ?? [])]

    // Sidehodet SKAL navngi stasjonen. Sto det ingenting der, kunne
    // testen ikke skille «enige» fra «sida sier ingenting».
    expect(paaSida, `Sidehodet navngir ingen stasjon: «${hode}»`).toEqual([skallnr])
  })

  test('J - kommandopaletten virker fra forsiden', async ({ page }) => {
    await page.keyboard.press('Control+k')
    await expect(page.locator('.sq-palett')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.locator('.sq-palett')).toHaveCount(0)
  })
})

// ---------------------------------------------------------------------
// DEN ROLIGE TILSTANDEN
// ---------------------------------------------------------------------
test.describe('/oversikt uten funn', () => {
  test('normal er stille, ikke tom', async ({ page }) => {
    // Testkjeden har ingen drift. Da skal forsiden SI at det er i
    // orden - ikke vise en tom liste og la sjefen lure.
    await loggInn(page, TOM_SJEF)
    await tilOversikten(page)
    await expect(page.locator('body')).toContainText('Ingenting trenger oppmerksomhet')
    expect(await page.locator('.sq-sak').count(), 'Saker uten data').toBe(0)
    await axeRent(page, 'den rolige forsiden')
  })
})

// ---------------------------------------------------------------------
// EIEREN
// ---------------------------------------------------------------------
test.describe('/oversikt for eieren', () => {
  test.use({ storageState: OKTFIL })

  test('E - eieren faar portefoljen, ikke en kopi av butikksjefens', async ({ page }) => {
    await tilOversikten(page)
    await expect(page.locator('.sq-sidehode h1')).toContainText('stasjoner')
    await expect(page.locator('body')).toContainText('Stasjonene mot hverandre')

    // Butikksjefens operative bilde skal ikke staa her.
    const tekst = await page.locator('body').innerText()
    for (const sjefens of ['Dine fokuspunkter', 'Fremover']) {
      expect(tekst, `Eieren fikk butikksjefens «${sjefens}»`).not.toContain(sjefens)
    }
  })

  test('E2 - stasjonene staar i ord, ikke bare i farge', async ({ page }) => {
    await tilOversikten(page)
    const rader = page.locator('.sq-rad')
    await expect(rader.first()).toBeVisible()
    const tomme = await page.locator('.sq-rad .sq-status').evaluateAll(
      (n) => n.map((e) => (e.textContent ?? '').trim()).filter((t) => t.length === 0))
    expect(tomme, 'Stasjonsrad med farge, uten ord').toEqual([])
  })

  test('E3 - eierens saker staar ogsaa over tallene', async ({ page }) => {
    await tilOversikten(page)
    const saker = page.locator('.sq-sak')
    await expect(saker.first()).toHaveAttribute('data-niva', 'kritisk')
    const forst = await saker.first().boundingBox()
    const puls = await page.locator('.sq-puls').first().boundingBox()
    if (puls) expect(forst!.y).toBeLessThan(puls.y)
  })

  test('H2 - axe er ren paa portefoljebildet', async ({ page }) => {
    await tilOversikten(page)
    await axeRent(page, 'eierens oversikt')
  })
})

// ---------------------------------------------------------------------
// NETTBRETTET - skal IKKE vaere rort
// ---------------------------------------------------------------------
test.describe('/oversikt for nettbrettet', () => {
  test('G - nettbrettet faar ikke lederflaten', async ({ page }) => {
    await loggInn(page, NETTBRETT)
    await page.goto('/oversikt')
    await expect(page.locator('body')).toBeVisible()

    expect(await page.locator('.sq-sidehode').count(),
      'Nettbrettet fikk lederens sidehode').toBe(0)
    expect(await page.locator('.sq-sak').count(),
      'Nettbrettet fikk lederens saksliste').toBe(0)

    // Og det er fortsatt nettbrettets egen flate.
    const overskrifter = await page.evaluate(() => [...document.querySelectorAll('h1, h2, h3')]
      .map((e) => (e.textContent ?? '').trim()).filter(Boolean))
    expect(overskrifter.length, 'Nettbrettets hjem er tomt').toBeGreaterThan(0)
  })
})

// ---------------------------------------------------------------------
// STASJONSKONTEKSTEN PAA FORSIDEN
//
// Korrekthetstrinnet etter 4B.2. Butikksjefens /oversikt leste ALLE
// hennes stasjoner uansett hva toppstripen sto paa - skallet sa «5102
// Grenseby» over en side som regnet paa alle tre. Det er den samme
// doble konteksten trinn 09 lukket, og den sto igjen paa systemets
// forside fordi bare eiergrenen var koblet paa.
//
// Bevisene under maaler INNDATA, ikke bare overskriften: oppgaven over
// frist ligger paa 5101, saa den skal forsvinne fra sakslista naar
// konteksten er 5102. En test som bare leser sidehodet ville vaert
// groenn selv om signalmotoren fortsatt fikk alle stasjonene.
// ---------------------------------------------------------------------
test.describe('/oversikt foelger stasjonskonteksten', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, SJEF)
  })

  test('skall 5101 -> forsiden leser 5101', async ({ page }) => {
    await page.goto(`/oversikt?stasjon=${UNDERBY}`)
    await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })

    expect(await skallet(page)).toContain('5101')
    await expect(page.locator('.sq-sidehode h1')).toContainText('5101')
    // Oppgaven over frist ligger paa 5101 og SKAL vaere med.
    await expect(page.locator('.sq-sak', { hasText: 'over frist' })).toHaveCount(1)
  })

  test('skall 5102 -> forsiden leser 5102, og inndataene foelger med', async ({ page }) => {
    await page.goto(`/oversikt?stasjon=${GRENSEBY}`)
    await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })

    expect(await skallet(page)).toContain('5102')
    await expect(page.locator('.sq-sidehode h1')).toContainText('5102')

    // DETTE ER SELVE BEVISET. Oppgaven ligger paa 5101; staar den her,
    // leser motoren fortsatt alle stasjonene.
    await expect(page.locator('.sq-sak', { hasText: 'over frist' })).toHaveCount(0)
  })

  test('delt lenke gir samme kontekst i skall og side - paa forste visning', async ({ page }) => {
    // Proxyen skriver kapselen naar lenka baerer en gyldig stasjon, men
    // den gjelder foerst fra NESTE forespoersel. Leste sida bare
    // kapselen, ville en delt lenke vist skallets nye stasjon over
    // sidas gamle - og det er den eneste visningen en delt lenke faar.
    await page.goto(`/oversikt?stasjon=${GRENSEBY}`)
    await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })
    const vist = await skallet(page)
    const hode = await page.locator('.sq-sidehode').first().innerText()
    expect(hode).toContain(vist.match(/\d{4}/)?.[0] ?? 'x')
  })

  test('en valgt stasjon gir ikke et skjult aggregat', async ({ page }) => {
    // /oversikt taaler aggregat bare for eieren (TAALER_AGGREGAT).
    // Butikksjefen med tre stasjoner skal derfor ha EN stasjon, ikke en
    // sum forkledd som en.
    await page.goto(`/oversikt?stasjon=${GRENSEBY}`)
    await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })

    const hode = await page.locator('.sq-sidehode').first().innerText()
    expect(hode, 'Sidehodet summerer i stedet for aa navngi').not.toContain('Dine stasjoner')
    expect([...new Set(hode.match(/(5101|5102|5103)/g) ?? [])]).toEqual(['5102'])
  })

  test('en lenke til en annen kjedes stasjon flytter ingen', async ({ page }) => {
    // Oppslaget gaar gjennom brukerens egen sesjon, saa RLS avgjor hva
    // som finnes. En daarlig lenke skal falle pent tilbake - ikke gi tom
    // side, og aller minst vise en annen kjedes tall.
    await page.goto(`/oversikt?stasjon=${FREMMED}`)
    await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })

    const hode = await page.locator('.sq-sidehode').first().innerText()
    const paaSida = [...new Set(hode.match(/\d{4}/g) ?? [])]
    for (const nr of paaSida) {
      expect(['5101', '5102', '5103'], `Fikk ${nr}, som ikke er hennes`).toContain(nr)
    }
    expect(await skallet(page)).toMatch(/510[123]/)
  })

  test('pulsen er den valgte stasjonens, og den samme hver gang', async ({ page }) => {
    // `r[0]` fra en spoerring uten `order by`: med tre stasjoner var det
    // udefinert hvilken stasjons uketall som havnet under overskriften.
    // Basen kan returnere radene i hvilken som helst rekkefolge.
    const lest: string[] = []
    for (let i = 0; i < 3; i++) {
      await page.goto(`/oversikt?stasjon=${UNDERBY}`)
      await expect(page.locator('.sq-sidehode h1')).toBeVisible({ timeout: 20_000 })
      const puls = page.locator('.sq-puls')
      if (await puls.count() === 0) test.skip(true, 'Ingen komplett uke i fixturen')
      lest.push((await puls.first().innerText()).replace(/\s+/g, ' ').trim())
    }
    expect(new Set(lest).size, `Pulsen varierer mellom kjoringer: ${lest.join(' | ')}`).toBe(1)
    expect(lest[0], 'Pulsen navngir ikke den valgte stasjonen').toContain('5101')
  })
})
