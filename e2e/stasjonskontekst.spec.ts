import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// EN SANNHET OM HVILKEN STASJON MAN SER PAA.
//
// Feilen trinn 09 lukker: appskallet og siden leste hver sin kilde.
// Skallet hadde en informasjonskapsel, /produksjonsplan hadde
// `?butikknummer=`, og de visste ikke om hverandre. Skjermen kunne si
// «5102 Grenseby» i toppen mens planen under gjaldt 4177.
//
// TESTENE MAALER PARET, IKKE DELENE. Nesten hver test her sammenligner
// det skallet viser med det siden faktisk regner paa. En test som bare
// sjekket den ene ville vaert gronn gjennom hele feilen.
//
// Analysekjeden har tre stasjoner (5101 Underby, 5102 Grenseby,
// 5103 Overby), saa velgeren vises og det finnes noe aa bytte mellom.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Teksten i appskallets stasjonsvelger, f.eks. «5101 Underby». */
async function skallet(page: Page): Promise<string> {
  const velger = page.locator('.sq-stasjonskontekst select')
  await expect(velger).toBeVisible()
  return (await velger.evaluate(
    (e) => (e as HTMLSelectElement).selectedOptions[0]?.textContent ?? '',
  )).trim()
}

/** Stasjonen siden faktisk regner paa - den staar i sidehodet. */
async function siden(page: Page): Promise<string> {
  return (await page.locator('.sq-sidehode').innerText())
}

/** Det som skal vaere umulig etter trinn 09: to kontekster paa en skjerm. */
async function enigeOmStasjon(page: Page) {
  const i = await skallet(page)
  const tekst = await siden(page)
  expect(tekst, `Skallet viser «${i}», men sida sier noe annet:\n${tekst}`)
    .toContain(i)
  return i
}

