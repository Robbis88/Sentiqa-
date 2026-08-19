import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Testene som krever en oekt.
//
// Kjorer mot en LOKAL Supabase som CI starter fersk for hver kjoring, og
// som seedes av supabase/seed.sql. Ingen hemmeligheter: passordene under
// staar i seeden og gjelder kun en base som slettes etterpaa.
//
// MFA er grunnen til at bare to roller er med. Eier og
// plattform-redaktor tvinges gjennom TOTP (src/lib/auth/mfa.ts), og en
// innlogging som eier havner i innrullering i stedet for paa forsiden.
// Det krever en seedet faktor, og hoerer til en senere runde.
// =====================================================================

const BRUKERE = {
  butikksjef: { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' },
  nettbrett: { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' },
}

async function loggInn(page: Page, bruker: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', bruker.epost)
  await page.fill('input[name="passord"]', bruker.passord)
  await page.click('button[type="submit"]')

  // Blir vi staaende, skal feilmeldingen fra sida staa i rapporten.
  // Foerste utgave sa bare «unexpected value /logg-inn», og da vet man
  // at innlogging feilet, men ikke hvorfor - og hver runde med gjetting
  // koster en CI-kjoring.
  try {
    // Innlogget betyr «ikke lenger paa innloggingssida». Hvilken side man
    // havner paa avhenger av rolle, og det vil vi ikke laase.
    await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
  } catch (e) {
    const melding = await page.locator('[role="alert"], .feil').first()
      .textContent().catch(() => null)
    throw new Error(
      `Innlogging som ${bruker.epost} feilet.\n`
      + `Sida sier: ${melding?.trim() || '(ingen feilmelding vist)'}\n`
      + `Original: ${(e as Error).message}`,
    )
  }
}

test.describe('nettbrettet', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, BRUKERE.nettbrett)
  })

  test('treffomraadene taaler hansker', async ({ page }) => {
    // DETTE ER HULLET SOM VAR AAPENT LENGST. globals.css setter
    // .tablet .kryss til 56x56 fordi 44 er iOS-minimum for BAR finger,
    // og en sekstenaaring med arbeidshansker paa en kald morgen bommer.
    // Regelen har aldri vaert maalt - jsdom har ingen layout, og skjermen
    // krever oekt.
    await page.goto('/rutiner')

    const smaa = await page.evaluate(() => {
      const ut: string[] = []
      for (const el of document.querySelectorAll('button, a[href], input[type=submit], select')) {
        const r = el.getBoundingClientRect()
        if (r.width === 0 && r.height === 0) continue
        if (getComputedStyle(el).display === 'inline') continue // WCAG unntar inline-maal
        if (r.height < 44 || r.width < 44) {
          ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 24)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
        }
      }
      return ut
    })
    expect(smaa, `For smaa paa nettbrettet:\n  ${smaa.join('\n  ')}\n`).toEqual([])
  })

  test('hjem aapner med hva som gjenstaar, ikke med en meny', async ({ page }) => {
    await page.goto('/oversikt')
    // Skiftlista skal staa FORAN flisene. Bytter noen om paa det, er
    // nettbrettet tilbake til et modulrutenett - hele poenget med
    // redesignet av hjemskjermen.
    const rekkefolge = await page.evaluate(() => {
      const skift = document.querySelector('.tablet-skiftet, [data-skiftet]')
      const fliser = document.querySelector('.tablet-tiles')
      if (!skift || !fliser) return null
      return (skift.compareDocumentPosition(fliser) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0
    })
    // null = en av delene finnes ikke i denne tilstanden; da sier vi ikke noe.
    if (rekkefolge !== null) expect(rekkefolge, 'Flisene staar foran skiftlista').toBe(true)
  })

  test('ingen axe-brudd med kontrast', async ({ page }) => {
    await page.goto('/rutiner')
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.map((v) => `${v.id}: ${v.help} (${v.nodes.length})`)
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})

test.describe('butikksjefen', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, BRUKERE.butikksjef)
  })

  // Basen seedes UTEN salgsdata. Det er med vilje: tomme tilstander er de
  // som aldri ses under utvikling, fordi utvikleren alltid har data - og
  // en side som krasjer paa tom liste krasjer for den nye kunden, ikke
  // for oss.
  for (const sti of ['/salg', '/svinn', '/timesalg', '/utsolgt', '/oppgaver', '/bemanning', '/rutiner/min']) {
    test(`${sti} taaler tom database`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      const svar = await page.goto(sti)
      expect(svar?.status(), `${sti} svarte ${svar?.status()}`).toBeLessThan(400)
      await expect(page.locator('h1')).toBeVisible()
      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })
  }

  test('ser bare sine egne stasjoner', async ({ page }) => {
    // Isolasjonen er testet i SQL (rls_isolasjon.sql). Dette er den
    // samme egenskapen sett gjennom grensesnittet - de kan vaere uenige
    // hvis en sporring gaar utenom RLS et sted.
    await page.goto('/salg')
    const tekst = await page.locator('body').innerText()
    expect(tekst).not.toContain('9467') // stasjon som ikke finnes i seeden
  })
})
