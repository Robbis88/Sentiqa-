import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// Port 0 til bolge 4: redigeringsrutenettet, pilotert paa /stasjoner.
//
// HVA SOM FAKTISK BLE BYGGET, og hvorfor det er saa lite: kartleggingen
// av de tre kandidatene viste at bare TO av dem er redigeringsrutenett,
// og at de to lagrer paa hver sin maate - /produksjonsplan i det du
// endrer, /stasjoner naar du trykker Lagre. Primitivet eier derfor bare
// FORMEN. Lagringen blir liggende i sida.
//
// Testene under maaler nettopp det: at formen er ny, og at ingenting av
// oppforselen er det.
//
// Eieren logger inn gjennom ekte TOTP (port 0, bolge 3). /stasjoner er
// hennes rute - butikksjefen skal aldri se den.
// =====================================================================

test.describe.configure({ mode: 'serial' })

test.describe('/stasjoner som redigeringsrutenett', () => {
  // Gjenbruker okta oppsettsteget lagret. Ingen ny innlogging, ingen ny
  // faktor - og dermed ingen risiko for at to arbeidere ruller inn hver
  // sin.
  test.use({ storageState: OKTFIL })
  test('radene og alle fire feltgruppene finnes', async ({ page }) => {
    await page.goto('/stasjoner')

    const rutenett = page.locator('.sq-rutenett')
    await expect(rutenett).toBeVisible()

    // Analysekjedens tre stasjoner.
    await expect(rutenett.locator('tbody tr')).toHaveCount(3)
    await expect(rutenett.locator('thead th')).toHaveText(
      ['Butikknr', 'Navn', 'Type', 'Svinnterskel', 'Værfølsomhet', 'Posisjon (vær)'])

    // FIRE UAVHENGIGE SKJEMAER PER RAD, som for. Slaas de sammen til
    // ett, er det en funksjonell endring - ikke en designendring.
    const rad = rutenett.locator('tbody tr').first()
    await expect(rad.locator('form')).toHaveCount(4)

    // Feltnavnene er kontrakten mot serverhandlingene.
    for (const navn of ['stasjonstype', 'stasjonstype_sekundaer', 'terskel',
      'vaerfolsomhet', 'breddegrad', 'lengdegrad']) {
      await expect(rad.locator(`[name="${navn}"]`), navn).toHaveCount(1)
    }
  })

  test('den skjulte nyttelasten bestaar - en per skjema', async ({ page }) => {
    await page.goto('/stasjoner')

    const rad = page.locator('.sq-rutenett tbody tr').first()
    const skjulte = rad.locator('input[type="hidden"][name="stasjon_id"]')
    await expect(skjulte, 'Hvert skjema maa fortsatt si HVILKEN stasjon det gjelder')
      .toHaveCount(4)
    // Alle fire peker paa samme stasjon.
    const verdier = await skjulte.evaluateAll((n) => [...new Set(n.map((e) => (e as HTMLInputElement).value))])
    expect(verdier).toHaveLength(1)
  })

  test('LAGRE-KNAPPENE ER SKILLBARE. Aatti like knapper var uleselige', async ({ page }) => {
    await page.goto('/stasjoner')

    // Fire per rad x tre rader. For het de alle bare «Lagre», og en
    // skjermleser leste dem identisk.
    await expect(page.getByRole('button', { name: /^Lagre type for/ })).toHaveCount(3)
    await expect(page.getByRole('button', { name: /^Lagre svinnterskel for/ })).toHaveCount(3)
    await expect(page.getByRole('button', { name: /^Lagre værfølsomhet for/ })).toHaveCount(3)
    await expect(page.getByRole('button', { name: /^Lagre posisjon for/ })).toHaveCount(3)
  })

  test('en gyldig endring lagres, og verdien staar etter omlasting', async ({ page }) => {
    // MAALER TO HANDLINGER, IKKE EN.
    //
    // Forste utgave maalte bare posisjonen, og feilet tre ganger paa rad
    // uten aa si HVA som var galt: verdien sto rett etter lagring (fordi
    // feltet er ukontrollert og beholdt det jeg nettopp skrev), og var
    // borte etter omlasting. Det beviser bare at noe ikke ble skrevet -
    // ikke hva.
    //
    // Naa proeves begge: en `select` gjennom `settStasjonstype`, og et
    // tallfelt gjennom `settPosisjon`. Feiler bare den ene, vet vi hvor
    // problemet ligger. Feiler begge, skriver ingen av handlingene, og
    // det er noe annet enn en felttype.
    await page.goto('/stasjoner')

    const rad = () => page.locator('.sq-rutenett tbody tr').first()
    const type = rad().locator('[name="stasjonstype"]')
    const foerType = await type.inputValue()
    const nyType = foerType === 'bydel' ? 'pendler' : 'bydel'

    await type.selectOption(nyType)
    await rad().getByRole('button', { name: /^Lagre type for/ }).click()
    await page.waitForLoadState('networkidle')
    await page.reload()
    expect(
      await rad().locator('[name="stasjonstype"]').inputValue(),
      'settStasjonstype skrev ikke - da skriver ingen av handlingene',
    ).toBe(nyType)

    // Posisjonen: samme rad, annen handling, annen felttype.
    const bredde = rad().locator('[name="breddegrad"]')
    const lengde = rad().locator('[name="lengdegrad"]')
    const foerB = await bredde.inputValue()
    const foerL = await lengde.inputValue()

    await bredde.fill('60.3913')
    await lengde.fill('5.3221')
    await rad().getByRole('button', { name: /^Lagre posisjon for/ }).click()
    await page.waitForLoadState('networkidle')
    await page.reload()
    expect(
      await rad().locator('[name="breddegrad"]').inputValue(),
      'settPosisjon skrev ikke, mens settStasjonstype gjorde det',
    ).toBe('60.3913')

    // Rydd opp - fixturen er delt.
    await rad().locator('[name="stasjonstype"]').selectOption(foerType)
    await rad().getByRole('button', { name: /^Lagre type for/ }).click()
    await page.waitForLoadState('networkidle')
    await rad().locator('[name="breddegrad"]').fill(foerB)
    await rad().locator('[name="lengdegrad"]').fill(foerL)
    await rad().getByRole('button', { name: /^Lagre posisjon for/ }).click()
  })

  test('INGEN ENDRING GIR INGEN ENDRING', async ({ page }) => {
    // Aa trykke Lagre uten aa roere noe skal la verdien staa. Det hoeres
    // selvsagt ut, og er nettopp derfor verdt aa maale: en
    // serverhandling som tolker tom streng som null ville nullet feltet.
    await page.goto('/stasjoner')

    const rad = page.locator('.sq-rutenett tbody tr').first()
    const foer = await rad.locator('[name="vaerfolsomhet"]').inputValue()
    // Skriver samme verdi tilbake - trygt, og det er nettopp poenget.
    await rad.getByRole('button', { name: /^Lagre værfølsomhet for/ }).click()

    await page.reload()
    await expect(page.locator('.sq-rutenett tbody tr').first().locator('[name="vaerfolsomhet"]'))
      .toHaveValue(foer)
  })

  test('rutenettet er ikke en stasjonsvelger', async ({ page }) => {
    // Raden administrerer EN stasjon. Den skal ikke bytte aktiv stasjon
    // i appskallet - det spoersmaalet bor i toppstripen (trinn 09).
    await page.goto('/stasjoner')

    const foer = await page.locator('.sq-stasjonskontekst select').inputValue()
    const rad = page.locator('.sq-rutenett tbody tr').last()
    await rad.locator('[name="terskel"]').click()

    await expect(page.locator('.sq-stasjonskontekst select')).toHaveValue(foer)
    await expect(page).not.toHaveURL(/stasjon=|butikknummer=/)
  })

  test('tastaturet kommer gjennom rutenettet', async ({ page }) => {
    await page.goto('/stasjoner')

    await page.locator('.sq-rutenett tbody tr').first().locator('[name="terskel"]').focus()
    const naadd: string[] = []
    for (let i = 0; i < 4; i++) {
      await page.keyboard.press('Tab')
      naadd.push(await page.evaluate(() => {
        const a = document.activeElement
        return a ? `${a.tagName.toLowerCase()}:${a.getAttribute('name') ?? a.textContent?.trim().slice(0, 12) ?? ''}` : ''
      }))
    }
    // Fra terskelfeltet skal man naa lagreknappen og videre inn i neste
    // gruppe - uten aa hoppe ut av raden.
    expect(naadd.some((t) => t.startsWith('button')), `Tabbet: ${naadd.join(', ')}`).toBe(true)
  })

  test('feil rolle faar ikke ny tilgang', async ({ page, context }) => {
    await context.clearCookies()
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'analyse@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-analyse-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    await page.goto('/stasjoner')
    await expect(page.locator('body')).toContainText(/ikke tilgang|Kun eier|eier/i)
    expect(await page.locator('.sq-rutenett').count(),
      'Butikksjefen fikk se redigeringsrutenettet').toBe(0)
  })

  test('ingen axe-brudd paa rutenettet', async ({ page }) => {
    await page.goto('/stasjoner')
    await expect(page.locator('.sq-rutenett')).toBeVisible()

    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('tettheten holder - rutenettet flyter ikke ut', async ({ page }) => {
    await page.goto('/stasjoner')

    for (const bredde of [1280, 1440]) {
      await page.setViewportSize({ width: bredde, height: 900 })
      await expect(page.locator('.sq-rutenett')).toBeVisible()
      const sol = await page.evaluate(() => ({
        scroll: document.documentElement.scrollWidth,
        klient: document.documentElement.clientWidth,
      }))
      expect(sol.scroll, `Vannrett rulling paa ${bredde}px`).toBeLessThanOrEqual(sol.klient + 1)
    }

    // Tre stasjoner skal fortsatt faa plass uten aa rulle vertikalt i
    // det uendelige. Maalet er tetthet, ikke luft.
    const hoyde = await page.locator('.sq-rutenett tbody tr').first()
      .evaluate((e) => e.getBoundingClientRect().height)
    expect(hoyde, 'Raden er blitt et kort').toBeLessThan(140)
  })
})
