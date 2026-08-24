import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// /svinn - kost mot kost, maalt paa ekte tall.
//
// DEN GAMLE PROSENTEN VAR FAGLIG UGYLDIG: alt svinn (kostpris) delt paa
// matsalget alene (omsetning). Feil omfang og feil enhet i samme brook.
// Den nye er svinn til kostpris delt paa varekost av solgte varer, per
// stasjon, varegruppe og maaned. Terskeltabellen som hvilte paa den
// gamle prosenten er derfor borte, og testen som maalte den med den.
//
// TO KJEDER, TO PRODUKTTILSTANDER, SAMTIDIG.
//
// Testkjeden har ingen svinndata og gir tomtilstanden. Analysekjeden har
// en deterministisk fixture og gir analysesida. Skillet gaar gjennom
// RLS - den samme mekanismen som skiller to ekte kunder - saa
// tomtilstandstesten er ogsaa en isolasjonstest.
//
// TALLENE UNDER ER IKKE VALGT AV TESTEN. De faller ut av fixturen i
// supabase/seed.sql gjennom produksjonsberegningen i
// `src/lib/svinn/maaned.ts` og viewene i `0129_svinn_maaned.sql`.
//
// MARS 2026, ANALYSEKJEDEN:
//
//   Underby  5101   2 000 ikke koblet + 10 000 koblet = 12 000 kr
//   Grenseby 5102   2 800 ikke koblet                 =  2 800 kr
//   Overby   5103   4 000 ikke koblet                 =  4 000 kr
//   Kjeden                                            = 18 800 kr
//
//   Varekost solgt: 500 000 - 300 000 = 200 000 (varegruppe 1290, Underby)
//   Alle andre mars-rader i `daglig_salg` har varegruppe_kode = null og
//   teller derfor ikke i nevneren.
//
//   1290 FERSKVARER  10 000 / 200 000 = 5,0 %
//   Underby samlet   12 000 / 200 000 = 6,0 %   83 % kategorisert
//   Kjeden samlet    18 800 / 200 000 = 9,4 %   53 % kategorisert
//   Overby           ingen varekost             ikke maalbart
//
// JANUAR OG FEBRUAR 2026 har sin egen svinn-baseline: fire tirsdager
// med kjedesum 4 400 hver (2026-01-20, -01-27, -02-03, -02-10). To
// tirsdager i hver maaned gir 8 800 kr per maaned, alle ukoblede.
//
// Nevneren i de to maanedene er produksjonsfixturen (1201/1216), som
// gaar 5. januar til 1. februar med varekost 600 kr per dag:
//
//   januar   27 dager x 600 = 16 200   ->  8 800 / 16 200 =    54,3 %
//   februar   1 dag  x 600  =    600   ->  8 800 /    600 = 1 466,7 %
//
// Februartallet ser vilt ut, og det er riktig av det: én dag med salg
// er ikke en nevner man kan si noe om. Sida viser det den har.
//
// Endres fixturen, skal disse testene feile. Det er meningen.
// =====================================================================

const TOM = { epost: 'butikksjef@test.sentiqa.no', passord: 'test-butikksjef-2026' }
const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

const UNDERBY = '44444444-4444-4444-8444-111111111111'   // 5101
const OVERBY = '44444444-4444-4444-8444-333333333333'    // 5103

const MARS = '2026-03-01'

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

const nokkeltall = (page: Page, merkelapp: string) =>
  page.locator('.sq-nokkeltall').filter({ hasText: merkelapp })

