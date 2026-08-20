import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 5: nettbrettet.
//
// Dette er ikke responsiv desktop. Det er en egen operativ flate, og de
// to spor ikke om det samme:
//
//   Desktop   Hva krever oppmerksomhet, og hvorfor?
//   Nettbrett Hva skal jeg gjore naa?
//
// Bevisene under maaler nettopp det skillet - at flatene IKKE ligner
// hverandre - i tillegg til de fire tingene som gjelder for enhver
// arbeidsflate: rolle, treffomraade, kontrast og aksessibilitet.
//
// TO NETTBRETT MED VILJE. `nettbrett@` staar i den tomme Testkjeden og
// beviser tomtilstanden. `nettbrett-analyse@` staar i Analysekjeden med
// IK-mat-punkter aa maale, og beviser arbeidsflyten. En koe uten
// oppgaver er ikke en koe.
// =====================================================================

const TOMT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }
const MED_DATA = {
  epost: 'nettbrett-analyse@test.sentiqa.no',
  passord: 'test-nettbrett-analyse-2026',
}

/** Rutene nettbrettet naar. Samme mengde som `naabart()` gir rollen. */
const RUTENE = [
  '/oversikt',
  '/rutiner',
  '/anvisninger',
  '/lenker',
  '/ikmat',
  '/merker',
  '/mine-opplysninger',
  '/nyheter',
  '/produksjonsplan',
  '/varsler',
]

/**
 * Samme maalestokk som design-skrallen bruker (src/lib/redesign/design.ts).
 *
 * Bygget fra en streng framfor en literal: monsteret er rene
 * kodepunkt-escapes, og de overlever ikke alltid en tur gjennom et
 * verktoy som normaliserer tegn.
 */
const EMOJI = new RegExp('[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]|[\\u2000-\\u32FF]\\uFE0F', 'g')

async function loggInn(page: Page, b: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', b.epost)
  await page.fill('input[name="passord"]', b.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

async function paaFlata(page: Page, sti: string) {
  const svar = await page.goto(sti)
  expect(svar?.status(), `${sti} svarte ${svar?.status()}`).toBeLessThan(400)
  await expect(page.locator('.tablet'), `${sti} er ikke nettbrettets flate`).toBeVisible()
}

// ---------------------------------------------------------------------
// 1. ROLLE: flata er nettbrettets, og bare nettbrettets
// ---------------------------------------------------------------------
test.describe('nettbrettet faar sin egen verden', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti} er nettbrettets flate`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))
      await paaFlata(page, sti)

      // «IKKE KOPIER DESKTOP INN I TABLET» - maalt to ganger, fordi
      // regelen har to halvdeler, og forste utgave av denne testen tok
      // bare den ene.
      //
      // 1. SPRAAKET. `Nokkeltall` og `Signal` er lederflatens verktoy
      //    for «hva krever oppmerksomhet, og hvorfor». Nettbrettet spor
      //    om noe annet, og skal ikke ha dem.
      const lekkasje = await page.evaluate(() => [
        '.sq-nokkeltall', '.sq-signal', '.sq-puls', '.sq-sak',
      ].filter((k) => document.querySelector(k) !== null))
      expect(lekkasje, `${sti}: lederflatens analysespraak paa nettbrettet`).toEqual([])

      // 2. FLATA. Byggeklossene DELES - sidehodet, radene, tabellen -
      //    og det er meningen: ett system, to paletter. Men da maa
      //    palettbyttet faktisk virke. Foerste maaling fant lederens
      //    hvite kort midt i det moerke skallet paa fem ruter.
      const lyse = await page.evaluate(() => {
        const flate = (el: Element): string => {
          let n: Element | null = el
          while (n) {
            const b = getComputedStyle(n).backgroundColor
            const m = b.match(/rgba?\(([^)]+)\)/)
            if (m) {
              const d = m[1].split(',').map((x) => Number(x))
              if ((d[3] ?? 1) > 0.5) return `${d[0]},${d[1]},${d[2]}`
            }
            n = n.parentElement
          }
          return '0,0,0'
        }
        const ut: string[] = []
        for (const sel of ['.sq-sidehode', '.sq-rad-lenke', '.sq-tom', '.tabell', '.kort']) {
          for (const el of document.querySelectorAll(sel)) {
            const r = el.getBoundingClientRect()
            if (r.width === 0 || r.height === 0) continue
            const [rr, gg, bb] = flate(el).split(',').map(Number)
            // Enkel lyshet. Vi trenger ikke WCAG her - vi trenger aa
            // vite om flata er dag eller natt.
            if ((rr * 299 + gg * 587 + bb * 114) / 1000 > 128) {
              ut.push(`${sel} paa rgb(${flate(el)})`)
            }
          }
        }
        return [...new Set(ut)]
      })
      expect(lyse, `${sti}: lys flate i den moerke verdenen`).toEqual([])

      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })
  }

  test('lederens ruter er stengt', async ({ page }) => {
    for (const sti of ['/bemanning', '/salg', '/regnskap', '/ansatte']) {
      await page.goto(sti)
      await expect(page.locator('body'), sti).toContainText(/ikke tilgang|Kun eier|logg inn|eier/i)
    }
  })
})

// ---------------------------------------------------------------------
// 2. TREFFOMRAADE: hansker, ikke mus
// ---------------------------------------------------------------------
test.describe('treffomraadene taaler hansker', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti}`, async ({ page }) => {
      await paaFlata(page, sti)
      // 44 px er iOS-minimum for bar finger. Nettbrettet betjenes med
      // arbeidshansker av en som staar med noe i den andre haanda, og
      // skallet setter derfor 48 der det raar. Grensa her er 44: det er
      // det ABSOLUTTE minimumet, og en test som krevde 48 ville felt
      // ting som er gode nok.
      const smaa = await page.evaluate(() => {
        const ut: string[] = []
        for (const el of document.querySelectorAll('button, a[href], input, select, textarea, summary')) {
          const r = el.getBoundingClientRect()
          if (r.width === 0 && r.height === 0) continue
          if (getComputedStyle(el).display === 'inline') continue
          if (r.height < 44 || r.width < 44) {
            ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 28)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
          }
        }
        return ut
      })
      expect(smaa, `For smaa paa ${sti}:\n  ${smaa.join('\n  ')}\n`).toEqual([])
    })
  }
})

