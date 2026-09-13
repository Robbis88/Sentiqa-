import { expect, test } from '@playwright/test'
import { OKTFIL } from './eier'

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
//   Underby  juli  bekreftelse + usikker enkeltmåling
//   Grenseby juli  tiltak + retning tilgjengelig
//   Underby  juni  blokkert, med årsak og måned
//
// ---------------------------------------------------------------------
// `toContainText`, IKKE `innerText`
//
// `innerText` gir bare rendret tekst og kan ikke skille «finnes ikke»
// fra «er skjult». En negativ påstand hører til `textContent`. Se
// AGENTS.md — det har flaket her før.

// =====================================================================
// ØKTA. Uten denne linja kjører fila UTLOGGET.
//
// Prosjektet `chromium` avhenger av `oppsett`, som logger inn eieren og
// lagrer økta i `OKTFIL` — men avhengigheten kjører bare steget, den
// deler ikke økta. Hver spec-fil må be om den selv.
//
// Glemte man den, ble hver `goto` sendt til /logg-inn og HVER påstand
// feilet med «element(s) not found». Det ser ut som en feil i sida.
// =====================================================================
test.use({ storageState: OKTFIL })

const kort = (side: import('@playwright/test').Page, stasjon: string) =>
  side.locator('.sq-plankort').filter({ hasText: stasjon }).first()

test.beforeEach(async ({ page }) => {
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
})

