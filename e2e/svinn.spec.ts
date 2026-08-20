import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// /svinn - analysemonsteret, maalt paa ekte tall.
//
// TO KJEDER, TO PRODUKTTILSTANDER, SAMTIDIG.
//
// Testkjeden har ingen svinndata og gir tomtilstanden. Analysekjeden har
// en deterministisk fixture og gir analysesida. Begge er ekte tilstander,
// og skillet gaar gjennom RLS - altsaa den samme mekanismen som skiller
// to ekte kunder. Tomtilstandstesten er derfor ogsaa en isolasjonstest.
//
// TALLENE UNDER ER IKKE VALGT AV TESTEN. De faller ut av fixturen i
// supabase/seed.sql gjennom produksjonsberegningen: `matsalg_vindu_sum`
// over `v_salg_per_stasjon_dag` (avdeling 120), `svinn_vindu_sum` over
// `synlig_svinn`, terskel per stasjon i sida, og `motNormalen` for
// sammenligningen. Ingenting er mocket, og ingen terskel er rort.
//
//   Underby  5101   2000 / 100000 = 2,0 %  <= 2,5           under terskel
//   Grenseby 5102   2800 / 100000 = 2,8 %  > 2,5, <= 3,125  like over
//   Overby   5103   4000 / 100000 = 4,0 %  > 3,125          godt over
//   Kjeden          8800 mot median 4400   = +100,0 %       pil opp, roed dom
//
// Endres fixturen, skal disse testene feile. Det er meningen: da er det
// ikke lenger de samme tilstandene som maales.
// =====================================================================

const TOM = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }
const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

async function loggInn(page: Page, bruker: { epost: string; passord: string }) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', bruker.epost)
  await page.fill('input[name="passord"]', bruker.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** «8 800 kr» -> «8800». nb-NO skiller tusener med et tegn som ikke er
 *  mellomrom, og som varierer med ICU-versjon. Sifrene varierer ikke. */
const sifre = (s: string | null) => (s ?? '').replace(/\D/g, '')

/** Tabellen med denne overskriften. Datatabell rendrer tittelen som h3. */
const tabell = (page: Page, tittel: string | RegExp) =>
  page.locator('.sq-datatabell').filter({
    has: page.getByRole('heading', { name: tittel }),
  })

// ---------------------------------------------------------------------
// TOM TILSTAND - Testkjeden
// ---------------------------------------------------------------------
test.describe('/svinn uten data', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, TOM)
    await page.goto('/svinn')
  })

  test('tomtilstanden vises, og den peker videre', async ({ page }) => {
    await expect(page.locator('h1')).toHaveText('Synlig svinn')
    // En tom skjerm som bare sier «ingen data» lar brukeren staa fast.
    await expect(page.locator('.sq-tom')).toBeVisible()
    await expect(page.locator('.sq-tom')).toContainText(/Varetransaksjonsliste/i)
    await expect(page.getByRole('link', { name: /Import/i })).toBeVisible()
  })

  test('ser ikke den andre kjedens tall', async ({ page }) => {
    // Fixturen ligger i en annen kjede. Kommer den til syne her, er det
    // ikke en testfeil - det er RLS som lekker mellom kunder.
    const tekst = await page.locator('body').innerText()
    expect(tekst).not.toContain('Overby')
    expect(tekst).not.toContain('5103')
  })

  test('feil rolle faar ikke tilgang', async ({ page, context }) => {
    await context.clearCookies()
    await loggInn(page, {
      epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026',
    })
    await page.goto('/svinn')
    await expect(page.locator('body')).toContainText(
      /ikke tilgang til svinn|Ingen tilgang|logg inn/i)
  })
})