// ---------------------------------------------------------------------
// TOM TILSTAND - Testkjeden
// ---------------------------------------------------------------------
test.describe('/svinn uten data', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, TOM)
    await page.goto('/svinn')
  })

  test('tomtilstanden vises, og den peker videre', async ({ page }) => {
    await expect(page.locator('h1')).toHaveText('Svinn')
    // En tom skjerm som bare sier «ingen data» lar brukeren staa fast.
    await expect(page.locator('.sq-tom')).toBeVisible()
    await expect(page.locator('.sq-tom')).toContainText(/Varetransaksjonsliste/i)
    await expect(page.getByRole('link', { name: /import/i })).toBeVisible()
  })

  test('en tom kjede faar ingen prosent, heller ikke 0 %', async ({ page }) => {
    // Uten data finnes ingen nevner. En «0,0 %» her ville vaert en
    // paastand om at det ikke svinner noe - og den har systemet ikke
    // dekning for.
    //
    // VENT PAA TOMTILSTANDEN FOERST. Leses `main` mens den fortsatt
    // sier «Laster …», bestaar paastanden fordi det ikke staar noe -
    // og en test som maaler tomheten sin egen ventetid beviser
    // ingenting.
    await expect(page.locator('.sq-tom')).toBeVisible()
    const tekst = await page.locator('main').innerText()
    expect(tekst).not.toMatch(/\d[,.]\d\s*%/)
  })

  test('ser ikke den andre kjedens tall', async ({ page }) => {
    // Fixturen ligger i en annen kjede. Kommer den til syne her, er det
    // ikke en testfeil - det er RLS som lekker mellom kunder.
    await expect(page.locator('.sq-tom')).toBeVisible()
    const tekst = await page.locator('body').innerText()
    expect(tekst).not.toContain('Overby')
    expect(tekst).not.toContain('5103')
    expect(tekst).not.toContain('Grovbrod')
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
// KJEDEN SAMLET - Analysekjeden, alle tre stasjonene
// ---------------------------------------------------------------------
test.describe('/svinn med data - hele kjeden', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(`/svinn?stasjon=alle&maned=${MARS}`)
  })

  test('A - kronene stemmer, og prosenten er kost mot kost', async ({ page }) => {
    const feil: string[] = []
    page.on('pageerror', (e) => feil.push(e.message))

    await expect(page.locator('h1')).toHaveText('Svinn')
    await expect(page.locator('.sq-tom')).toHaveCount(0)

    // 8 800 fra de seks ukoblede varene + 10 000 fra den koblede.
    const total = nokkeltall(page, 'Svinn totalt')
    expect(sifre(await total.locator('.sq-nokkeltall-verdi').textContent()))
      .toBe('18800')

    // 18 800 / 200 000. Nevneren er varekost, ikke omsetning - regnes
    // det mot omsetning igjen, blir tallet 3,8 % og testen roed.
    const andel = nokkeltall(page, 'Av varekost solgt')
    await expect(andel.locator('.sq-nokkeltall-verdi')).toHaveText('9,4 %')
    await expect(andel).toContainText('svinn til kostpris / varekost solgt')

    expect(feil, `Klientfeil:\n  ${feil.join('\n  ')}`).toEqual([])
  })

  test('B - ukoblet svinn blir i totalen, og sier fra om seg selv', async ({ page }) => {
    // 8 800 av 18 800 kroner har ingen salgsmotpart. Kastes de ut, ser
    // kjeden ut til aa svinne 10 000 - feil i den ene retningen ingen
    // oppdager. De skal staa i totalen OG ha sin egen linje.
    const kategorisert = nokkeltall(page, 'Kategorisert')
    await expect(kategorisert.locator('.sq-nokkeltall-verdi')).toHaveText('53 %')
    expect(sifre(await kategorisert.locator('.sq-nokkeltall-mot').textContent()))
      .toBe('8800')

    const t = tabell(page, 'Svinn per varegruppe')
    const ukoblet = t.locator('tbody tr').filter({ hasText: 'Ikke koblet' })
    expect(sifre(await ukoblet.locator('td').nth(1).textContent())).toBe('8800')

    // INGEN PROSENT PAA DEN LINJA. Uten nevner finnes ingen andel, og
    // en «0,0 %» her ville sagt at de kronene ikke er et problem.
    await expect(ukoblet.locator('td').nth(4)).toHaveText('ikke målbart')
  })

  test('C - den koblede varegruppa faar en ekte prosent', async ({ page }) => {
    const t = tabell(page, 'Svinn per varegruppe')
    const rad = t.locator('tbody tr').filter({ hasText: 'FERSKVARER' })
    expect(sifre(await rad.locator('td').nth(1).textContent())).toBe('10000')
    expect(sifre(await rad.locator('td').nth(3).textContent())).toBe('200000')
    await expect(rad.locator('td').nth(4)).toHaveText('5,0 %')

    await expect(t.locator('thead th')).toHaveText(
      ['Varegruppe', 'Svinn', 'Antall', 'Varekost solgt', 'Svinn %'])
  })

  test('D - per stasjon, med samme brook som totalen', async ({ page }) => {
    const t = tabell(page, /Per stasjon/)
    const rader = t.locator('tbody tr')
    await expect(rader).toHaveCount(3)

    // Sortert paa kroner, storst forst.
    await expect(rader.nth(0)).toContainText('Underby')
    await expect(rader.nth(1)).toContainText('Overby')
    await expect(rader.nth(2)).toContainText('Grenseby')

    expect(sifre(await rader.nth(0).locator('td').nth(1).textContent())).toBe('12000')
    await expect(rader.nth(0).locator('td').nth(2)).toHaveText('6,0 %')

    // Overby har svinn, men ingen varekost aa maale det mot. Da finnes
    // ingen prosent - og «0,0 %» ville sagt at stasjonen er ren.
    expect(sifre(await rader.nth(1).locator('td').nth(1).textContent())).toBe('4000')
    await expect(rader.nth(1).locator('td').nth(2)).toHaveText('ikke målbart')
    expect(sifre(await rader.nth(1).locator('td').nth(3).textContent())).toBe('4000')
  })

  test('E - maaned for maaned regner hver maaned mot sin egen nevner', async ({ page }) => {
    // Hver rad har sin egen teller OG sin egen nevner. Deles alle
    // maanedene paa den samme nevneren, blir bare én av dem riktig -
    // og de to andre ser ut som utvikling.
    const t = tabell(page, 'Måned for måned')
    await expect(t.locator('tbody tr')).toHaveCount(3)

    const rad = (m: RegExp) => t.locator('tbody tr').filter({ hasText: m })

    expect(sifre(await rad(/mars 2026/i).locator('td').nth(1).textContent())).toBe('18800')
    expect(sifre(await rad(/mars 2026/i).locator('td').nth(2).textContent())).toBe('94')
    await expect(rad(/mars 2026/i).locator('td').nth(3)).toHaveText('1 av 31')

    // 8 800 / 16 200. Samme kroner som februar, helt annen prosent -
    // fordi nevneren er 27 salgsdager mot én.
    expect(sifre(await rad(/januar 2026/i).locator('td').nth(1).textContent())).toBe('8800')
    expect(sifre(await rad(/januar 2026/i).locator('td').nth(2).textContent())).toBe('543')
    await expect(rad(/januar 2026/i).locator('td').nth(3)).toHaveText('2 av 31')

    expect(sifre(await rad(/februar 2026/i).locator('td').nth(1).textContent())).toBe('8800')
    expect(sifre(await rad(/februar 2026/i).locator('td').nth(2).textContent())).toBe('14667')
    await expect(rad(/februar 2026/i).locator('td').nth(3)).toHaveText('2 av 28')
  })

  test('F - sammenligningen viser grunnlaget sitt, ogsaa naar den holder', async ({ page }) => {
    // Mars har 1 registrert dag, februar 2. Regelen maaler LIKHET
    // mellom grunnlagene, ikke om de er store nok - to daarlige
    // grunnlag er like. Da maa tallene staa der, saa leseren kan se
    // hva «omtrent likt» faktisk betyr her.
    const f = page.locator('details.sq-forklaring')
      .filter({ hasText: /Hvordan ligger dette mot/i })
    await expect(f).toHaveCount(1)
    await expect(f).toContainText(/1 av 31 mot 2 av 28 dager/)
    await expect(f).toContainText(/utviklingen kan leses/i)
  })

  test('G - dekningen staar ved siden av tallet', async ({ page }) => {
    const f = page.locator('details.sq-forklaring')
      .filter({ hasText: /Hvor godt er registreringsgrunnlaget/i })
    await expect(f).toHaveCount(1)
    await expect(f).toContainText(/1 av 31 dager/)
    // Sida skal ikke paastaa HVORFOR dagene er faa. Maten kastes hver
    // dag; faa foeringsdager er enten manglende foering eller flere
    // dager foert samlet, og de to ser like ut i datoen alene.
    await expect(f).toContainText(/ikke ble ført/i)
    await expect(f).toContainText(/ført samlet/i)
    await expect(f).not.toContainText(/tellerytme/i)

    // Nivaa 4: metoden skal vaere tilgjengelig, ikke i veien.
    expect(await f.first().evaluate((e: HTMLDetailsElement) => e.open),
      'Forklaringen staar aapen og skygger for svaret').toBe(false)
  })

  test('den gamle terskeltabellen er borte', async ({ page }) => {
    // Den hvilte paa den ugyldige prosenten. Blir den staaende, viser
    // sida to ulike svar paa det samme spoersmaalet.
    const tekst = await page.locator('main').innerText()
    expect(tekst).not.toMatch(/mot terskel/i)
    expect(tekst).not.toMatch(/Under terskel|Godt over terskel/i)
    expect(await page.locator('.status-pip').count(),
      'Gammel status-pip henger igjen').toBe(0)
  })
})

