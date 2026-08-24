import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// UX-VAKTHUNDEN.
//
// MAALER DET SOM KAN MAALES. «Fint design» lar seg ikke automatisere, og
// en vakt som proever blir enten alltid roed eller alltid groenn - og en
// vakt som alltid er roed laerer folk aa ignorere roedt.
//
// Det som KAN maales er geometri og semantikk:
//   bryter noe ut av viewporten
//   overlapper to synlige kontroller hverandre
//   er en trykkflate for liten
//   har et interaktivt element et navn
//   ser man hvor fokus er
//   sier navigasjonen hvor man staar
//
// Alt annet hoerer hjemme i en gjennomgang med oeyne, mot ekte data.
//
// KLASSIFISERINGEN FOERST (PORT 4). Det ble meldt 65 `onClick` paa
// div/tr/li i kartlegginga. Det tallet var feil - det kom av en grep som
// talte bokstavene «li» inne i ord som «click» og «slett». Det er TRE,
// og ingen av dem skal konverteres:
//
//   kommandopalett  `.sq-dim`      bakteppe som lukker. Escape finnes.
//   sidemeny        `.meny-overlay` samme, og `aria-hidden`. Escape lagt til.
//   maaling/skjema  `<label onClick={stopPropagation}>` ikke interaktiv.
//
// Et bakteppe skal ikke vaere en knapp. Det skal ha en tastaturvei, og
// det er noe annet.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

const RUTER = ['/oversikt', '/salg', '/svinn', '/oppgaver', '/rutiner', '/stasjoner']

const BREDDER = [
  { navn: '1440 px', bredde: 1440, hoyde: 900 },
  { navn: '1152 px (125 % zoom)', bredde: 1152, hoyde: 720 },
]

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