// ---------------------------------------------------------------------
// 3. KONTRAST OG AKSESSIBILITET
// ---------------------------------------------------------------------
test.describe('den moerke flata er lesbar', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti} har ingen axe-brudd`, async ({ page }) => {
      await paaFlata(page, sti)
      // Kontrasten maales HER, ikke i jsdom: den krever layout. Den
      // deterministiske vakten i farger.test.ts maaler tokenparene;
      // denne maaler det som faktisk ble tegnet.
      const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
      const funn = res.violations.flatMap((v) => v.nodes.map(
        (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
      ))
      expect(funn, `\n${sti}\n${funn.join('\n')}\n`).toEqual([])
    })
  }

  test('ingen emoji baerer mening paa flata', async ({ page }) => {
    // Emoji har sine egne farger, oversettes ikke med resten av
    // grensesnittet, og leses ulikt av skjermlesere. Nettbrettet hadde
    // 24 av dem. Merkelappen brukeren selv velger paa /merker er
    // brukerinnhold og staar i et attributt, ikke i teksten.
    const funn: string[] = []
    for (const sti of RUTENE) {
      await paaFlata(page, sti)
      const tekst = await page.locator('body').innerText()
      for (const e of tekst.match(EMOJI) ?? []) funn.push(`${sti}: ${e}`)
    }
    expect(funn, `Emoji paa nettbrettet:\n  ${funn.join('\n  ')}`).toEqual([])
  })
})

// ---------------------------------------------------------------------
// 4. ARBEIDSFLYT: fra «hva skal jeg gjore» til gjort
// ---------------------------------------------------------------------
test.describe('IK-mat: koen, ikke regnearket', () => {
  test.describe.configure({ mode: 'serial' })

  test('koen sier hva som gjenstaar, gruppert slik hun jobber', async ({ page }) => {
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/ikmat')

    // Fem punkter, ingen maalt.
    await expect(page.locator('.tablet-hode h1')).toContainText('5 igjen')

    // EN RAD PER GRUPPE, ikke en rad per punkt. Det er skillet mellom en
    // koe og et regneark: hun gaar til kjolerommet en gang, ikke tre.
    const grupper = page.locator('.ikmat-rutine')
    await expect(grupper).toHaveCount(2)
    await expect(grupper.first()).toContainText('0/3')
    await expect(grupper.last()).toContainText('0/2')

    // Og det skal IKKE finnes en maaletabell her lenger.
    expect(await page.locator('table').count(), 'Regnearket er tilbake').toBe(0)
  })

  test('raden foerer til maalingen, og maalingen teller ned', async ({ page }) => {
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/ikmat')

    await page.locator('.ikmat-rutine', { hasText: 'Daglig' }).first()
      .getByRole('link').click()
    await expect(page).toHaveURL(/\/ikmat\/maaling/)
    await expect(page.locator('body')).toContainText('Kjoledisk pakkemat')

    // Maal en enhet. Kravet er under 4 grader; 3 er innenfor.
    const rad = page.locator('.maaling-rad', { hasText: 'Kjoledisk pakkemat' }).first()
    await rad.getByRole('textbox').fill('3')
    await rad.getByRole('button', { name: 'Lagre' }).click()
    await expect(rad).toContainText('3', { timeout: 15_000 })

    // Tilbake i koen skal tallet ha falt. Uten dette beviser ingenting
    // av det over at maalingen faktisk ble lagret.
    await paaFlata(page, '/ikmat')
    await expect(page.locator('.tablet-hode h1')).toContainText('4 igjen')
    await expect(page.locator('.ikmat-rutine', { hasText: 'Daglig' }).first())
      .toContainText('1/3')
  })
})

// ---------------------------------------------------------------------
// 5. DEN TOMME BUTIKKEN
// ---------------------------------------------------------------------
test.describe('nettbrettet i en butikk uten oppsett', () => {
  test('sier at det ikke er satt opp, i stedet for aa staa tomt', async ({ page }) => {
    await loggInn(page, TOMT)
    await paaFlata(page, '/ikmat')
    await expect(page.locator('body')).toContainText(/Ingen kontrollpunkter/i)
  })

  test('hjem staar seg uten data', async ({ page }) => {
    await loggInn(page, TOMT)
    await paaFlata(page, '/oversikt')
    const overskrifter = await page.evaluate(() => [...document.querySelectorAll('h1, h2, h3')]
      .map((e) => (e.textContent ?? '').trim()).filter(Boolean))
    expect(overskrifter.length, 'Nettbrettets hjem er tomt').toBeGreaterThan(0)
  })
})