// ---------------------------------------------------------------------
// ÉN STASJON - innsnevring, ikke et annet regnestykke
// ---------------------------------------------------------------------
test.describe('/svinn med data - én stasjon', () => {
  test('Underby alene: 12 000 kr og 6,0 %', async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(`/svinn?stasjon=${UNDERBY}&maned=${MARS}`)

    expect(sifre(await nokkeltall(page, 'Svinn totalt')
      .locator('.sq-nokkeltall-verdi').textContent())).toBe('12000')
    await expect(nokkeltall(page, 'Av varekost solgt')
      .locator('.sq-nokkeltall-verdi')).toHaveText('6,0 %')
    await expect(nokkeltall(page, 'Kategorisert')
      .locator('.sq-nokkeltall-verdi')).toHaveText('83 %')

    // Per stasjon-tabellen hoerer ikke hjemme naar man ser paa én.
    await expect(tabell(page, /Per stasjon/)).toHaveCount(0)
  })

  test('Overby alene: kroner uten prosent', async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(`/svinn?stasjon=${OVERBY}&maned=${MARS}`)

    expect(sifre(await nokkeltall(page, 'Svinn totalt')
      .locator('.sq-nokkeltall-verdi').textContent())).toBe('4000')
    // Ingen varekost paa stasjonen i mars. Kronene er ekte, prosenten
    // finnes ikke - og skal ikke oppfinnes.
    await expect(nokkeltall(page, 'Av varekost solgt')
      .locator('.sq-nokkeltall-verdi')).toHaveText('ikke målbart')
    await expect(nokkeltall(page, 'Kategorisert')
      .locator('.sq-nokkeltall-verdi')).toHaveText('0 %')
  })

  test('varegruppa kan aapnes, og varelista foelger valget', async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(`/svinn?stasjon=${UNDERBY}&maned=${MARS}`)

    // Uten valgt gruppe skal topplista likevel vise varene.
    const alle = tabell(page, /Mest svinn/)
    await expect(alle.locator('tbody tr').first()).toBeVisible()

    await tabell(page, 'Svinn per varegruppe')
      .locator('tbody tr').filter({ hasText: 'Ikke koblet' })
      .getByRole('link').click()

    const t = tabell(page, /Mest svinn/)
    await expect(t.locator('h3')).toContainText(/Ikke koblet/i)
    // De to ukoblede varene paa Underby: 1 200 + 800.
    await expect(t.locator('tbody tr')).toHaveCount(2)
    expect(sifre(await t.locator('tbody tr').nth(0).locator('td').nth(1).textContent()))
      .toBe('1200')
    // Den koblede varen hoerer ikke hjemme under «ikke koblet».
    await expect(t).not.toContainText('Grovbrod')
  })

  test('butikksjefen ser bare sine egne stasjoner', async ({ page }) => {
    // `analyse@test.sentiqa.no` er butikksjef i Analysekjeden med tre
    // stasjoner. Grensa som maales her er ikke sidas - det er RLS-en:
    // Testkjedens stasjoner finnes i basen og skal ikke naas herfra,
    // uansett hva som staar i URL-en.
    await loggInn(page, DATA)

    // VENT PAA INNHOLDET, IKKE PAA NAVIGASJONEN. Sida streamer, og
    // `innerText` rett etter `goto` leser «Laster …» - en test som
    // maaler tomheten sin egen ventetid beviser ingenting.
    await page.goto(`/svinn?stasjon=${UNDERBY}&maned=${MARS}`)
    await expect(page.locator('.sq-nokkeltall').first()).toBeVisible()
    let tekst = await page.locator('main').innerText()
    expect(tekst).toContain('Underby')
    expect(tekst).not.toContain('Grenseby')
    expect(tekst).not.toContain('Overby')

    // «alle» er hele hans egen kjede - og ikke ett tegn mer. Testkjedens
    // stasjoner heter Testby (4177) og Testvik (9145).
    await page.goto(`/svinn?stasjon=alle&maned=${MARS}`)
    await expect(tabell(page, /Per stasjon/)).toBeVisible()
    tekst = await page.locator('main').innerText()
    expect(tekst).toContain('Grenseby')
    expect(tekst).not.toMatch(/Testby|Testvik|4177|9145/)
  })
})

// ---------------------------------------------------------------------
// FLATA SELV
// ---------------------------------------------------------------------
test.describe('/svinn - flata', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, DATA)
    await page.goto(`/svinn?stasjon=alle&maned=${MARS}`)
  })

  test('ingen axe-brudd paa analysesida, med kontrast', async ({ page }) => {
    await expect(page.locator('.sq-datatabell').first()).toBeVisible()
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })

  test('sida flyter ikke ut i bredden paa desktop', async ({ page }) => {
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

  test('maanedsvelgeren bytter maaned', async ({ page }) => {
    await page.selectOption('select[name="maned"]', '2026-01-01')
    await page.getByRole('button', { name: /Vis måneden/i }).click()
    await expect(page).toHaveURL(/maned=2026-01-01/)
    expect(sifre(await nokkeltall(page, 'Svinn totalt')
      .locator('.sq-nokkeltall-verdi').textContent())).toBe('8800')
  })
})
