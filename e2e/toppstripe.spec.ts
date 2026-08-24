import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// TOPPSTRIPEN TAALER DET SOM FAKTISK STAAR I DEN.
//
// Skjermbildet 2026-08-24 viste «4185 St1 DaleRobert» - stasjonstekst
// klistret inntil brukernavnet. Stripa var `display: flex` med
// `space-between`, fire barn og INGEN gap. Hierarkiet oppstod dermed av
// innholdets bredde, og ved trangt vindu forsvant det helt.
//
// MAALER GEOMETRI, IKKE SMAK. «Fint design» lar seg ikke automatisere,
// og en vakt som proever blir enten alltid roed eller alltid groenn. Det
// som KAN maales: bryter noe ut av viewporten, overlapper to synlige
// bokser hverandre, er en trykkflate under grensen, har et interaktivt
// element et navn.
//
// LANGE VERDIER SETTES INN I DOM-EN, ikke i basen. Testen skal maale at
// LAYOUTEN taaler et langt stasjonsnavn - ikke at akkurat denne kjeden
// tilfeldigvis har et. Da virker den ogsaa naar Kelsar kommer inn med
// «5102 St1 Bergen Sentrum Vest».
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

const BREDDER = [
  { navn: '1440 px skrivebord', bredde: 1440, hoyde: 900 },
  { navn: 'smal laptop', bredde: 1280, hoyde: 800 },
  // 125 % zoom paa 1440 gir 1152 CSS-piksler. Zoom er ikke en egen
  // modus - det er faerre piksler til det samme innholdet.
  { navn: '1440 px ved 125 % zoom', bredde: 1152, hoyde: 720 },
]

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Setter inn urimelig lange verdier der brukeren kan ha lange verdier. */
async function settLangeNavn(page: Page) {
  await page.evaluate(() => {
    const navn = document.querySelector('.bruker .brukernavn')
    if (navn) navn.textContent = 'Robert Kristian Vestbø-Hammerstad'
    document.querySelectorAll('.sq-stasjonskontekst option').forEach((o) => {
      o.textContent = `${o.textContent} St1 Bergen Sentrum Vest Terminalen`
    })
  })
}

/** Bokser som er synlige og har areal — det er dem som kan kollidere. */
async function bokser(page: Page, velgere: string[]) {
  const ut: { velger: string; boks: { x: number; y: number; w: number; h: number } }[] = []
  for (const v of velgere) {
    const el = page.locator(v).first()
    if (await el.count() === 0) continue
    if (!(await el.isVisible())) continue
    const b = await el.boundingBox()
    if (b && b.width > 0 && b.height > 0) {
      ut.push({ velger: v, boks: { x: b.x, y: b.y, w: b.width, h: b.height } })
    }
  }
  return ut
}

function overlapper(
  a: { x: number; y: number; w: number; h: number },
  b: { x: number; y: number; w: number; h: number },
) {
  // Ett piksels slingringsmonn: nabobokser som deler kant er ikke overlapp.
  const m = 1
  return a.x < b.x + b.w - m && b.x < a.x + a.w - m
    && a.y < b.y + b.h - m && b.y < a.y + a.h - m
}

