import { expect, test } from '@playwright/test'

// =====================================================================
// Mat- og svinnanalysen på månedsplanen — den faktiske flaten.
// =====================================================================
//
// Enhetstestene måler visningsobjektet. Denne måler at tallene faktisk
// står på skjermen, at en blokkert analyse IKKE forsvinner, og at
// kortet holder på telefonbredde.
//
// Seedet har tre utkast, ett for hver tilstand som må tåles:
//
//   Testby  juli  bekreftelse + usikker enkeltmåling
//   Testvik juli  tiltak + retning tilgjengelig
//   Testby  juni  blokkert, med årsak og måned
//
// ---------------------------------------------------------------------
// `toContainText`, IKKE `innerText`
//
// `innerText` gir bare rendret tekst og kan ikke skille «finnes ikke»
// fra «er skjult». En negativ påstand hører til `textContent`. Se
// AGENTS.md — det har flaket her før.

const kort = (side: import('@playwright/test').Page, stasjon: string) =>
  side.locator('.sq-plankort').filter({ hasText: stasjon }).first()

test.beforeEach(async ({ page }) => {
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
})

test('Testby juli: bekreftelse med alle tallene', async ({ page }) => {
  const k = kort(page, 'Testby').filter({ hasText: 'Synlig matkast' })
  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()

  // Merket sier dommen.
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('bekreftelse')

  // De seks spørsmålene, som tall på skjermen.
  await expect(blokk).toContainText('838 292')      // hvor ligger vi
  await expect(blokk).toContainText('32 019')       // synlig kast
  await expect(blokk).toContainText('3,82 %')       // faktisk
  await expect(blokk).toContainText('6,23 %')       // budsjett
  await expect(blokk).toContainText('52 245')       // justert budsjett
  await expect(blokk).toContainText('−2,41 pp')     // avvik
  await expect(blokk).toContainText('20 226')       // avvik i kroner
  await expect(blokk).toContainText('bedre enn budsjett')
  await expect(blokk).toContainText('Kastprosenten faller')
  await expect(blokk).toContainText('Under kastbudsjettet')
})

test('Testby juli: uforklart matavvik er usikkert, ikke en manko', async ({ page }) => {
  const blokk = kort(page, 'Testby')
    .locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(blokk).toBeVisible()

  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('usikker måling')
  await expect(blokk).toContainText('+31 902 kr')
  await expect(blokk).toContainText('Usikker enkeltmåling')
  await expect(blokk).toContainText('telling')
  await expect(blokk).toContainText('periodisering')
  await expect(blokk).toContainText('fakturaflyt')
  await expect(blokk).toContainText('teoretisk bruttofortjeneste minus faktisk')
  await expect(blokk).toContainText('overproduksjon')

  // ORDENE SOM IKKE SKAL STÅ DER. `textContent` gjennom toContainText —
  // en negativ påstand på `innerText` ville bestått mens blokken var
  // skjult.
  await expect(blokk).not.toContainText('manko')
  await expect(blokk).not.toContainText('gevinst')
})

test('Testvik juli: tiltak med budsjettavviket som forklaring', async ({ page }) => {
  const blokk = kort(page, 'Testvik')
    .locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('tiltak')
  await expect(blokk).toContainText('19,33 %')
  await expect(blokk).toContainText('13,59 %')
  await expect(blokk).toContainText('+5,74 pp')
  await expect(blokk).toContainText('over budsjett')
  await expect(blokk).toContainText('ingen stabil forbedring')
  // Ikke en påstand dataene ikke bærer.
  await expect(blokk).not.toContainText('feil vei')
})

test('Testvik juli: retning med PERIODEN i setningen', async ({ page }) => {
  const blokk = kort(page, 'Testvik')
    .locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('retning tilgjengelig')
  await expect(blokk).toContainText('+3 815 kr')
  await expect(blokk).toContainText('de siste 3 månedene')
  // «Økt» i et positivt uforklart avvik betyr VERRE.
  await expect(blokk).toContainText('har økt')
})

test('en blokkert analyse forsvinner IKKE', async ({ page }) => {
  // Juni på Testby. Før P2 falt matkast bare ut av punktene, og kortet
  // så komplett ut — da tror den som leser at alt er i orden.
  const k = page.locator('.sq-plankort').filter({ hasText: 'Testby' }).nth(1)
  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('ikke beregnet')
  await expect(blokk).toContainText('Datagrunnlag mangler')
  await expect(blokk).toContainText('ikke avstemt')
  await expect(blokk).toContainText('Gjelder måneden 2026-04-01')

  const u = k.locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(u).toContainText('Matgruppen ble ikke funnet')
  await expect(u).toContainText('Gjelder måneden 2026-04-01')
})

test('norsk tegnsett står riktig på skjermen', async ({ page }) => {
  const side = page.locator('.sq-plankort-liste').first()
  await expect(side).toContainText('måneder')
  await expect(side).toContainText('Uforklart matavvik')
  // Ingen mojibake fra feil koding.
  await expect(side).not.toContainText('Ã')
})

// =====================================================================
// MOBIL
//
// Prosjektet kjører bare Desktop Chrome. Bredden settes derfor her —
// det er layouten som skal måles, ikke en ny nettlesermotor.
// =====================================================================
test.describe('telefonbredde', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('analyseblokkene stables og teksten er hel', async ({ page }) => {
    await page.goto('/maanedsplan')
    const blokker = kort(page, 'Testby').locator('.sq-analyse')
    await expect(blokker.first()).toBeVisible()

    // ÉN KOLONNE. To blokker ved siden av hverandre på 390 px ville
    // klippet tallene.
    const a = await blokker.nth(0).boundingBox()
    const b = await blokker.nth(1).boundingBox()
    expect(a && b).toBeTruthy()
    expect(b!.y).toBeGreaterThan(a!.y + a!.height - 4)

    // Tallene er fortsatt hele.
    await expect(blokker.nth(0)).toContainText('838 292')
    await expect(blokker.nth(0)).toContainText('−2,41 pp')
  })

  test('sida ruller ikke sideveis', async ({ page }) => {
    await page.goto('/maanedsplan')
    await expect(page.locator('.sq-plankort').first()).toBeVisible()
    const bredde = await page.evaluate(
      () => [document.documentElement.scrollWidth, window.innerWidth],
    )
    // En analyseblokk som er bredere enn skjermen gir en side som må
    // dras sidelengs — det er en feil, ikke en detalj.
    expect(bredde[0]).toBeLessThanOrEqual(bredde[1] + 1)
  })
})
