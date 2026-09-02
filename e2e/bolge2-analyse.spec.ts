import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 2: analysefamilien.
//
// Aatte ruter som alle svarer paa «hva skjedde, er det bra, hvorfor».
// Denne fila maaler at de bruker det SAMME analytiske spraaket - ikke at
// de ser like ut, for aerendet er ulikt fra rute til rute.
//
// TO AV DEM MAALES PAA EKTE TALL. /timesalg og /kasserer fikk
// deterministisk fixture i denne bolgen (port 0), saa de kan verifiseres
// med data og ikke bare i tomtilstand. Tallene under faller ut av
// produksjonsberegningen; ingenting er mocket.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }
const UNDERBY = '44444444-4444-4444-8444-111111111111'

/**
 * Rutene i bolgen som TESTBRUKEREN naar.
 *
 * /dekning og /analyse staar utenfor lista: de er eierens (roller [A] i
 * navigasjonen), og seeden har ingen eier - eierrollen tvinges gjennom
 * TOTP og trenger en seedet faktor. Det er notert i seed.sql fra
 * stemplingsrunden, og gjelder fortsatt.
 */
const FAMILIEN = [
  '/salg',
  '/timesalg',
  '/kasserer',
  '/rutiner/oversikt',
  '/salgsprognose',
  '/produksjonsplan/treffsikkerhet',
]

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

const sifre = (s: string | null) => (s ?? '').replace(/\D/g, '')

const nokkeltall = (page: Page, merkelapp: string | RegExp) =>
  page.locator('.sq-nokkeltall').filter({
    has: typeof merkelapp === 'string'
      ? page.getByText(merkelapp, { exact: true })
      : page.getByText(merkelapp),
  })