test('Underby juli: bekreftelse med alle tallene', async ({ page }) => {
  const k = kort(page, 'Underby').filter({ hasText: 'Synlig matkast' })
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

test('Underby juli: uforklart matavvik er usikkert, ikke en manko', async ({ page }) => {
  const blokk = kort(page, 'Underby')
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

test('Grenseby juli: tiltak med budsjettavviket som forklaring', async ({ page }) => {
  const blokk = kort(page, 'Grenseby')
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

test('Grenseby juli: retning med PERIODEN i setningen', async ({ page }) => {
  const blokk = kort(page, 'Grenseby')
    .locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('retning tilgjengelig')
  await expect(blokk).toContainText('+3 815 kr')
  await expect(blokk).toContainText('de siste 3 månedene')
  // «Økt» i et positivt uforklart avvik betyr VERRE.
  await expect(blokk).toContainText('har økt')
})

test('en blokkert analyse forsvinner IKKE', async ({ page }) => {
  // Juni på Underby. Før P2 falt matkast bare ut av punktene, og kortet
  // så komplett ut — da tror den som leser at alt er i orden.
  const k = page.locator('.sq-plankort').filter({ hasText: 'Underby' }).nth(1)
  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('ikke beregnet')
  await expect(blokk).toContainText('Datagrunnlag mangler')
  await expect(blokk).toContainText('ikke avstemt')
  await expect(blokk).toContainText('Gjelder måneden 2026-04-01')

  const u = k.locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(u).toContainText('Matgruppen ble ikke funnet')
  await expect(u).toContainText('Gjelder måneden 2026-04-01')

  // SAMME KORT BÆRER EN PLAN FRA FØR `0216`: `rangering` er null.
  // Sida skrev før `?? { mulig: true, kandidater: [] }`, og da sto det
  // «Ingen av løftestengene peker feil vei denne måneden» på en plan
  // ingen har målt. Vi vet ikke hva den gamle motoren gjorde.
  await expect(k).toContainText('Rangering er ikke tilgjengelig')
  await expect(k).not.toContainText('Ingen av løftestengene peker feil vei')
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
    const blokker = kort(page, 'Underby').locator('.sq-analyse')
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

// =====================================================================
// Å BYGGE MÅNEDENS UTKAST PÅ NYTT — DEN POSITIVE PRODUKSJONSVEIEN
// =====================================================================
//
// Knappen finnes fordi den eneste veien til et nytt utkast var å kjøre
// en regnskapsfil om igjen — og det skriver `regnskapslinjer`,
// `bilagssum`, `bp_linje` og provenienstabellene på veien.
//
// Seedet har minste gyldige regnskapsgrunnlag for juli 2026 på ALLE tre
// stasjonene i Analysekjeden, så juli er en komplett datamåned. Da
// vises knappen, og hele kjeden kan måles:
//
//   komplett grunnlag -> knappen vises -> eieren bekrefter ->
//   serverhandlingen kjører -> juliutkast bygges -> snapshot lagres ->
//   fredede rader står urørt
//
// SEEDETS JULI-TILSTAND:
//   Underby  5101   utkast   skal SKRIVES
//   Grenseby 5102   utkast   skal SKRIVES
//   Overby   5103   AVVIST   skal stå urørt og NAVNGIS
//
// Og utenfor juli:
//   Underby  juni   utkast   annen måned — skal ikke røres
//   Grenseby mai    sluppet  avgjort — skal ikke røres
// =====================================================================

/** Kortet for én stasjon i én måned, uansett hvilken seksjon det står i. */
const plankort = (side: import('@playwright/test').Page, stasjon: string, mnd: string) =>
  side.locator('.sq-plankort').filter({ hasText: stasjon }).filter({ hasText: mnd })

/** Alt som skal stå urørt, avlest før og etter. */
async function uroert(side: import('@playwright/test').Page) {
  const juni = await plankort(side, 'Underby', 'juni').first().textContent()
  await side.goto('/min-plan')
  const mai = await side.locator('.sq-plankort').first().textContent()
  await side.goto('/maanedsplan')
  return { juni, mai }
}

test.describe('bygg på nytt', () => {
  test('knappen sier hvilken måned, hvor mange stasjoner, og hva som IKKE skjer',
    async ({ page }) => {
      await page.goto('/maanedsplan')
      const seksjon = page.locator('section').filter({ hasText: 'Bygg juli 2026 på nytt' })
      await expect(seksjon).toBeVisible()

      // FORVENTNINGEN FRA DATAGRUNNLAGET, ikke antall planrader.
      await expect(seksjon).toContainText('Grunnlaget forventer 3 stasjoner')

      // Forklaringen må si hva som IKKE skjer. «Bygg på nytt» alene
      // leses som «kjør importen om igjen».
      await expect(seksjon).toContainText('Ingen fil lastes opp')
      await expect(seksjon).toContainText('ingen import kjøres')
      await expect(seksjon).toContainText('Bare utkast skrives om')
    })

  test('den kjører ALDRI av seg selv', async ({ page }) => {
    // En side som skriver når den åpnes er en side ingen kan stole på.
    await page.goto('/maanedsplan')
    await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
    await page.reload()
    await expect(page.locator('.sq-plankort').first()).toBeVisible()
    await expect(page.locator('body')).not.toContainText('Bygget')
  })

  test('spørsmålet navngir måneden og begge tallene', async ({ page }) => {
    await page.goto('/maanedsplan')
    let tekst = ''
    page.on('dialog', async (d) => { tekst = d.message(); await d.dismiss() })
    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await expect.poll(() => tekst).toContain('juli 2026')
    expect(tekst).toContain('Grunnlaget forventer 3 stasjoner')
    expect(tekst).toContain('Ingen regnskapsdata')
    expect(tekst).toContain('Sluppet, sendt og avvist står urørt')
  })

  test('avbryt betyr avbryt', async ({ page }) => {
    // `window.confirm` uten `preventDefault` kjører handlingen uansett
    // hva man svarer. Det har skjedd i dette huset før.
    await page.goto('/maanedsplan')
    page.on('dialog', (d) => d.dismiss())
    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await page.waitForTimeout(500)
    await expect(page.locator('body')).not.toContainText('Bygget')
  })

  // ===================================================================
  // DEN POSITIVE VEIEN, HELE KJEDEN
  // ===================================================================
  test('bygger juli, låser den avviste, og rører ingen annen måned',
    async ({ page }) => {
      await page.goto('/maanedsplan')
      const foer = await uroert(page)

      page.on('dialog', (d) => d.accept())
      await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()

      // KVITTERINGEN: to skrevet, den avviste NAVNGITT.
      const kvittering = page.locator('body')
      await expect(kvittering).toContainText('Bygget 2 utkast for 2026-07',
        { timeout: 20_000 })
      await expect(kvittering).toContainText('Overby')
      await expect(kvittering).toContainText('allerede avgjort')

      await page.reload()

      // SNAPSHOTET ER SKREVET. Grunnlaget har ingen svinnrader og intet
      // kastbudsjett, så nipunktsporten blokkerer — og et BLOKKERT
      // snapshot er et skrevet snapshot. Sto det «Ikke beregnet», var
      // kolonnen fortsatt null.
      for (const st of ['Underby', 'Grenseby']) {
        const k = plankort(page, st, 'juli').first()
        await expect(k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' }))
          .toContainText('Datagrunnlag mangler')
      }

      // DEN AVVISTE STÅR URØRT — også innholdet.
      const overby = plankort(page, 'Overby', 'juli').first()
      await expect(overby).toContainText('Resultatet i juli er 10 000 kroner')

      // INGEN ANNEN MÅNED FLYTTET SEG.
      const etter = await uroert(page)
      expect(etter.juni, 'juni-kortet endret seg').toBe(foer.juni)
      expect(etter.mai, 'den sluppede mai-planen endret seg').toBe(foer.mai)
    })

  test('andre kjøring gir ingen duplikater og samme innhold', async ({ page }) => {
    await page.goto('/maanedsplan')
    page.on('dialog', (d) => d.accept())

    const antall = async () => page.locator('.sq-plankort').count()
    const juliTekst = async () =>
      (await plankort(page, 'Underby', 'juli').first().textContent()) ?? ''

    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await expect(page.locator('body')).toContainText('Bygget 2 utkast', { timeout: 20_000 })
    await page.reload()
    const a = { n: await antall(), t: await juliTekst() }

    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await expect(page.locator('body')).toContainText('Bygget 2 utkast', { timeout: 20_000 })
    await page.reload()
    const b = { n: await antall(), t: await juliTekst() }

    // FEM PLANER, IKKE TI. Kolliderer ikke upserten på
    // (stasjon_id, maaned), ville andre kjøring lagt til nye rader.
    expect(b.n).toBe(a.n)
    // Og innholdet er det samme. `beregnetTid` og `oppdatert_tid` står
    // ikke på skjermen, så kortteksten skal være identisk.
    expect(b.t).toBe(a.t)
  })

  test('butikksjefens flate har ingen byggeknapp', async ({ page }) => {
    // NEGATIV TILSTAND PÅ EN ANNEN AKSE: mottakeren skal aldri kunne
    // bygge planen sin på nytt. `textContent` — en negativ påstand på
    // `innerText` ville bestått mens knappen var skjult.
    await page.goto('/min-plan')
    await expect(page.locator('body')).not.toContainText('på nytt')
    await expect(page.getByRole('button', { name: /Bygg/ })).toHaveCount(0)
  })
})
