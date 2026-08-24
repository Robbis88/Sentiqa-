import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// ETT KNAPPESPRAAK.
//
// Elementet `<button>` var PRIMAERT som standard - fylt groenn flate
// uten klasse - mens `<Knapp>` var SEKUNDAER som standard. To systemer
// som pekte motsatt vei paa samme skjerm.
//
// Foelgen var ikke bare rot: 51 knapper uten klasse og 45 med `liten`
// fikk hovedhandlingens vekt uten at noen hadde bestemt det. Steppere
// (- og +), ✕-knapper og «Prøv igjen» i feilgrensene sto alle som fylte
// groenne flater, side om side med den ene knappen som faktisk var
// sidas hovedhandling.
//
// REGELEN ER MEKANISK: primaer = fullfoerer et skjema. Vekslere er
// unntatt - de har eget spraak.
//
// MAALER GEOMETRI OG TELLING, IKKE SMAK. At en skjerm ser «ryddig» ut
// kan ikke automatiseres. At en stepper ikke har hovedhandlingens farge,
// og at ingen trykkflate er for liten, kan det.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

const RUTER = ['/oversikt', '/salg', '/svinn', '/produksjonsplan?dato=2026-02-02', '/oppgaver']

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Alle synlige knapper med rolle, farge og hoeyde. */
async function knapper(page: Page) {
  return page.evaluate(() => {
    const ut: {
      tekst: string; type: string; klasser: string
      bakgrunn: string; hoyde: number; bredde: number
    }[] = []
    document.querySelectorAll('button').forEach((b) => {
      const r = b.getBoundingClientRect()
      if (r.width === 0 || r.height === 0) return
      const s = getComputedStyle(b)
      if (s.visibility === 'hidden' || s.display === 'none') return
      ut.push({
        tekst: (b.textContent ?? '').trim().slice(0, 30),
        type: b.getAttribute('type') ?? '(ingen)',
        klasser: b.className,
        bakgrunn: s.backgroundColor,
        hoyde: Math.round(r.height),
        bredde: Math.round(r.width),
      })
    })
    return ut
  })
}

/** Merkevaregroennt, --primaer #2e7d6b. Hovedhandlingens farge. */
const PRIMAER = 'rgb(46, 125, 107)'

test.describe('knappespraak', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await loggInn(page)
  })

  for (const rute of RUTER) {
    test(`${rute.split('?')[0]} — bare skjemahandlinger har hovedhandlingens farge`, async ({ page }) => {
      await page.goto(rute)
      await expect(page.locator('.toppstripe')).toBeVisible()

      for (const k of await knapper(page)) {
        if (k.bakgrunn !== PRIMAER) continue

        // En primaerfarget knapp skal enten fullfoere et skjema, eller
        // vaere merket primaer med vilje. Er den ingen av delene, har
        // den faatt vekten fordi noen glemte en klasse.
        const lovlig = k.type === 'submit' || /\bprimar\b/.test(k.klasser)
        expect(lovlig,
          `«${k.tekst}» er primaerfarget uten aa vaere en skjemahandling `
          + `(type=${k.type}, klasser=«${k.klasser}»)`).toBe(true)
      }
    })

    test(`${rute.split('?')[0]} — ingen trykkflate under 36 px`, async ({ page }) => {
      await page.goto(rute)
      await expect(page.locator('.toppstripe')).toBeVisible()

      for (const k of await knapper(page)) {
        expect(k.hoyde,
          `«${k.tekst}» er ${k.hoyde} px hoey (klasser: «${k.klasser}»)`)
          .toBeGreaterThanOrEqual(36)
      }
    })
  }

  test('steppere og ikonknapper roper ikke', async ({ page }) => {
    await page.goto('/produksjonsplan?dato=2026-02-02')
    const alle = await knapper(page)
    const smaa = alle.filter((k) => /^[−+✕↩–-]$/.test(k.tekst))

    // Fantes ingen steppere paa denne planen, er det ingenting aa maale -
    // og da skal testen si det, ikke bestaa i stillhet.
    test.skip(smaa.length === 0, 'Ingen steppere paa denne planen')

    for (const k of smaa) {
      expect(k.bakgrunn, `Stepperen «${k.tekst}» har hovedhandlingens farge`)
        .not.toBe(PRIMAER)
    }
  })

  test('«Vis dagen» er tydeligere enn feltet den staar ved siden av', async ({ page }) => {
    await page.goto('/produksjonsplan?dato=2026-02-02')

    const knapp = page.getByRole('button', { name: 'Vis dagen' })
    await expect(knapp).toBeVisible()

    const k = await knapp.evaluate((e) => {
      const s = getComputedStyle(e)
      return { bakgrunn: s.backgroundColor, farge: s.color }
    })
    const felt = await page.locator('input[name="dato"]').evaluate((e) => ({
      bakgrunn: getComputedStyle(e).backgroundColor,
    }))

    // «Dag [25.08.2026] [Vis dagen]» var to hvite bokser ved siden av
    // hverandre. Feltet er verdien, knappen er handlingen - og det skal
    // ses uten aa proeve seg fram.
    expect(k.bakgrunn, 'Handlingen har samme flate som verdifeltet')
      .not.toBe(felt.bakgrunn)
    expect(k.bakgrunn).toBe(PRIMAER)
  })

  // KANARIFUGL: uten denne kunne noen sette elementstilen tilbake til
  // fylt groenn, og hver eneste maaling over ville fortsatt vaert
  // groenn - fordi de bare ser paa knapper som ER primaerfarget, og da
  // ville alle vaere det.
  test('kanarifugl: en knapp uten klasse er IKKE primaer', async ({ page }) => {
    await page.goto('/oversikt')
    const farge = await page.evaluate(() => {
      const b = document.createElement('button')
      b.textContent = 'test'
      document.body.appendChild(b)
      const f = getComputedStyle(b).backgroundColor
      b.remove()
      return f
    })
    expect(farge, 'Elementstilen gir fortsatt hovedhandlingens farge uten klasse')
      .not.toBe(PRIMAER)
  })

  test('kanarifugl: en knapp MED primar-klasse ER primaer', async ({ page }) => {
    await page.goto('/oversikt')
    const farge = await page.evaluate(() => {
      const b = document.createElement('button')
      b.className = 'primar'
      b.textContent = 'test'
      document.body.appendChild(b)
      const f = getComputedStyle(b).backgroundColor
      b.remove()
      return f
    })
    expect(farge, 'primar-klassen gir ikke lenger hovedhandlingens farge').toBe(PRIMAER)
  })
})
