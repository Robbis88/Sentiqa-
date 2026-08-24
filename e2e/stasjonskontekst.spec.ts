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
    // /oversikt kom inn her i korrekthetstrinnet etter bolge 4B.2.
    // Butikksjefens forside leste ALLE hennes stasjoner uansett hva
    // toppstripen sto paa, og var derfor den siste flata i systemet der
    // skallet og sida kunne si hver sin ting.
    '/oversikt',
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

      // SAMMENLIGN DET SOM FINNES AV BEVIS. Ikke hver side navngir
      // stasjonen sin - en tom /timesalg har ingen tall aa knytte til
      // noen. Da er det ingenting aa vaere uenige om, og testen sier det
      // i stedet for aa kreve et bevis som ikke finnes.
      //
      // Butikknumrene matches eksplisitt: et loepende \d{4} ville
      // truffet aarstallet i «17. mars 2026».
      const NUMRE = /(5101|5102|5103)/g
      const paaSida = [...new Set(tekst.match(NUMRE) ?? [])]
      const sidaSummerer = /alle stasjoner|samlet|kjeden/i.test(tekst)

      if (paaSida.length === 0 && !sidaSummerer) {
        test.skip(true, 'Sida navngir ikke stasjonen sin - ingenting aa sammenligne')
      }

      if (/^Alle stasjoner/i.test(vist)) {
        expect(sidaSummerer, `Skallet summerer, men sida sier:
${tekst}`).toBe(true)
        expect(paaSida, 'Skallet summerer, men sida viser EN stasjon').toEqual([])
      } else {
        const nr = vist.match(/\d{4}/)?.[0]
        expect(paaSida, `Skallet viser «${vist}», sida sier:
${tekst}`).toEqual([nr])
      }
    })
  }


  // =================================================================
  // S1-S6 - VELGEREN SELV
  //
  // Testene over maaler at SKALLET og SIDA er enige. De var groenne
  // gjennom hele feilen fra 2026-08-24, fordi de alle navigerer med
  // `page.goto()` - hard omlasting, som remonterer komponenten og
  // setter `defaultValue` paa nytt.
  //
  // Feilen levde i den MYKE veien: en lenke med `?stasjon=` inne i
  // appen. Da blir klientkomponenten staaende montert, og en
  // ukontrollert `<select>` beholder gammel verdi mens siden henter den
  // nye stasjonens data.
  //
  // S6 er den ene som ville sett det. De fem andre er porten rundt den.
  // =================================================================
  test.describe('S1-S6 velgeren og konteksten', () => {
    /**
     * Butikknumre som staar SYNLIG i toppstripen, utenom velgeren selv.
     *
     * `innerText` paa en `<select>` gir opsjonslista - alle tre
     * stasjonene - enten den er aapen eller ikke. Foerste utgave av
     * denne testen leste dem som «tre stasjoner vises samtidig» og var
     * roed uansett hva produktet gjorde.
     *
     * Velgeren maales for seg, med `selectedOptions`. Her maales alt
     * ANNET: kvitteringen, sidehodefragmenter, hva som helst noen
     * legger inn senere.
     */
    async function numreITopp(page: Page): Promise<string[]> {
      const tekst = await page.locator('.toppstripe').evaluate((el) => {
        const kopi = el.cloneNode(true) as HTMLElement
        kopi.querySelectorAll('select, option').forEach((n) => n.remove())
        return kopi.innerText ?? kopi.textContent ?? ''
      })
      return [...new Set(tekst.match(/(5101|5102|5103)/g) ?? [])]
    }

    /**
     * Bytt stasjon, og vent til SIDA har fulgt etter.
     *
     * Uten ventingen maaler paastanden et oeyeblikk der velgeren har
     * brukerens nye valg og sida fortsatt har det gamle - altsaa et
     * avvik som er ekte, men forbigaaende og forventet. Det er ikke det
     * denne suiten er ute etter.
     */
    async function byttTil(page: Page, etikett: string) {
      const nr = etikett.match(/\d{4}/)![0]
      await page.locator('.sq-stasjonskontekst select').selectOption({ label: etikett })
      await expect(page.locator('.sq-sidehode').first()).toContainText(nr, { timeout: 15_000 })
    }

    // Bytt til en ANNEN stasjon enn den som allerede staar. Velger man
    // den man er paa, er testen groenn uten aa ha maalt et bytte.
    test('S1 - velg 5102, og bade velger og side bruker 5102', async ({ page }) => {
      await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
      expect(await skallet(page)).toContain('5101')

      await byttTil(page, '5102 Grenseby')
      expect(await enigeOmStasjon(page)).toContain('5102')
    })

    test('S2 - velg 5103, og bade velger og side bruker 5103', async ({ page }) => {
      await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
      await byttTil(page, '5103 Overby')
      expect(await enigeOmStasjon(page)).toContain('5103')
    })

    test('S3 - omlasting gir samme stasjon', async ({ page }) => {
      await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
      await byttTil(page, '5102 Grenseby')
      expect(await enigeOmStasjon(page)).toContain('5102')

      await page.reload()
      expect(await enigeOmStasjon(page)).toContain('5102')
    })

    test('S4 - delt URL viser riktig stasjon ved FOERSTE visning', async ({ page }) => {
      // Hukommelsen staar paa 5101 naar lenka aapnes.
      await page.goto('/produksjonsplan?butikknummer=5101&dato=2026-02-02')
      expect(await skallet(page)).toContain('5101')

      await page.goto('/produksjonsplan?butikknummer=5103&dato=2026-02-02')
      // Ikke etter et klikk, ikke etter en omlasting - med en gang.
      expect(await skallet(page)).toContain('5103')
      expect(await enigeOmStasjon(page)).toContain('5103')
    })

    test('S5 - ingen annen stasjon kan vises samtidig i toppstripen', async ({ page }) => {
      for (const sti of [
        '/produksjonsplan?dato=2026-02-02',
        '/produksjonsplan?butikknummer=5102&dato=2026-02-02',
        '/salg',
        '/svinn',
      ]) {
        await page.goto(sti)
        const velger = page.locator('.sq-stasjonskontekst select')
        if (await velger.count() === 0) continue

        const vist = await skallet(page)
        const nr = vist.match(/\d{4}/)?.[0]
        const iTopp = await numreITopp(page)

        // Staar det et butikknummer i toppstripen, skal det vaere DET
        // velgeren viser. Ett tall, ikke to.
        if (nr) {
          expect(iTopp, `Toppstripen viser ${iTopp.join(' og ')}, velgeren viser ${vist}`)
            .toEqual([nr])
        } else {
          expect(iTopp, `Velgeren summerer, men toppstripen navngir ${iTopp.join(' og ')}`)
            .toEqual([])
        }
      }
    })

    // DEN SOM FANGER FEILEN.
    //
    // /salg viser en «Per stasjon»-tabell naar velgeren staar paa «Alle
    // stasjoner», og hver rad lenker til `/salg?dato=...&stasjon=<id>`.
    // Et klikk der er en MYK navigering: komponenten remonteres ikke.
    test('S6 - myk navigering via ?stasjon= oppdaterer velgeren', async ({ page }) => {
      await page.goto('/salg')
      const velger = page.locator('.sq-stasjonskontekst select')
      await velger.selectOption({ label: 'Alle stasjoner' })
      await expect(velger).toHaveValue('alle')

      // Foerste stasjonslenke i «Per stasjon»-tabellen.
      const lenke = page.locator('a[href*="/salg?"][href*="stasjon="]').first()
      await expect(lenke).toBeVisible()
      const navn = (await lenke.innerText()).trim()
      await lenke.click()

      // INGEN reload her. Er velgeren ukontrollert, staar den paa
      // «alle» mens sida regner paa én stasjon - og det er nettopp den
      // tilstanden skjermbildet fra 2026-08-24 viste.
      await expect(velger, 'Velgeren ble staaende mens sida byttet stasjon')
        .not.toHaveValue('alle', { timeout: 15_000 })
      expect(await skallet(page)).toContain(navn.match(/\d{4}/)?.[0] ?? navn)

      // Og ingen andre stasjoner i toppstripen samtidig.
      const nr = (await skallet(page)).match(/\d{4}/)?.[0]
      expect(await numreITopp(page)).toEqual([nr])
    })
  })

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