test.describe('toppstripen', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const { navn, bredde, hoyde } of BREDDER) {
    test(`${navn} — ingen vannrett overflyt, heller ikke med lange navn`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: hoyde })
      await page.goto('/salg')
      await expect(page.locator('.toppstripe')).toBeVisible()

      for (const runde of ['vanlige navn', 'lange navn']) {
        if (runde === 'lange navn') await settLangeNavn(page)

        const flyt = await page.evaluate(() => ({
          dok: document.documentElement.scrollWidth,
          vindu: document.documentElement.clientWidth,
          stripe: (document.querySelector('.toppstripe') as HTMLElement)?.scrollWidth ?? 0,
          stripeSynlig: (document.querySelector('.toppstripe') as HTMLElement)?.clientWidth ?? 0,
        }))

        expect(flyt.dok, `Sida flyter vannrett med ${runde}`)
          .toBeLessThanOrEqual(flyt.vindu + 1)
        expect(flyt.stripe, `Toppstripen flyter vannrett med ${runde}`)
          .toBeLessThanOrEqual(flyt.stripeSynlig + 1)
      }
    })

    test(`${navn} — sonene overlapper ikke`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: hoyde })
      await page.goto('/salg')
      await settLangeNavn(page)

      const alle = await bokser(page, [
        '.topp-venstre',
        '.topp-midt',
        '.topp-hoyre',
        '.sq-stasjonskontekst select',
        '.bruker',
        '.rolle-pip',
        '.logg-ut',
      ])

      for (let i = 0; i < alle.length; i++) {
        for (let j = i + 1; j < alle.length; j++) {
          const a = alle[i]
          const b = alle[j]
          // Bokser som ligger inne i hverandre er ikke kollisjon —
          // `.rolle-pip` ligger i `.bruker`, som ligger i `.topp-hoyre`.
          const inni = a.boks.x <= b.boks.x && a.boks.y <= b.boks.y
            && a.boks.x + a.boks.w >= b.boks.x + b.boks.w
            && a.boks.y + a.boks.h >= b.boks.y + b.boks.h
          const inni2 = b.boks.x <= a.boks.x && b.boks.y <= a.boks.y
            && b.boks.x + b.boks.w >= a.boks.x + a.boks.w
            && b.boks.y + b.boks.h >= a.boks.y + a.boks.h
          if (inni || inni2) continue

          const vis = (x: typeof a) =>
            `${x.velger} [x ${Math.round(x.boks.x)}–${Math.round(x.boks.x + x.boks.w)}, `
            + `y ${Math.round(x.boks.y)}–${Math.round(x.boks.y + x.boks.h)}]`
          expect(overlapper(a.boks, b.boks),
            `Overlapp ved ${bredde} px:
  ${vis(a)}
  ${vis(b)}`).toBe(false)
        }
      }
    })
  }

  test('sonene ligger i rekkefoelge: soek, stasjon, bruker', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/salg')

    const midt = await page.locator('.topp-midt').boundingBox()
    const hoyre = await page.locator('.topp-hoyre').boundingBox()
    expect(midt && hoyre, 'Sonene finnes ikke').toBeTruthy()
    expect(midt!.x, 'Stasjonssonen ligger ikke foer brukersonen')
      .toBeLessThan(hoyre!.x)
  })

  test('mellom stasjon og bruker er det faktisk luft', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/salg')

    const velger = page.locator('.sq-stasjonskontekst select')
    if (await velger.count() === 0) test.skip(true, 'Ingen velger for denne brukeren')

    const v = (await velger.boundingBox())!
    const b = (await page.locator('.bruker').boundingBox())!

    // «4185 St1 DaleRobert» var null piksler. Under ti er ikke luft.
    expect(b.x - (v.x + v.width), 'Velgeren staar for tett paa brukernavnet')
      .toBeGreaterThanOrEqual(10)
  })

  test('velgeren ser klikkbar ut i hviletilstand', async ({ page }) => {
    await page.goto('/salg')
    const velger = page.locator('.sq-stasjonskontekst select')
    if (await velger.count() === 0) test.skip(true, 'Ingen velger for denne brukeren')

    const stil = await velger.evaluate((e) => {
      const s = getComputedStyle(e)
      return { kant: s.borderTopColor, bredde: s.borderTopWidth, peker: s.cursor }
    })

    // Kanten var `transparent` - da sa ingenting at dette var en kontroll
    // foer du holdt musa over den.
    expect(stil.kant, 'Velgeren har gjennomsiktig kant i hviletilstand')
      .not.toMatch(/rgba\(0, 0, 0, 0\)|transparent/)
    expect(parseFloat(stil.bredde)).toBeGreaterThan(0)
    expect(stil.peker).toBe('pointer')
  })

  test('ikonene i toppstripen har navn OG forklaring', async ({ page }) => {
    await page.goto('/salg')
    for (const merke of ['Varsler', 'Sikkerhet']) {
      const l = page.locator(`.topp-hoyre a[aria-label*="${merke}"]`).first()
      await expect(l, `${merke} mangler tilgjengelig navn`).toHaveCount(1)
      expect(await l.getAttribute('title'), `${merke} mangler title`).toBeTruthy()
    }
  })

  // KANARIFUGL: uten dette kunne noen fjerne sonene og la stripa gaa
  // tilbake til fire soesken uten gap - og hver eneste maaling over
  // ville fortsatt vaert groenn paa et vidt vindu, fordi det er trangt
  // vindu og lange navn som avsloerer det.
  test('kanarifugl: stripa er et rutenett med tre soner', async ({ page }) => {
    await page.goto('/salg')
    const stil = await page.locator('.toppstripe').evaluate((e) => {
      const s = getComputedStyle(e)
      return { visning: s.display, gap: s.columnGap, soner: e.querySelectorAll(':scope > .topp-sone').length }
    })
    expect(stil.visning).toBe('grid')
    expect(stil.soner, 'Toppstripen har ikke tre soner').toBe(3)
    expect(parseFloat(stil.gap), 'Sonene har ingen gap').toBeGreaterThan(0)
  })
})
