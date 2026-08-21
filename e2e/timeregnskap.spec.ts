import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// /timeregnskap og /timeregnskap/oppsett
//
// HVA DENNE KAN OG IKKE KAN BEVISE. CI-basen har ingen `regnskapslinjer`
// og ingen `bemanning_maned`, så begge sidene viser tomtilstanden. Det
// som KAN måles er rolle, tomtilstand, tilgjengelighet og kontrast —
// og kontrast er det eneste stedet det kan måles i det hele tatt, siden
// jsdom ikke har layout.
//
// Selve regnestykket er bevist i `supabase/tests/timeregnskap.sql` med
// Roberts egne tall, og ordene i `src/lib/bemanning/lederdekning.test.ts`.
//
// ROLLEN ER DET VIKTIGSTE HER. Hakene på oppsettsiden UTVIDER
// stasjonens ramme. Kunne butikksjefen sette dem, kunne hun utvide sin
// egen — og det ville ikke sett ut som en feil, det ville sett ut som
// et godt tall.
// =====================================================================

test.describe('timeregnskap som eier', () => {
  test.use({ storageState: OKTFIL })

  test('begge sidene svarer, og sier hvorfor de er tomme', async ({ page }) => {
    const a = await page.goto('/timeregnskap')
    expect(a?.status(), `/timeregnskap svarte ${a?.status()}`).toBeLessThan(400)
    await expect(page.locator('body')).toContainText(/timeregnskap|timene/i)

    const b = await page.goto('/timeregnskap/oppsett')
    expect(b?.status(), `/timeregnskap/oppsett svarte ${b?.status()}`).toBeLessThan(400)
    await expect(page.locator('body')).toContainText(/butikksjef/i)
  })

  test('ingen axe-brudd på noen av dem', async ({ page }) => {
    for (const sti of ['/timeregnskap', '/timeregnskap/oppsett']) {
      await page.goto(sti)
      const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
      const funn = res.violations.flatMap((v) => v.nodes.map(
        (n) => `${sti} — ${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
      ))
      expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
    }
  })
})

test.describe('timeregnskap for andre roller', () => {
  test('butikksjefen slipper ikke inn i oppsettet', async ({ page }) => {
    // DEN VIKTIGSTE KONTROLLEN I FILA. Hakene utvider rammen stasjonen
    // måles mot. RLS-policyen på `bemanning_lederdekning` er den som
    // faktisk holder — denne beviser at portneren i siden er enig med
    // den, så avvisningen blir en setning og ikke en tom liste.
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'butikksjef@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-butikksjef-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })

    await page.goto('/timeregnskap/oppsett')
    await expect(page.locator('body')).toContainText(/Kun eier|ikke tilgang/i)

    await page.goto('/timeregnskap')
    await expect(page.locator('body')).toContainText(/Kun eier|ikke tilgang/i)
  })
})