test.describe('bolge 2 - analysefamilien', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const sti of FAMILIEN) {
    test(`${sti} bruker familiens spraak`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))

      const svar = await page.goto(sti)
      expect(svar?.status()).toBeLessThan(400)
      await expect(page.locator('.sq-sidehode h1')).toHaveCount(1)

      // De to handskrevne systemene skal vaere borte fra hele bolgen.
      // To sett som ser NESTEN like ut er dyrere enn ett som ser
      // annerledes ut.
      expect(await page.locator('.status-pip').count(), `${sti}: gammel status-pip`).toBe(0)
      expect(await page.locator('.kpi').count(), `${sti}: gammelt kpi-kort`).toBe(0)

      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })

    test(`${sti} har ingen axe-brudd`, async ({ page }) => {
      await page.goto(sti)
      const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
      const funn = res.violations.flatMap((v) => v.nodes.map(
        (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
      ))
      expect(funn, `\n${sti}\n${funn.join('\n')}\n`).toEqual([])
    })
  }

  // -------------------------------------------------------------------
  // EKTE TALL
  // -------------------------------------------------------------------
  test('/timesalg viser doegnrytmen fra fixturen', async ({ page }) => {
    await page.goto(`/timesalg?stasjon=${UNDERBY}`)

    // 1000 + 3000 + 12000 + 6000 + 3000 = 25000, topp kl. 11-12.
    const topp = nokkeltall(page, 'Travleste time')
    await expect(topp.locator('.sq-nokkeltall-verdi')).toContainText('11-12')
    await expect(topp).toContainText('12 000')

    const dagen = nokkeltall(page, 'Hele dagen')
    expect(sifre(await dagen.locator('.sq-nokkeltall-verdi').textContent())).toBe('25000')
    await expect(dagen).toContainText('5 timer med salg')
  })

  // -------------------------------------------------------------------
  // /kasserer - volum og sammensetning, ikke folk mot hverandre
  //
  // DEN GAMLE TESTEN MAALTE EN GRENSE SOM IKKE FANTES. Den sjekket at
  // 2,5 % avvik ga roed dom mot grensa paa 2 %. Sonden mot produksjon
  // 2026-08-24 maalte den grensa: den ville felt 771 av 775
  // kasserermaaneder. En grense som feller alt er ikke en grense.
  //
  // Underby, mars 2026 (uten systemnummeret):
  //   bonger      600 + 300 + 100          = 1 000
  //   makulert    800
  //   retur       1 200
  //   slettet     500
  //   per 100     2 500 / 1 000 * 100      =   250 kr
  //   Kari alene  2 500 /   600 * 100      =   417 kr
  // -------------------------------------------------------------------
  test('/kasserer - makulert staar foerst, fordi det ER stoerst', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)

    // Summeres de tre til ett tall, skjuler det store at de to andre er
    // smaa - og forholdet mellom dem er hele poenget.
    const mak = nokkeltall(page, 'Makulert')
    expect(sifre(await mak.locator('.sq-nokkeltall-verdi').textContent())).toBe('800')

    const rs = nokkeltall(page, 'Retur og slettet')
    expect(sifre(await rs.locator('.sq-nokkeltall-verdi').textContent())).toBe('1700')
    await expect(rs).toContainText('retur')

    const per100 = nokkeltall(page, 'Per 100 bonger')
    expect(sifre(await per100.locator('.sq-nokkeltall-verdi').textContent())).toBe('250')

    // RETNING OG DOM PEKER HVER SIN VEI. Februar var 60, mars er 250:
    // pila peker opp, og opp er daarlig her. En komponent som antar
    // boerslogikk ville vist dette som en god nyhet.
    const mot = per100.locator('.sq-nokkeltall-mot')
    await expect(mot).toContainText('↑')
    await expect(mot).toHaveClass(/darlig/)
    await expect(mot).not.toHaveClass(/god/)
  })

  test('/kasserer - ingen rangering, og siden sier hvorfor', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)

    // Sortert paa NUMMER. Kari har alt avviket og skal likevel ikke
    // staa oeverst fordi hun har det - hun staar oeverst fordi 101 er
    // lavest. En liste sortert paa avvik er en mistenktliste.
    const t = page.locator('.sq-datatabell').filter({
      has: page.getByRole('heading', { name: /Underby/ }),
    })
    const rader = t.locator('tbody tr')
    await expect(rader).toHaveCount(3)
    await expect(rader.nth(0)).toContainText('101')
    await expect(rader.nth(1)).toContainText('102')
    await expect(rader.nth(2)).toContainText('103')

    // Kari: 2 500 / 600 * 100 = 417 kr per 100 bonger.
    expect(sifre(await rader.nth(0).locator('td').nth(6).textContent())).toBe('417')
    // KJERNEN I SIDA, MAALT: Kari maales mot SEG SELV, ikke mot Ola og
    // Nina. Februar: 600 avvik / 600 bonger = 100. Mars: 417.
    // 417 - 100 = +317.
    expect(sifre(await rader.nth(0).locator('td').nth(7).textContent())).toBe('317')
    await expect(rader.nth(0).locator('td').nth(7)).toContainText('+')

    // Ola og Nina hadde null avvik begge maaneder - da er 0 et svar, og
    // «ingen historikk» ville vaert feil.
    expect(sifre(await rader.nth(1).locator('td').nth(7).textContent())).toBe('0')

    // Begrunnelsen skal staa paa sida, ikke bare i en commit-melding.
    const hvorfor = page.locator('details.sq-forklaring')
      .filter({ hasText: /Hvorfor rangeres ikke/i })
    await expect(hvorfor).toHaveCount(1)
    // Selve funnet, ikke bare overskriften: uten denne kunne teksten
    // blitt til en unnskyldning for at siden mangler noe.
    await expect(hvorfor).toContainText(/fra måned til måned/i)
    await expect(hvorfor).toContainText(/sortert på kassanummer/i)
  })

  test('/kasserer - kassa selv staar for seg, hverken slettet eller blandet inn', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)

    // 999999 er ikke en medarbeider. Blandes den inn, faar kassa skylda
    // til en person; slettes den i stillhet, ser stasjonens volum
    // lavere ut enn det er.
    const kassa = page.locator('.sq-datatabell').filter({
      has: page.getByRole('heading', { name: 'Kassa selv' }),
    })
    await expect(kassa.locator('tbody tr')).toHaveCount(1)
    await expect(kassa.locator('tbody tr').first()).toContainText('999999')
    expect(sifre(await kassa.locator('tbody tr').first().locator('td').nth(1).textContent()))
      .toBe('500')

    // ...og den staar IKKE blant folkene.
    const folk = page.locator('.sq-datatabell').filter({
      has: page.getByRole('heading', { name: /Underby/ }),
    })
    await expect(folk).not.toContainText('999999')

    // 500 av 1500 bonger = 33 %.
    await expect(page.locator('details.sq-forklaring')
      .filter({ hasText: /Hva er .kassa selv/i })).toContainText('33 %')
  })

  test('/kasserer - maanedsvelgeren er felles, og den gamle grensa er borte', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)

    // SAMME KONTROLL SOM PAA /svinn, /bemanning og /lonn: synlig
    // etikett «Maaned», ISO-verdi, knappen heter «Vis maaneden».
    await expect(page.getByRole('combobox', { name: 'Måned' })).toBeVisible()
    await expect(page.getByRole('combobox', { name: 'Måned' }))
      .toHaveValue('2026-03-01')
    await expect(page.getByRole('button', { name: 'Vis måneden' })).toBeVisible()

    // TEXTCONTENT, IKKE INNERTEXT. En NEGATIV paastand paa `innerText`
    // kan ikke skille «finnes ikke» fra «er skjult» - `innerText` gir
    // bare RENDRET tekst. `toContainText` leser `textContent` og ser
    // ogsaa det som ligger i DOM-en uten aa vaere synlig, og er derfor
    // den strengere paastanden her. Se AGENTS.md.
    //
    // KANARIFUGL: den positive foerst. Uten den ville begge paastandene
    // under bestaatt hvis `main` ikke fantes i det hele tatt.
    const hoved = page.locator('main')
    await expect(hoved, 'Fant ikke sida - da beviser paastandene under ingenting')
      .toContainText('Kasserer')
    await expect(hoved).not.toContainText('% av omsetningen')
    await expect(hoved).not.toContainText('Retur, makulert og slettet')
  })

  test('kassereroppgjoret staar som sammenligningsmatrise', async ({ page }) => {
    await page.goto(`/kasserer?stasjon=${UNDERBY}`)
    const t = page.locator('.sq-datatabell').filter({
      has: page.getByRole('heading', { name: /Underby/ }),
    })
    await expect(t).toBeVisible()
    // De tre avvikstypene bortover, kassererne nedover. Typene staar
    // hver for seg fordi makulert er 71-83 % av kronene i produksjon -
    // en sum ville skjult de to andre.
    await expect(t.locator('thead th')).toHaveText(
      ['Nummer', 'Navn', 'Bonger', 'Makulert', 'Retur', 'Slettet',
       'Per 100 bonger', 'Mot eget snitt'])
    await expect(t.locator('tbody tr')).toHaveCount(3)
    await expect(t.locator('tbody tr').first()).toContainText('Kari Kasserer')
  })

  test('INGEN TILSTAND FINNES BARE SOM FARGE', async ({ page }) => {
    // Regelen fra /fokus i bolge 1, gjort til en maaling for hele
    // analysesystemet: hvert statusmerke maa ha lesbar tekst i seg.
    for (const sti of [`/kasserer?stasjon=${UNDERBY}`, '/rutiner/oversikt']) {
      await page.goto(sti)
      const tomme = await page.locator('.sq-status').evaluateAll(
        (noder) => noder
          .map((n) => (n.textContent ?? '').trim())
          .filter((t) => t.length === 0),
      )
      expect(tomme, `${sti}: statusmerke uten tekst - fargen baerer alene`).toEqual([])
    }
  })

  test('treffomraadene holder maal i hele familien', async ({ page }) => {
    for (const sti of FAMILIEN) {
      await page.goto(sti)
      const smaa = await page.evaluate(() => {
        const ut: string[] = []
        for (const el of document.querySelectorAll('button, a[href], input, select')) {
          const r = el.getBoundingClientRect()
          if (r.width === 0 && r.height === 0) continue
          if (getComputedStyle(el).display === 'inline') continue
          if (r.height < 24 || r.width < 24) {
            ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 24)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
          }
        }
        return ut
      })
      expect(smaa, `For smaa paa ${sti}:\n  ${smaa.join('\n  ')}\n`).toEqual([])
    }
  })
})
