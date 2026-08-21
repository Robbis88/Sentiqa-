import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL, REDAKTOR_OKTFIL } from './eier'

// =====================================================================
// Port 0 til bolge 4B: sikkerhetsnettene for /bemanning og /oversikt.
//
// Ingen designendring her. Bare det som maa staa PAA PLASS foer de to
// tyngste sidene rores:
//
//   1  /oversikt har flere ansikter - en baseline per rolle, saa vi kan
//      se hva som forsvinner naar den skrives om
//   2  plattform-redaktoren har aldri kunnet logge inn i CI
//   3  nettbrettets stiler kan lekke inn i desktop, som paa /ikmat
// =====================================================================

const SJEF = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }
const NETTBRETT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }

async function loggInn(page: Page, b: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', b.epost)
  await page.fill('input[name="passord"]', b.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

/** Alle synlige overskrifter paa sida, i dokumentrekkefolge. */
async function seksjoner(page: Page): Promise<string[]> {
  return page.evaluate(() => [...document.querySelectorAll('h1, h2, h3')]
    .map((e) => (e.textContent ?? '').replace(/\s+/g, ' ').trim())
    .filter(Boolean))
}

// ---------------------------------------------------------------------
// 1. /OVERSIKT: BASELINE PER ROLLE
// ---------------------------------------------------------------------
test.describe('/oversikt har flere ansikter', () => {
  test('butikksjefens oversikt har seksjoner, og de er hennes', async ({ page }) => {
    await loggInn(page, SJEF)
    await page.goto('/oversikt')

    const funnet = await seksjoner(page)
    // BASELINE, IKKE FASIT. Poenget er ikke aa laase teksten - den skal
    // endres i 4B - men aa ha et MAALT utgangspunkt aa sammenligne mot,
    // og aa vite at rollen faktisk faar sitt eget bilde.
    expect(funnet.length, `Butikksjefens oversikt:\n  ${funnet.join('\n  ')}`)
      .toBeGreaterThan(2)

    // Butikksjefen skal IKKE se eierens portefoljebilde.
    const tekst = await page.locator('body').innerText()
    expect(tekst).not.toContain('Stasjonene mot hverandre')
  })


  test('nettbrettets oversikt er nettbrettets, ikke lederens', async ({ page }) => {
    await loggInn(page, NETTBRETT)
    await page.goto('/oversikt')

    // Nettbrettet faar TabletHjem - en helt annen flate bak samme rute.
    // Den skal ikke ha lederens sidehode.
    expect(await page.locator('.sq-sidehode').count(),
      'Nettbrettet fikk lederens sidehode').toBe(0)
    const funnet = await seksjoner(page)
    expect(funnet.length, `Nettbrettets hjem:\n  ${funnet.join('\n  ')}`).toBeGreaterThan(0)
  })
})

test.describe('/oversikt for eieren', () => {
  test.use({ storageState: OKTFIL })

  test('eierens oversikt er en annen side enn butikksjefens', async ({ page }) => {
    await page.goto('/oversikt')
    const funnet = await seksjoner(page)
    expect(funnet.length, `Eierens oversikt:\n  ${funnet.join('\n  ')}`).toBeGreaterThan(2)
  })
})

// ---------------------------------------------------------------------
// 2. PLATTFORM-REDAKTOREN
// ---------------------------------------------------------------------
test.describe('plattform-redaktoren, gjennom ekte TOTP', () => {
  test.use({ storageState: REDAKTOR_OKTFIL })

  test('naar sine egne flater med riktig rolle', async ({ page }) => {
    await page.goto('/plattform')
    await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)
    await expect(page.locator('body')).not.toContainText('Plattform-oversikten er for plattform-eier')

    // /redaktor og /kunnskap er ogsaa hennes - og har aldri vaert maalt.
    for (const sti of ['/redaktor', '/kunnskap']) {
      await page.goto(sti)
      await expect(page.locator('.sq-sidehode h1'), sti).toHaveCount(1)
    }
  })

  test('ser ingen kjedes drift - hun staar utenfor dem alle', async ({ page }) => {
    // retailer_id er null for denne rollen. Hun publiserer paa tvers, og
    // skal ikke ha en kjedes tall.
    await page.goto('/salg')
    await expect(page.locator('body')).toContainText(/ikke tilgang|Kun eier|logg inn|eier/i)
  })

  test('ingen axe-brudd paa en ekte plattformflate', async ({ page }) => {
    await page.goto('/plattform')
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})

test.describe('feil rolle naar ikke plattformen', () => {
  test('butikksjefen avvises', async ({ page }) => {
    await loggInn(page, SJEF)
    await page.goto('/plattform')
    await expect(page.locator('body')).toContainText(/plattform-eier|ikke tilgang/i)
  })

  test('nettbrettet avvises', async ({ page }) => {
    await loggInn(page, NETTBRETT)
    await page.goto('/plattform')
    await expect(page.locator('body')).toContainText(/plattform-eier|ikke tilgang|logg inn/i)
  })
})

// ---------------------------------------------------------------------
// 3. STIL-LEKKASJE MELLOM NETTBRETT OG DESKTOP
// ---------------------------------------------------------------------
test.describe('nettbrettets stiler blir paa nettbrettet', () => {
  /**
   * Rutene som deler kode mellom nettbrett og desktop. /ikmat sto paa
   * denne lista med `.tablet-hode` paa lederens side og 1,9:1 i kontrast
   * - funnet av axe i bolge 4A, etter aa ha staatt lenge.
   */
  const DELTE = ['/ikmat', '/rutiner', '/anvisninger', '/mine-opplysninger', '/oversikt']

  /**
   * Kjente lekkasjer, med grunn og forfallsdato.
   *
   * LISTA ER TOM ETTER BOLGE 5, og det var hele avtalen da den ble
   * opprettet. Den sto med ett navn: `/rutiner: .tablet-hode`. Ruta ER
   * nettbrettets - «Paa vakt», rolle [T] i navigasjonen - men en leder
   * som gikk dit direkte fikk nettbrettets moerke hode paa lys
   * bakgrunn, samme 1,9:1 som /ikmat hadde.
   *
   * Loesningen var den samme som paa /ikmat: svaret er det samme for
   * begge rollene - hvor mange igjen - men formen er det ikke. Lederen
   * faar `Sidehode`, nettbrettet beholder sitt.
   *
   * En tom liste er ikke det samme som en fjernet liste. Den staar
   * igjen fordi den er MEKANIKKEN som gjor unntak synlige framfor
   * skjulte, og neste lekkasje skal maatte skrives inn her med en grunn.
   */
  const KJENTE = new Set<string>([])

  test('ingen .tablet-klasse paa lederens flate', async ({ page }) => {
    await loggInn(page, SJEF)

    const funn: string[] = []
    for (const sti of DELTE) {
      await page.goto(sti)
      // Skallet selv setter `.tablet` paa <body> for nettbrettrollen.
      // Er den ikke satt, er vi paa desktop - og da skal ingen
      // presentasjonsklasse fra nettbrettet vaere i bruk.
      const paaTablet = await page.evaluate(() => document.body.classList.contains('tablet')
        || document.querySelector('.tablet') !== null)
      if (paaTablet) continue

      const lekkasje = await page.evaluate(() => [...document.querySelectorAll('[class]')]
        .flatMap((e) => [...e.classList])
        .filter((k) => k.startsWith('tablet-'))
        .filter((k, i, a) => a.indexOf(k) === i))
      for (const k of lekkasje) {
        const id = `${sti}: .${k}`
        if (!KJENTE.has(id)) funn.push(id)
      }
    }

    expect(
      funn,
      'Nettbrettets klasser er tegnet for morkt underlag. Paa lederens '
      + 'lyse side gir de kontrast langt under kravet - /ikmat sto slik '
      + 'lenge for axe fant den.',
    ).toEqual([])
  })

  test('nettbrettets egen flate er fortsatt axe-ren', async ({ page }) => {
    // Nettbrettet skal IKKE redesignes her. Testen finnes for aa fange
    // at en opprydding paa desktop ikke odelegger den andre flata.
    await loggInn(page, NETTBRETT)
    await page.goto('/oversikt')

    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\nnettbrettets hjem\n${funn.join('\n')}\n`).toEqual([])
  })
})
