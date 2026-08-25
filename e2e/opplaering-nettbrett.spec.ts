import { test, expect, type Page } from '@playwright/test'
import { treffomraadeneHolder } from './hjelp-treffomraade'

// =====================================================================
// Opplæringen skal nå fram til stasjonen der den skjer.
//
// Butikksjefen planlegger «i dag, 16–23» på kontoret. Den dagen står
// sjekklista på stasjonens nettbrett av seg selv — ingen publisering,
// ingen kopiering av lister. Skift-kalenderen er utløseren, og den har
// ligget i basen siden 0042 uten at noe leste den.
//
// FIXTUREN BRUKER `current_date`, ikke en fast dato. En fixture på
// 2026-08-29 ville vært usynlig alle andre dager, og testen ville
// bestått fordi den ikke fant noe — ikke fordi det ikke var noe galt.
//
// Testby (4177) i Testkjeden, tre oppgaver, én av dem alt gjort:
//
//   Kasse · Kassaoppgjoer         ugjort
//   Kasse · Aldersgrense tobakk   ugjort
//   Bake  · Steke boller          GJORT
//
// Er alle tre ugjorte, ville en visning som aldri merker noe som ferdig
// bestått like godt. To tilstander i fixturen er det som gjør at testen
// kan se forskjell.
// =====================================================================

const NETTBRETT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }
const SJEF = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }

async function loggInn(page: Page, b: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', b.epost)
  await page.fill('input[name="passord"]', b.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

const kortet = (page: Page) => page.locator('section.topl')

// SERIELT, OG LESING FOER SKRIVING. Testene deler én database, saa en
// hake satt i test C endrer tallet test A leser. Uten dette ville de
// bestaatt eller feilet etter hvilken rekkefoelge Playwright valgte -
// og en test som svarer forskjellig fra kjoering til kjoering er ikke
// en test. Absolutte tellinger staar derfor bare foer foerste hake.
test.describe.configure({ mode: 'serial' })

test.describe('opplæring på nettbrettet', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, NETTBRETT)
    await page.goto('/oversikt')
  })

  test('A - kortet står der, med navn, tidsrom og fremdrift', async ({ page }) => {
    const k = kortet(page)
    await expect(k).toHaveCount(1)
    await expect(k).toContainText('Nora Nyansatt')

    // TIDENE FORTELLER. De styrer ikke om lista vises - man haker av
    // etter at noe er lært bort, og en liste som forsvinner 23:00
    // forsvinner midt i jobben.
    await expect(k).toContainText('16:00–23:00')

    // Én av tre er gjort i fixturen.
    await expect(k).toContainText('1/3')
    await expect(k.locator('.topl-pst')).toHaveText('33 %')
  })

  test('B - gjort er ikke en knapp', async ({ page }) => {
    // `opp2_utfort_del` er leder-only: nettbrettet kan sette haken, men
    // ikke ta den bort. En knapp som ser ut som den virker og blir
    // avvist av databasen er verre enn ingen knapp.
    const k = kortet(page)
    const gjort = k.locator('.topl-rad.topl-gjort')
    await expect(gjort).toHaveCount(1)
    await expect(gjort).toContainText('Steke boller')
    await expect(gjort.locator('button')).toHaveCount(0)

    await expect(k.locator('.topl-rad button')).toHaveCount(2)
    await expect(k).toContainText('En hake kan bare tas bort av butikksjefen.')
  })

  test('C - en hake settes, og den blir stående', async ({ page }) => {
    const k = kortet(page)
    await k.getByRole('button', { name: 'Kassaoppgjoer' }).click()

    // FEILER SYNLIG. Haken settes først når serveren har svart ja - en
    // oppgave som ser gjort ut uten å være det, oppdages aldri.
    await expect(k.locator('.topl-rad.topl-gjort')).toHaveCount(2)
    await expect(k).toContainText('2/3')

    // ...og den overlever en ny lasting. Uten dette ville en hake som
    // bare finnes i nettleseren bestått testen.
    await page.reload()
    await expect(kortet(page)).toContainText('2/3')
    // PEK PAA DEN ENE RADEN. `.topl-gjort` treffer naa to elementer, og
    // en `toContainText` over flere er ikke bare strict-mode-brudd - den
    // ville ogsaa bestaatt om FEIL rad var haket av.
    await expect(kortet(page).locator('.topl-rad.topl-gjort')
      .filter({ hasText: 'Kassaoppgjoer' })).toHaveCount(1)
  })

  test('D - oppgavene står gruppert på kategori', async ({ page }) => {
    const k = kortet(page)
    await expect(k.locator('.topl-kategori')).toHaveText(['Kasse', 'Bake'])
  })

  test('E - treffområdene tåler en benk, ikke en mus', async ({ page }) => {
    // Hjelperen skiller «for lav» fra «ikke lagt ut» og har sin egen
    // kanarifugl. Se e2e/hjelp-treffomraade.ts for hvorfor de to ikke
    // kan slaas sammen til ett tall.
    await treffomraadeneHolder(page, '.topl-rad button')
  })
})

test.describe('opplæring hos butikksjefen', () => {
  test('vaktplanen viser klokkeslettene som ble planlagt', async ({ page }) => {
    await loggInn(page, SJEF)
    await page.goto('/opplaring?periode=0ccc0000-0000-4000-8000-000000000001')
    await expect(page.locator('body')).toContainText('Nora Nyansatt')
    // Klokkeslettene butikksjefen la inn staar i vaktplanen.
    await expect(page.locator('body')).toContainText('16:00–23:00')
  })

  test('nettbrettets hake er den samme raden butikksjefen ser', async ({ page }) => {
    // Ingen synk, ingen duplikater: begge skriver til samme rad i
    // `opplaering_utfort` med upsert på (periode_id, oppgave_id).
    await loggInn(page, NETTBRETT)
    await page.goto('/oversikt')
    await kortet(page).getByRole('button', { name: 'Aldersgrense tobakk' }).click()
    // INGEN ABSOLUTT TELLING HER. Test C har alt satt en hake, saa
    // totalen avhenger av rekkefoelgen. Det denne testen maaler er at
    // NETTBRETTETS hake naar butikksjefen - ikke hvor mange det er.
    await expect(kortet(page).locator('.topl-rad.topl-gjort')
      .filter({ hasText: 'Aldersgrense tobakk' })).toHaveCount(1)

    await page.context().clearCookies()
    await loggInn(page, SJEF)
    await page.goto('/opplaring?periode=0ccc0000-0000-4000-8000-000000000001')

    // AT NAVNET STAAR DER BEVISER INGENTING - oppgavebiblioteket viser
    // alle tre uansett. Fremdriftstallet er det eneste som endrer seg
    // naar en hake naar fram: fixturen har 1, test C satte den andre,
    // og denne satte den tredje. Rekkefoelgen er fast fordi fila
    // kjoerer serielt.
    await expect(page.locator('.person-liste .sq-status').first()).toHaveText('3/3')
  })
})
