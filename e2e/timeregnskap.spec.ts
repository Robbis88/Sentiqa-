import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// /timeregnskap — «har vi råd til timene vi bruker?»
//
// HVA DENNE KAN OG IKKE KAN BEVISE. CI-basen har ingen
// `regnskapslinjer` og ingen `bemanning_maned`, så sida viser
// tomtilstanden. Det som KAN måles er rolle, tomtilstand,
// tilgjengelighet og kontrast — og kontrast er det eneste stedet det
// kan måles i det hele tatt, siden jsdom ikke har layout.
//
// Selve regnestykket er bevist i `supabase/tests/timeregnskap.sql` med
// Roberts egne tall, og lederdekningen fra faste vakter i samme fil.
//
// ROLLEN ER DET VIKTIGSTE HER. Tallet sier hvor mange timer en stasjon
// har brukt uten dekning i brutto, målt mot en ramme butikksjefen ikke
// skal se — `bemanning_budsjett` er retailer_admin-only med vilje
// (0082: «IKKE synlig for butikksjef»).
//
// OPPSETTSIDA ER BORTE. Lederdekningen leses nå fra
// `bemanning_fast_vakt.timelonnet`, som vedlikeholdes på /bemanning.
// Ett sted, ikke to.
// =====================================================================

test.describe('timeregnskap som eier', () => {
  test.use({ storageState: OKTFIL })

  test('sida svarer, og sier hvorfor den er tom', async ({ page }) => {
    const svar = await page.goto('/timeregnskap')
    expect(svar?.status(), `/timeregnskap svarte ${svar?.status()}`).toBeLessThan(400)
    await expect(page.locator('body')).toContainText(/timeregnskap|timene/i)
  })

  test('den slettede oppsettsida er faktisk borte', async ({ page }) => {
    // KANARIFUGL FOR EN HALV SLETTING. Ble ruta liggende igjen, ville
    // den fortsatt skrevet til en tabell som ikke finnes — og feilet
    // først når noen forsøkte å lagre.
    const svar = await page.goto('/timeregnskap/oppsett')
    expect(svar?.status(), 'oppsettsida skal være slettet').toBe(404)
  })

  test('ingen axe-brudd', async ({ page }) => {
    await page.goto('/timeregnskap')
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})

test.describe('timeregnskap for andre roller', () => {
  test('butikksjefen slipper ikke inn', async ({ page }) => {
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'butikksjef@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-butikksjef-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })

    await page.goto('/timeregnskap')
    await expect(page.locator('body')).toContainText(/Kun eier|ikke tilgang/i)
  })
})
