import { expect, test } from '@playwright/test'

async function loggInn(page: import('@playwright/test').Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', 'analyse@test.sentiqa.no')
  await page.fill('input[name="passord"]', 'test-analyse-2026')
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

test('mobilmenyen skjuler lukket innhold fra fokus og returnerer fokus ved lukking', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await loggInn(page)
  const meny = page.locator('.sidemeny')
  await expect(meny).toHaveAttribute('inert', '')
  const utloser = page.getByRole('button', { name: 'Åpne meny', exact: true })
  await utloser.click()
  await expect(meny).toHaveAttribute('role', 'dialog')
  await expect(page.locator('.hoved')).toHaveJSProperty('inert', true)
  const lukk = meny.getByRole('button', { name: 'Lukk meny', exact: true })
  await expect(lukk).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  expect(await meny.evaluate((node) => node.contains(document.activeElement))).toBe(true)
  await page.keyboard.press('Tab')
  await expect(lukk).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(meny).toHaveAttribute('inert', '')
  await expect(utloser).toBeFocused()
  await expect(page.locator('.hoved')).toHaveJSProperty('inert', false)
})

test('søket har forståelig navn på mobil og native dialog holder tastaturfokus', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await loggInn(page)
  const utloser = page.getByRole('button', { name: 'Spør Sentiqa eller finn noe', exact: true })
  await utloser.click()
  const dialog = page.getByRole('dialog', { name: 'Spør Sentiqa eller finn noe', exact: true })
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('textbox', { name: 'Spørsmål eller sidenavn' })).toBeFocused()
  expect(await dialog.evaluate((node) => node.matches(':modal'))).toBe(true)
  for (let i = 0; i < 15; i++) {
    await page.keyboard.press('Tab')
    expect(await dialog.evaluate((node) => node.contains(document.activeElement))).toBe(true)
  }
  await page.keyboard.press('Escape')
  await expect(dialog).toHaveCount(0)
  await expect(utloser).toBeFocused()
})