// ---------------------------------------------------------------------
// MED DATA - Analysekjeden
// ---------------------------------------------------------------------
test.describe('/svinn med data', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto('/svinn')
  })

  test('A - sida rendrer de seedede tallene', async ({ page }) => {
    const feil: string[] = []
    page.on('pageerror', (e) => feil.push(e.message))

    await expect(page.locator('h1')).toHaveText('Synlig svinn')
    await expect(page.locator('.sq-tom')).toHaveCount(0)

    const total = page.locator('.sq-nokkeltall')
      .filter({ hasText: 'Synlig svinn totalt' })
    expect(sifre(await total.locator('.sq-nokkeltall-verdi').textContent()))
      .toBe('8800')

    const enheter = page.locator('.sq-nokkeltall').filter({ hasText: 'Antall enheter' })
    // 12 + 8 + 18 + 10 + 25 + 15 = 88 enheter paa maaledagen.
    expect(sifre(await enheter.locator('.sq-nokkeltall-verdi').textContent()))
      .toBe('88')
    await expect(enheter).toContainText('fordelt paa 6 varer')

    expect(feil, `Klientfeil:\n  ${feil.join('\n  ')}`).toEqual([])
  })

  test('B - alle tre terskeltilstandene vises, hver paa sin stasjon', async ({ page }) => {
    const t = tabell(page, /Svinn mot terskel/)
    await expect(t).toBeVisible()

    // Prosenten er regnet av produksjonskoden, ikke av testen. Star det
    // noe annet her, har enten fixturen eller beregningen flyttet seg.
    const rad = (nr: string) => t.locator('tbody tr').filter({ hasText: nr })
    await expect(rad('5101')).toContainText('2.0 %')
    await expect(rad('5102')).toContainText('2.8 %')
    await expect(rad('5103')).toContainText('4.0 %')

    // Status, ikke farge: teksten skal kunne leses av en som ikke ser
    // fargen i det hele tatt.
    await expect(rad('5101').locator('.sq-status')).toHaveText('Under terskel')
    await expect(rad('5102').locator('.sq-status')).toHaveText('Like over terskel')
    await expect(rad('5103').locator('.sq-status')).toHaveText('Godt over terskel')

    // ROLIG SOM STANDARD. Stasjonen som ligger der den skal, faar ingen
    // farge - «i orden» er utgangspunktet, ikke en god nyhet.
    await expect(rad('5101').locator('.sq-status')).toHaveClass(/sq-status-normal/)
    await expect(rad('5102').locator('.sq-status')).toHaveClass(/sq-status-endring/)
    await expect(rad('5103').locator('.sq-status')).toHaveClass(/sq-status-handling/)

    // Den gamle pipen skal vaere borte fra hele sida.
    expect(await page.locator('.status-pip').count(),
      'Gammel status-pip henger igjen').toBe(0)
  })

  test('B2 - terskelen som staar i basen er den som vises', async ({ page }) => {
    // Uten denne kunne terskelkolonnen vaert hardkodet i sida og testen
    // over fortsatt vaert groenn.
    const t = tabell(page, /Svinn mot terskel/)
    for (const nr of ['5101', '5102', '5103']) {
      await expect(t.locator('tbody tr').filter({ hasText: nr })).toContainText('2.5 %')
    }
  })

  test('C - tabellene har forventet struktur og data', async ({ page }) => {
    const terskel = tabell(page, /Svinn mot terskel/)
    await expect(terskel.locator('tbody tr')).toHaveCount(3)
    await expect(terskel.locator('thead th')).toHaveText(
      ['Stasjon', 'Svinn %', 'Terskel', 'Status'])

    // Per stasjon: sortert paa kroner, storst forst.
    const perStasjon = tabell(page, /Per stasjon/)
    await expect(perStasjon.locator('tbody tr')).toHaveCount(3)
    const rader = perStasjon.locator('tbody tr')
    await expect(rader.nth(0)).toContainText('Overby')
    await expect(rader.nth(2)).toContainText('Underby')
    expect(sifre(await rader.nth(0).locator('td').nth(1).textContent())).toBe('4000')
    expect(sifre(await rader.nth(2).locator('td').nth(1).textContent())).toBe('2000')

    // Mest svinn: seks varelinjer med ulike belop, saa rekkefolgen er
    // entydig og testen ikke kan bli flaky paa uavgjort sortering.
    const varer = tabell(page, /Mest svinn/)
    await expect(varer.locator('tbody tr')).toHaveCount(6)
    await expect(varer.locator('tbody tr').nth(0)).toContainText('Grillpolse')
    expect(sifre(await varer.locator('tbody tr').nth(0).locator('td').nth(1).textContent()))
      .toBe('2500')
    await expect(varer.locator('tbody tr').nth(5)).toContainText('Kaffe filter')
  })

  test('RETNING OG DOM PEKER HVER SIN VEI', async ({ page }) => {
    // Dette er hele poenget med at Nokkeltall skiller `retning` fra `bra`.
    //
    // Svinnet er DOBLET mot en vanlig tirsdag. Bevegelsen er opp, og
    // vurderingen er negativ. En komponent som antar borslogikk - opp er
    // gronn, ned er rod - vil vise dette som en god nyhet, og da lyver
    // sida om et tall den har helt riktig.
    const mot = page.locator('.sq-nokkeltall')
      .filter({ hasText: 'Synlig svinn totalt' })
      .locator('.sq-nokkeltall-mot')

    await expect(mot).toContainText('100,0 % mot en vanlig tirsdag')

    // Retningen: pilen peker opp.
    await expect(mot).toContainText('↑')

    // Dommen: negativ. De to er atskilt med vilje, og testen sjekker dem
    // hver for seg nettopp derfor.
    await expect(mot).toHaveClass(/darlig/)
    await expect(mot).not.toHaveClass(/god/)
  })

  test('forklaringen er lukket til noen spor', async ({ page }) => {
    // Nivaa 4: metoden skal vaere tilgjengelig, ikke i veien. Staar den
    // aapen, moter brukeren regnestykket for svaret.
    const f = page.locator('details.sq-forklaring').first()
    await expect(f).toBeVisible()
    expect(await f.evaluate((e: HTMLDetailsElement) => e.open),
      'Forklaringen staar aapen og skygger for svaret').toBe(false)
  })

  test('D - ingen axe-brudd paa analysesida, med kontrast', async ({ page }) => {
    // Kjorer paa flata MED data. Tomtilstanden har hverken tabeller,
    // statusmerker eller nokkeltall - det er de tre som faktisk kan ha
    // kontrastproblemer.
    await expect(page.locator('.sq-datatabell').first()).toBeVisible()
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('E - sida flyter ikke ut i bredden paa desktop', async ({ page }) => {
    // Ikke et bildesammenligningssystem - bare det maalet som faktisk
    // knekker en analyseside: en tabell som skyver hele sida sidelengs.
    // Tabellen skal rulle inni sin egen ramme.
    for (const bredde of [1280, 1440]) {
      await page.setViewportSize({ width: bredde, height: 900 })
      await expect(page.locator('.sq-datatabell').first()).toBeVisible()
      const sol = await page.evaluate(() => ({
        scroll: document.documentElement.scrollWidth,
        klient: document.documentElement.clientWidth,
      }))
      expect(sol.scroll, `Vannrett rulling paa ${bredde}px`)
        .toBeLessThanOrEqual(sol.klient + 1)
    }
  })

  test('treffomraadene holder maal paa analysesida', async ({ page }) => {
    const smaa = await page.evaluate(() => {
      const ut: string[] = []
      for (const el of document.querySelectorAll('button, a[href], input, select')) {
        const r = el.getBoundingClientRect()
        if (r.width === 0 && r.height === 0) continue
        if (getComputedStyle(el).display === 'inline') continue
        // WCAG 2.2 AA: 24x24 er minstekravet paa peker-flater.
        if (r.height < 24 || r.width < 24) {
          ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 24)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
        }
      }
      return ut
    })
    expect(smaa, `For smaa:\n  ${smaa.join('\n  ')}\n`).toEqual([])
  })
})
