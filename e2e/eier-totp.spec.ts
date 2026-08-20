import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { loggInnEier } from './eier'
// =====================================================================
// PORT 0 for bolge 3: eieren, gjennom den ekte to-faktorflyten.
//
// HVORFOR DETTE MAATTE TIL. `retailer_admin` og `plattform_redaktor`
// tvinges gjennom TOTP (src/lib/auth/mfa.ts). TOTP var slaatt av i den
// lokale Supabase-en, saa de to rollene kunne ikke logge inn i CI i det
// hele tatt - og eiergrenene sto uten dekning gjennom hele redesignet,
// mens testene hoppet over dem med en begrunnelse som saa fornuftig ut.
//
// INGEN OMGAAELSE. Ingen faktor er seedet, ingen «hvis test»-gren
// finnes, og TOTP er skrudd PAA i testmiljoet - ikke av. Testen gjor
// noyaktig det et menneske gjor: logger inn, blir tvunget til
// innrullering, leser hemmeligheten fra manuell-inntastingsfeltet, og
// regner ut engangskoden.
//
// Koden regnes her fordi den maa regnes ET sted. RFC 6238 er tretti
// linjer; alternativet var en pakke til i treet for aa gjore det samme.
// =====================================================================

// SERIELT MED VILJE. Faktoren er delt tilstand i basen: to arbeidere som
// ruller inn samtidig ville laget hver sin, og den ene ville faatt en
// kode som ikke passer til den andres faktor.
test.describe.configure({ mode: 'serial' })

test.describe('PORT 0 - eieren gjennom ekte TOTP', () => {
  test('1-3: eier logger inn, fullforer TOTP og faar riktig rolle', async ({ page }) => {
    await loggInnEier(page)

    await page.goto('/oversikt')
    // Rollemerket i toppstripen er sidas eget svar paa «hvem er jeg».
    await expect(page.locator('.rolle-pip')).toContainText(/eier|admin/i)
  })

  test('4: eier ser sin egen kjede, og bare den', async ({ page }) => {
    await loggInnEier(page)
    await page.goto('/stasjoner')

    const tekst = await page.locator('body').innerText()
    // Analysekjedens tre stasjoner.
    expect(tekst).toContain('5101')
    // Testkjedens stasjoner hoerer til en annen kjede. Ser hun dem, er
    // det ikke en testfeil - det er RLS som lekker mellom kunder.
    expect(tekst, 'En annen kjedes stasjon er synlig').not.toContain('4177')
    expect(tekst).not.toContain('Testby')
  })

  test('5: butikksjefen faar ikke eierens handlinger', async ({ page }) => {
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'analyse@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-analyse-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    // /dekning og /analyse er eierens. Butikksjefen skal avvises.
    for (const sti of ['/dekning', '/analyse']) {
      await page.goto(sti)
      await expect(page.locator('body'), sti).toContainText(/ikke tilgang|Kun eier|eier/i)
    }
  })

  test('6: nettbrettet naar ikke eierflatene', async ({ page }) => {
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })

    for (const sti of ['/dekning', '/analyse', '/stasjoner']) {
      await page.goto(sti)
      // Hver side sier det med sine egne ord - «er en eier-oversikt»,
      // «Kun eier», «ikke tilgang». Det som betyr noe er at ingen av dem
      // slipper nettbrettet inn i innholdet.
      await expect(page.locator('body'), sti).toContainText(
        /ikke tilgang|Kun eier|eier-oversikt|administreres av|logg inn/i)
    }
  })

  test('7: axe paa en eiergren med ekte data', async ({ page }) => {
    await loggInnEier(page)
    await page.goto('/dekning')
    await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)

    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})