test.describe('stasjonskontekst', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  test('A - uten parameter er skall og side enige', async ({ page }) => {
    await page.goto('/produksjonsplan?dato=2026-02-02')
    await enigeOmStasjon(page)
  })

  test('B - parameteren overstyrer det huskede valget', async ({ page }) => {
    // Husk 5101 forst, be saa om 5103 i URL-en.
    await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
    expect(await skallet(page)).toContain('5101')

    await page.goto('/produksjonsplan?butikknummer=5103&dato=2026-02-02')
    expect(await enigeOmStasjon(page)).toContain('5103')
  })

  test('C+L - delt lenke aapner riktig stasjon OG blir det nye huskede', async ({ page }) => {
    await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
    expect(await skallet(page)).toContain('5101')

    // Lenka noen delte: stasjon B mens hukommelsen staar paa A.
    await page.goto('/produksjonsplan?butikknummer=5102&dato=2026-02-02')
    expect(await enigeOmStasjon(page)).toContain('5102')

    // URL-en skal ha skrevet hukommelsen. Uten det spretter brukeren
    // tilbake til 5101 idet hun navigerer videre - to sannheter igjen,
    // bare forskjovet ett klikk.
    await page.goto('/produksjonsplan?dato=2026-02-02')
    expect(await enigeOmStasjon(page)).toContain('5102')
  })

  test('D - uten URL brukes det huskede valget', async ({ page }) => {
    await page.goto('/produksjonsplan?butikknummer=5103&dato=2026-02-02')
    await page.goto('/svinn')
    await page.goto('/produksjonsplan?dato=2026-02-02')
    expect(await enigeOmStasjon(page)).toContain('5103')
  })

  test('E+K - en stasjon brukeren ikke har, endrer ingenting', async ({ page }) => {
    await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
    expect(await skallet(page)).toContain('5101')

    // 4177 finnes, men i Testkjeden. RLS gir den aldri til denne brukeren.
    await page.goto('/produksjonsplan?butikknummer=4177&dato=2026-02-02')
    const naa = await enigeOmStasjon(page)
    expect(naa, 'En annen kjedes stasjon slapp gjennom').not.toContain('4177')
    expect(naa).toContain('5101')

    // Og den ugyldige verdien skal ikke ha skrevet seg inn i hukommelsen.
    await page.goto('/produksjonsplan?dato=2026-02-02')
    expect(await skallet(page)).toContain('5101')

    // Velgeren tilbyr heller ikke stasjoner utenfor kjeden.
    const valg = await page.locator('.sq-stasjonskontekst select option').allInnerTexts()
    expect(valg.join(' ')).not.toContain('4177')
    expect(valg.join(' ')).not.toContain('Testby')
  })

  test('F - «alle stasjoner» finnes der sida taaler det, og bare der', async ({ page }) => {
    // /svinn summerer stasjoner. /produksjonsplan kan ikke - en plan for
    // alle stasjoner er ikke en plan noen kan bake etter.
    await page.goto('/svinn')
    const paaSvinn = await page.locator('.sq-stasjonskontekst select option').allInnerTexts()
    expect(paaSvinn.join(' ')).toContain('Alle stasjoner')

    await page.goto('/produksjonsplan?dato=2026-02-02')
    const paaPlan = await page.locator('.sq-stasjonskontekst select option').allInnerTexts()
    expect(paaPlan.join(' '), 'Skallet tilbod aggregat paa en side som ikke taaler det')
      .not.toContain('Alle stasjoner')
  })

  test('J - fra «alle» til en side som krever en stasjon', async ({ page }) => {
    await page.goto('/svinn')
    await page.locator('.sq-stasjonskontekst select').selectOption({ label: 'Alle stasjoner' })
    await expect(page.locator('.sq-stasjonskontekst select')).toHaveValue('alle')

    // Planen kan ikke aggregere. Da skal BEGGE lande paa samme konkrete
    // stasjon - ikke skallet paa «alle» og sida paa en av dem.
    await page.goto('/produksjonsplan?dato=2026-02-02')
    const valgt = await enigeOmStasjon(page)
    expect(valgt, 'Skallet sto igjen paa «alle» der sida ikke taaler det')
      .not.toContain('Alle')
    expect(valgt).toMatch(/51\d\d/)
  })

  test('H - bytter man stasjon i skallet, folger sida med', async ({ page }) => {
    await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
    expect(await enigeOmStasjon(page)).toContain('5101')

    // Et klikk NAA skal slaa parameteren i adressefeltet. Gjor det ikke
    // det, vinner URL-en og valget ser dodt ut for brukeren.
    // Serverhandlingen rydder parameteren og sender henne til samme side
    // uten den - dagen skal staa igjen.
    await page.locator('.sq-stasjonskontekst select').selectOption({ label: '5103 Overby' })
    await expect(page).not.toHaveURL(/butikknummer/, { timeout: 15_000 })
    await expect(page).toHaveURL(/dato=2026-02-02/)
    expect(await enigeOmStasjon(page)).toContain('5103')
  })

  test('I - ingen skjult dobbel kontekst paa rutene som er koblet paa', async ({ page }) => {
    for (const sti of [
      '/produksjonsplan?dato=2026-02-02',
      '/produksjonsplan?butikknummer=5102&dato=2026-02-02',
    ]) {
      await page.goto(sti)
      await enigeOmStasjon(page)
    }
  })

  // =================================================================
  // DEN GENERELLE REGRESJONSTESTEN.
  //
  // Selve feilen, som en maaling som kan kjores paa hvilken som helst
  // rute: viser skallet en stasjon, skal sida regne paa DEN. Viser
  // skallet «Alle stasjoner», skal sida si at den summerer.
  //
  // De enkelte testene over maaler ett scenario hver. Denne maaler
  // EGENSKAPEN, og den er billig aa utvide: legg ruta i lista.
  // =================================================================
  const RUTER = [
    '/produksjonsplan?dato=2026-02-02',
    '/produksjonsplan/treffsikkerhet',
    '/svinn',
    '/salg',
    '/timesalg',
    '/kasserer',
    '/regnskap',
    '/salgsprognose',
  ]

  for (const rute of RUTER) {
    test(`skall og side er enige paa ${rute.split('?')[0]}`, async ({ page }) => {
      await page.goto(rute)

      const velger = page.locator('.sq-stasjonskontekst select')
      if (await velger.count() === 0) {
        test.skip(true, 'Ingen velger - brukeren har ikke noe aa velge mellom')
      }
      const vist = await skallet(page)

      const hode = page.locator('.sq-sidehode')
      if (await hode.count() === 0) {
        test.skip(true, 'Sida har ikke noe sidehode aa sammenligne med')
      }
      const tekst = await hode.first().innerText()

      if (/^Alle stasjoner/i.test(vist)) {
        // Skallet sier aggregat. Da skal ikke sida vise EN stasjon.
        expect(tekst, `Skallet summerer, men sida viser en enkelt stasjon:
${tekst}`)
          .toMatch(/alle stasjoner|samlet|kjeden/i)
      } else {
        // Skallet viser en konkret stasjon. Butikknummeret er den
        // entydige delen - navnet kan staa forkortet.
        const nr = vist.match(/\d{4}/)?.[0]
        if (!nr) test.skip(true, 'Stasjonen har ikke butikknummer aa matche paa')
        expect(tekst, `Skallet viser «${vist}», sida sier:
${tekst}`)
          .toContain(nr!)
      }
    })
  }

  test('G - skjemafeltene er urort payload, ikke kontekst', async ({ page }) => {
    // «Hvilken stasjon gjelder det jeg oppretter» er noe annet enn
    // «hvilken stasjon ser jeg paa». Konsolideringen skal ikke ha rort
    // opprettelsesskjemaene.
    await page.goto('/oppgaver')
    await page.getByRole('button', { name: /Ny oppgave/i }).first().click()
    const panel = page.locator('dialog[open]')
    await expect(panel.locator('select[name="stasjon_id"]')).toBeVisible()
  })
})