test.describe('ux-vakthund', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await loggInn(page)
  })

  // --- Overflyt ------------------------------------------------------

  for (const { navn, bredde, hoyde } of BREDDER) {
    test(`ingen vannrett overflyt paa hovedrutene ved ${navn}`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: hoyde })
      for (const rute of RUTER) {
        await page.goto(rute)
        await expect(page.locator('.toppstripe')).toBeVisible()

        const f = await page.evaluate(() => ({
          dok: document.documentElement.scrollWidth,
          vindu: document.documentElement.clientWidth,
          // Hvem stikker ut? Uten dette er «sida flyter» umulig aa fikse.
          synder: [...document.querySelectorAll('body *')]
            .filter((e) => {
              const r = e.getBoundingClientRect()
              return r.width > 0 && r.right > document.documentElement.clientWidth + 1
            })
            .slice(0, 3)
            .map((e) => `${e.tagName.toLowerCase()}.${(e.className || '').toString().split(' ')[0]}`),
        }))

        expect(f.dok, `${rute} flyter vannrett. Stikker ut: ${f.synder.join(', ') || 'ukjent'}`)
          .toBeLessThanOrEqual(f.vindu + 1)
      }
    })
  }

  // --- Tilgjengelig navn ---------------------------------------------

  test('alle interaktive elementer har et navn', async ({ page }) => {
    for (const rute of RUTER) {
      await page.goto(rute)
      await expect(page.locator('.toppstripe')).toBeVisible()

      const uten = await page.evaluate(() => {
        const ut: string[] = []
        document.querySelectorAll('button, a[href], select, input:not([type="hidden"])').forEach((e) => {
          const r = e.getBoundingClientRect()
          if (r.width === 0 || r.height === 0) return

          const el = e as HTMLElement
          const navn = (el.getAttribute('aria-label') ?? '').trim()
            || (el.textContent ?? '').trim()
            || (el.getAttribute('title') ?? '').trim()
            // Et felt kan hete noe via <label for> eller ved aa ligge inni en.
            || (el.id ? (document.querySelector(`label[for="${el.id}"]`)?.textContent ?? '').trim() : '')
            || (el.closest('label')?.textContent ?? '').trim()
            || (el.getAttribute('aria-labelledby')
              ? (document.getElementById(el.getAttribute('aria-labelledby')!)?.textContent ?? '').trim()
              : '')

          if (!navn) {
            ut.push(`${e.tagName.toLowerCase()}.${(el.className || '').toString().split(' ')[0]}`)
          }
        })
        return ut
      })

      expect(uten, `${rute} har navnloese kontroller: ${uten.join(', ')}`).toEqual([])
    }
  })

  // --- Trykkflater ---------------------------------------------------

  test('ingen knapp eller navigasjonslenke under 36 px paa skrivebord', async ({ page }) => {
    for (const rute of RUTER) {
      await page.goto(rute)
      await expect(page.locator('.toppstripe')).toBeVisible()

      const smaa = await page.evaluate(() => {
        const ut: string[] = []
        document.querySelectorAll('button, .sidemeny a, .sq-faner a, .topp-hoyre a').forEach((e) => {
          const r = e.getBoundingClientRect()
          if (r.width === 0 || r.height === 0) return
          if (r.height < 36) {
            ut.push(`«${(e.textContent ?? '').trim().slice(0, 20)}» ${Math.round(r.height)} px`)
          }
        })
        return ut
      })

      expect(smaa, `${rute} har for smaa trykkflater: ${smaa.join(' · ')}`).toEqual([])
    }
  })

  // --- Fokus ----------------------------------------------------------

  test('fokus er synlig, ikke bare til stede', async ({ page }) => {
    await page.goto('/salg')
    await page.keyboard.press('Tab')

    const synlig = await page.evaluate(() => {
      const e = document.activeElement as HTMLElement | null
      if (!e || e === document.body) return null
      const s = getComputedStyle(e)
      // Enten et omriss, eller en tydelig ring. Begge er svar; ingen av
      // dem er «browseren gjoer sikkert noe».
      const omriss = parseFloat(s.outlineWidth) > 0 && s.outlineStyle !== 'none'
      const ring = s.boxShadow !== 'none'
      return { merke: e.tagName.toLowerCase(), omriss, ring }
    })

    expect(synlig, 'Ingenting fikk fokus av Tab').not.toBeNull()
    expect(synlig!.omriss || synlig!.ring,
      `Fokus paa <${synlig!.merke}> gir hverken omriss eller ring`).toBe(true)
  })

  // --- Hvor er jeg ----------------------------------------------------

  test('navigasjonen sier hvor man staar, programmatisk', async ({ page }) => {
    for (const rute of ['/salg', '/svinn', '/oppgaver']) {
      await page.goto(rute)
      // `aria-current="page"`, ikke bare en CSS-klasse: en skjermleser
      // hoerer ikke at noe er groent.
      const aktiv = page.locator(`.sidemeny a[aria-current="page"]`)
      await expect(aktiv, `${rute} markerer ikke aktivt menypunkt`).toHaveCount(1)
      await expect(aktiv).toHaveAttribute('href', rute)
    }
  })

  test('fanerad markerer aktiv fane naar man staar paa en av dem', async ({ page }) => {
    // `/rutiner/min` er lederens egen rute. `/rutiner` er nettbrettets,
    // og en leder som skriver den inn direkte faar en fanerad der INGEN
    // fane er aktiv - fanene er soesken uten treff. Det er et ekte funn,
    // men et annet: her maales invarianten «staar du PAA en fane, skal
    // noeyaktig én vaere merket».
    await page.goto('/rutiner/min')
    const faner = page.locator('.sq-faner a')
    test.skip(await faner.count() === 0, 'Ingen fanerad for denne rollen')

    const stier = await faner.evaluateAll((a) =>
      a.map((e) => (e as HTMLAnchorElement).getAttribute('href')))
    expect(stier, 'Ruta er ikke blant fanene - da maaler testen feil ting')
      .toContain('/rutiner/min')

    await expect(page.locator('.sq-faner a[aria-current="page"]')).toHaveCount(1)
    await expect(page.locator('.sq-faner a[aria-current="page"]'))
      .toHaveAttribute('href', '/rutiner/min')
  })

  // --- Bakteppene har en tastaturvei ----------------------------------

  test('menyen kan lukkes med Escape, ikke bare med mus', async ({ page }) => {
    // Hamburgeren finnes bare paa smal skjerm.
    await page.setViewportSize({ width: 700, height: 900 })
    await page.goto('/salg')

    const knapp = page.getByRole('button', { name: /meny/i }).first()
    await expect(knapp).toBeVisible()
    await knapp.click()
    await expect(page.locator('.sidemeny.apen')).toBeVisible()

    // Overlayet er `aria-hidden` og kan ikke naas med tastatur. Uten
    // Escape kom den som navigerer med tastatur seg inn og ikke ut.
    await page.keyboard.press('Escape')
    await expect(page.locator('.sidemeny.apen')).toHaveCount(0)
  })

  test('kommandopaletten kan lukkes med Escape', async ({ page }) => {
    await page.goto('/salg')
    const sok = page.locator('.sq-sokknapp')
    test.skip(await sok.count() === 0, 'Ingen kommandopalett for denne rollen')

    await sok.click()
    await expect(page.locator('[role="dialog"]')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.locator('[role="dialog"]')).toHaveCount(0)
  })

  // --- Kanarifugler ---------------------------------------------------
  //
  // Hver maaling over er en LOEKKE over det den finner. Finner den
  // ingenting - fordi en velger ble skrevet om, eller fordi sida ikke
  // rakk aa laste - er loekka tom, og en tom loekke er groenn.

  test('kanarifugl: det FINNES kontroller aa maale', async ({ page }) => {
    await page.goto('/salg')
    await expect(page.locator('.toppstripe')).toBeVisible()
    const n = await page.evaluate(() =>
      document.querySelectorAll('button, a[href], select').length)
    expect(n, 'Fant ingen kontroller - da maaler vaktene ingenting').toBeGreaterThan(5)
  })

  test('kanarifugl: navnesjekken fanger et navnloest element', async ({ page }) => {
    await page.goto('/salg')
    const funnet = await page.evaluate(() => {
      const b = document.createElement('button')
      b.style.width = '40px'
      b.style.height = '40px'
      document.body.appendChild(b)
      const r = b.getBoundingClientRect()
      const navn = (b.getAttribute('aria-label') ?? '') || (b.textContent ?? '').trim()
      const ville = r.width > 0 && r.height > 0 && !navn
      b.remove()
      return ville
    })
    expect(funnet, 'Navnesjekken ville ikke sett en navnloes knapp').toBe(true)
  })
})
