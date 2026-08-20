import { test, expect, type Page } from '@playwright/test'
import { createHmac } from 'node:crypto'
import AxeBuilder from '@axe-core/playwright'

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

const EIER = { epost: 'eier@test.sentiqa.no', passord: 'test-eier-2026' }

/** Base32 (RFC 4648) → bytes. Supabase leverer hemmeligheten slik. */
function fraBase32(s: string): Buffer {
  const ALFABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  let bits = ''
  for (const tegn of s.replace(/=+$/, '').toUpperCase()) {
    const i = ALFABET.indexOf(tegn)
    if (i === -1) continue
    bits += i.toString(2).padStart(5, '0')
  }
  const ut: number[] = []
  for (let i = 0; i + 8 <= bits.length; i += 8) ut.push(parseInt(bits.slice(i, i + 8), 2))
  return Buffer.from(ut)
}

/** RFC 6238: seks siffer, tretti sekunders vindu, HMAC-SHA1. */
function totp(hemmelig: string, naa = Date.now()): string {
  const steg = Math.floor(naa / 1000 / 30)
  const tid = Buffer.alloc(8)
  tid.writeUInt32BE(Math.floor(steg / 2 ** 32), 0)
  tid.writeUInt32BE(steg >>> 0, 4)
  const hmac = createHmac('sha1', fraBase32(hemmelig)).update(tid).digest()
  const off = hmac[hmac.length - 1] & 0x0f
  const kode = ((hmac[off] & 0x7f) << 24 | hmac[off + 1] << 16
    | hmac[off + 2] << 8 | hmac[off + 3]) % 1_000_000
  return String(kode).padStart(6, '0')
}

/**
 * Logger inn eieren og fullforer to-faktor.
 *
 * Returnerer hemmeligheten, saa senere steg i samme test kan lage nye
 * koder uten aa rulle inn paa nytt.
 */
async function loggInnEier(page: Page): Promise<string> {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', EIER.epost)
  await page.fill('input[name="passord"]', EIER.passord)
  await page.click('button[type="submit"]')

  // Rollen krever MFA og har ingen faktor: appen tvinger innrullering.
  await expect(page).toHaveURL(/\/sikkerhet\?paakrevd=1/, { timeout: 20_000 })

  await page.getByRole('button', { name: 'Sett opp to-faktor' }).click()
  const hemmelig = (await page.locator('.mfa-hemmelig').innerText()).trim()
  expect(hemmelig.length, 'Ingen hemmelighet paa innrulleringssida').toBeGreaterThan(10)

  await page.getByLabel(/engangskoden/i).fill(totp(hemmelig))
  await page.getByRole('button', { name: 'Aktiver to-faktor' }).click()

  // Verifisert faktor → sesjonen er aal2 og eieren slipper inn.
  await expect(page.locator('.mfa-paa')).toContainText('To-faktor er aktivert', {
    timeout: 20_000,
  })
  return hemmelig
}

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
      await expect(page.locator('body'), sti).toContainText(
        /ikke tilgang|Kun eier|administreres av|logg inn/i)
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

export { loggInnEier, totp }
