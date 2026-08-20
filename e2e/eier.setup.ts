import { test as oppsett, expect } from '@playwright/test'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import {
  EIER, HEMMELIGFIL, OKTFIL, REDAKTOR, REDAKTOR_HEMMELIGFIL, REDAKTOR_OKTFIL, totp,
} from './eier'

// =====================================================================
// Eieren rulles inn EN gang, for alt annet kjorer.
//
// HVORFOR DETTE MAATTE BLI ET EGET STEG. Fire spec-filer trenger eieren.
// Da hver av dem logget inn selv, kunne to arbeidere treffe
// innrulleringen samtidig og lage HVER SIN faktor. Hemmeligheten laa i
// en delt fil, men fila kan bare holde en av dem - og da faar den andre
// arbeideren en kode som ikke passer til faktoren sida utfordrer.
//
// Feilen saa ut som «feil engangskode», altsaa som noe galt med TOTP.
// Den var i stedet et kappløp om hvem som fikk rulle inn forst.
//
// Naa: ett oppsettsteg, en faktor, en hemmelighet - og en lagret okt de
// andre gjenbruker. Det er ogsaa raskere: fire filer slipper aa gjennom
// paalogging og steg-opp hver for seg.
//
// FORTSATT INGEN OMGAAELSE. Dette steget gjor noyaktig det et menneske
// gjor forste gang: logger inn, blir tvunget til /sikkerhet, ruller inn
// gjennom det ekte API-et og skriver inn koden. Det er selve beviset paa
// at flyten virker - og det kjorer for hver eneste testkjoring.
// =====================================================================

oppsett('eieren ruller inn to-faktor, en gang for alle', async ({ page }) => {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', EIER.epost)
  await page.fill('input[name="passord"]', EIER.passord)
  await page.click('button[type="submit"]')

  // Rollen krever MFA og har ingen faktor: appen tvinger innrullering.
  await expect(page, 'Eieren ble ikke tvunget til innrullering')
    .toHaveURL(/\/sikkerhet\?paakrevd=1/, { timeout: 30_000 })

  await page.getByRole('button', { name: 'Sett opp to-faktor' }).click()
  const hemmelig = (await page.locator('.mfa-hemmelig').innerText()).trim()
  expect(hemmelig.length, 'Ingen hemmelighet paa innrulleringssida').toBeGreaterThan(10)

  await page.getByLabel(/engangskoden/i).fill(totp(hemmelig))
  await page.getByRole('button', { name: 'Aktiver to-faktor' }).click()

  // Tvunget innrullering sender henne rett til /oversikt naar sesjonen
  // er aal2. Det er porten som slipper henne gjennom.
  await expect(page, 'Innrulleringen slapp henne ikke gjennom porten')
    .toHaveURL(/\/oversikt/, { timeout: 30_000 })

  mkdirSync(dirname(HEMMELIGFIL), { recursive: true })
  writeFileSync(HEMMELIGFIL, hemmelig, 'utf8')
  await page.context().storageState({ path: OKTFIL })
})

/**
 * Samme flyt for plattform-redaktoren.
 *
 * Rollen tvinges gjennom TOTP paa noyaktig samme maate som eieren, og
 * hun rulles inn paa noyaktig samme maate: ingen seedet faktor, ingen
 * omgaaelse. To identiteter, to okter, og ingen av dem laaner den
 * andres.
 */
oppsett('plattform-redaktoren ruller inn to-faktor', async ({ page }) => {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', REDAKTOR.epost)
  await page.fill('input[name="passord"]', REDAKTOR.passord)
  await page.click('button[type="submit"]')

  await expect(page, 'Redaktoren ble ikke tvunget til innrullering')
    .toHaveURL(/\/sikkerhet\?paakrevd=1/, { timeout: 30_000 })

  await page.getByRole('button', { name: 'Sett opp to-faktor' }).click()
  const hemmelig = (await page.locator('.mfa-hemmelig').innerText()).trim()
  expect(hemmelig.length, 'Ingen hemmelighet paa innrulleringssida').toBeGreaterThan(10)

  await page.getByLabel(/engangskoden/i).fill(totp(hemmelig))
  await page.getByRole('button', { name: 'Aktiver to-faktor' }).click()

  await expect(page, 'Innrulleringen slapp henne ikke gjennom porten')
    .toHaveURL(/\/oversikt|\/plattform/, { timeout: 30_000 })

  mkdirSync(dirname(REDAKTOR_HEMMELIGFIL), { recursive: true })
  writeFileSync(REDAKTOR_HEMMELIGFIL, hemmelig, 'utf8')
  await page.context().storageState({ path: REDAKTOR_OKTFIL })
})
