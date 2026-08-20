import { expect, type Page } from '@playwright/test'
import { createHmac } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'

// =====================================================================
// Eieren i CI - delt hjelper.
//
// Bor i en .ts og ikke en .spec.ts med vilje: Playwright plukker opp
// spec-filer som testfiler, og en spec som importerer en annen spec ville
// kjort den andres tester en gang til.
//
// Hele begrunnelsen for aa gjore det slik - ingen seedet faktor, ingen
// bypass, ekte innrullering - staar i e2e/eier-totp.spec.ts.
// =====================================================================

export const EIER = { epost: 'eier@test.sentiqa.no', passord: 'test-eier-2026' }

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
export function totp(hemmelig: string, naa = Date.now()): string {
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
 * Hemmeligheten fra innrulleringen, delt mellom testene i fila.
 *
 * FORSTE KJORING AVSLORTE HVORFOR DEN MAA DELES: faktoren blir liggende
 * i basen etter forste test. De neste innloggingene moter derfor ikke
 * innrulleringen, men STEG-OPP - appen ber om en kode til en faktor som
 * allerede finnes. Uten hemmeligheten fra forste runde kan ingen av dem
 * svare.
 *
 * Derfor kjorer fila serielt: en arbeider, en faktor, en hemmelighet.
 */
/**
 * Hemmeligheten deles PAA DISK, ikke bare i modulminnet.
 *
 * To spec-filer bruker eieren, og Playwright kjorer dem i hver sin
 * arbeider med hvert sitt modulminne. Innrullerer den ene, moter den
 * andre steg-opp uten aa vite hemmeligheten - og da staar den fast paa
 * en kode den ikke kan regne ut.
 *
 * Fila ligger under test-results, som CI river sammen med resten.
 */
export const HEMMELIGFIL = join(process.cwd(), 'test-results', 'eier-totp.txt')

/**
 * Plattform-redaktoren - den andre rollen som tvinges gjennom TOTP.
 *
 * Hun staar UTENFOR alle kjeder (retailer_id = null): hun publiserer paa
 * tvers av kunder. Bolge 4A avslorte at /plattform manglet dekning fordi
 * ingen kunne logge inn som henne i CI.
 */
export const REDAKTOR = {
  epost: 'redaktor@test.sentiqa.no',
  passord: 'test-redaktor-2026',
}
export const REDAKTOR_HEMMELIGFIL = join(process.cwd(), 'test-results', 'redaktor-totp.txt')
export const REDAKTOR_OKTFIL = join(process.cwd(), 'test-results', 'redaktor-okt.json')

/** Den innloggede okta oppsettsteget lagrer, som alle eiertester gjenbruker. */
export const OKTFIL = join(process.cwd(), 'test-results', 'eier-okt.json')

function husk(hemmelig: string) {
  mkdirSync(dirname(HEMMELIGFIL), { recursive: true })
  writeFileSync(HEMMELIGFIL, hemmelig, 'utf8')
}

function hentHusket(): string | null {
  return existsSync(HEMMELIGFIL) ? readFileSync(HEMMELIGFIL, 'utf8').trim() : null
}

/**
 * Logger inn eieren og fullforer to-faktor - uansett hvilken av de to
 * lovlige veiene appen sender henne:
 *
 *   ingen faktor  -> /sikkerhet?paakrevd=1  (innrullering)
 *   har faktor    -> /logg-inn/totp         (steg opp)
 *
 * Begge er ekte tilstander for en ekte eier, og begge maa virke.
 */
export async function loggInnEier(page: Page): Promise<string> {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', EIER.epost)
  await page.fill('input[name="passord"]', EIER.passord)
  await page.click('button[type="submit"]')

  await expect(page).toHaveURL(/\/sikkerhet\?paakrevd=1|\/logg-inn\/totp/, {
    timeout: 20_000,
  })

  if (page.url().includes('/sikkerhet')) {
    await page.getByRole('button', { name: 'Sett opp to-faktor' }).click()
    const hemmelig = (await page.locator('.mfa-hemmelig').innerText()).trim()
    expect(hemmelig.length, 'Ingen hemmelighet paa innrulleringssida').toBeGreaterThan(10)

    await page.getByLabel(/engangskoden/i).fill(totp(hemmelig))
    await page.getByRole('button', { name: 'Aktiver to-faktor' }).click()

    // Tvunget innrullering sender henne rett til /oversikt naar sesjonen
    // er aal2. Det er porten som slipper henne gjennom.
    await expect(page).toHaveURL(/\/oversikt/, { timeout: 20_000 })
    husk(hemmelig)
    return hemmelig
  }

  const husket = hentHusket()
  expect(husket, 'Steg-opp uten kjent hemmelighet - ble faktoren rullet inn?').not.toBeNull()
  await page.getByLabel('Engangskode').fill(totp(husket!))
  await page.getByRole('button', { name: 'Bekreft' }).click()
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 20_000 })
  return husket!
}

