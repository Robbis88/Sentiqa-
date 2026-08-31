import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// SIDERAMMEN — MÅLT, IKKE RESONNERT
//
// Bredden var ikke bestemt noe sted før dette. Den falt ut av om siden
// tilfeldigvis brukte `className="kort"`, siden `.innhold .kort` er den
// eneste breddereglen i systemet. Talt over alle 71 sider var bare ett av
// åtte mønstre entydig; se `SPALTE` i src/lib/redesign/monstre.ts.
//
// ---------------------------------------------------------------------
// «FØR» ER IKKE EN GAMMEL SKJERMDUMP — DET ER NABOSIDA
//
// De ikke-migrerte sidene kjører fortsatt den gamle mekanismen. Derfor
// måles hver migrert side mot en søsterside i samme mønster som ikke er
// rørt: er de like brede, har rammen bevart oppførselen i stedet for å
// finne på en ny. Det holder også etter at noen endrer standardbredden —
// et tall jeg skriver ned her ville ikke gjort det.
//
//   migrert                            søster (urørt)     forventning
//   /salg                    analyse   /timesalg          LIK bredde
//   /rutiner/oppsett   innstillinger   /persondata        LIK bredde
//   /produksjonsplan/treffsikkerhet    /salg              LIK — se under
//
// Den siste er pilotens eneste tilsiktede endring: 12 av 15 analysesider
// var allerede fullbredde, denne var en av de tre som ikke var det, fordi
// den brukte kort. Den kommer hjem til familien sin.
//
// ---------------------------------------------------------------------
// TILGJENGELIGHET MÅLES IKKE HER
//
// `/salg` dekkes av bolge2-analyse.spec.ts og `/rutiner/oppsett` av
// bolge4a.spec.ts — begge kjører axe på `main` allerede. En tredje axe-
// kjøring på samme innhold ville vært en andre fasit på samme spørsmål,
// og det er nettopp formen denne revisjonen skal fjerne. Blir rammen et
// tilgjengelighetsproblem, roper de testene.
// =====================================================================

const DATA = { epost: 'analyse@test.sentiqa.no', passord: 'test-analyse-2026' }

/** `.innhold .kort { max-width: 880px }` i globals.css — den gamle grensa. */
const SMAL = 880

async function loggInn(page: Page) {
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', DATA.epost)
  await page.fill('input[name="passord"]', DATA.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn/, { timeout: 15_000 })
}

/** Spalta på en MIGRERT side: rammen eier bredden, så rammen måles. */
async function rammebredde(page: Page): Promise<number> {
  const ramme = page.locator('.sq-sideramme')
  await expect(ramme, 'siden er ikke migrert til Sideramme').toHaveCount(1)
  await expect(ramme).toBeVisible()
  return (await ramme.boundingBox())!.width
}

/**
 * Spalta på en URØRT side — altså «før».
 *
 * Har sida kort, er 880 px-regelen i kraft og kortet ER spalta. Har den
 * ikke kort, er det ingenting som begrenser bredden, og spalta er alt
 * `.innhold` gir bort innenfor sin egen padding. To former, fordi det
 * nettopp var to former før rammen fantes.
 */
/**
 * Plassen `.innhold` faktisk gir bort, innenfor sin egen padding.
 *
 * Dette er fasiten en `bred` side skal fylle, og taket en `smal` side
 * ikke kan overstige. Den leses fra sida i stedet for å skrives ned her,
 * så tallet holder når sidemenyen eller paddingen endrer seg.
 */
function tilgjengelig(page: Page): Promise<number> {
  return page.evaluate(() => {
    const el = document.querySelector('main.innhold')!
    const s = getComputedStyle(el)
    return el.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight)
  })
}

/**
 * Beviser hele kjeden for én rute: rute → Monster → SPALTE → målt bredde.
 *
 * En `smal` side skal være nøyaktig 880 px, eller hele spalta hvis den er
 * trangere enn det. En `bred` side skal fylle spalta. Ingen søsterside er
 * involvert — påstanden er absolutt, og gjelder også for ruter der dagens
 * bredde var tilfeldig og SKAL endres.
 */
async function bevisBredde(page: Page, sti: string, ventet: 'smal' | 'bred') {
  await page.goto(sti)
  await expect(page.locator('main.innhold'), sti).toHaveAttribute('data-bredde', ventet)
  const rom = await tilgjengelig(page)
  const ramme = await rammebredde(page)
  const fasit = ventet === 'bred' ? rom : Math.min(SMAL, rom)
  expect(
    Math.abs(ramme - fasit),
    `${sti} (${ventet}): rammen er ${Math.round(ramme)} px, spalta gir ${Math.round(rom)} px, `
    + `fasit ${Math.round(fasit)} px`,
  ).toBeLessThan(2)
  return { ramme, rom }
}

async function gammelSpalte(page: Page): Promise<number> {
  const kort = page.locator('.innhold > .kort, .innhold .kort').first()
  if (await kort.count()) {
    await expect(kort).toBeVisible()
    return (await kort.boundingBox())!.width
  }
  return page.evaluate(() => {
    const el = document.querySelector('main.innhold')!
    const s = getComputedStyle(el)
    return el.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight)
  })
}

test.describe('sideramme — bredden følger mønsteret', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 1000 })
    await loggInn(page)
  })

  test('skallet merker sida med bredden mønsteret gir', async ({ page }) => {
    // Uten dette attributtet faller ALT tilbake til smal, og hver side
    // rendrer fortsatt fint. Derfor måles attributtet direkte, ikke bare
    // følgene av det.
    await page.goto('/salg')
    await expect(page.locator('main.innhold')).toHaveAttribute('data-bredde', 'bred')

    await page.goto('/persondata')
    await expect(page.locator('main.innhold')).toHaveAttribute('data-bredde', 'smal')
  })

  test('/salg beholder bredden til den urørte /timesalg', async ({ page }) => {
    await page.goto('/timesalg')
    const foer = await gammelSpalte(page)
    await page.goto('/salg')
    const etter = await rammebredde(page)

    expect(foer, 'forutsetning: /timesalg er fullbredde i dag').toBeGreaterThan(SMAL)
    expect(Math.abs(etter - foer)).toBeLessThan(2)
  })

  test('/rutiner/oppsett beholder bredden til den urørte /persondata', async ({ page }) => {
    await page.goto('/persondata')
    const foer = await gammelSpalte(page)
    await page.goto('/rutiner/oppsett')
    const etter = await rammebredde(page)

    expect(foer, 'forutsetning: /persondata er 880 px i dag').toBeLessThanOrEqual(SMAL)
    expect(Math.abs(etter - foer)).toBeLessThan(2)
  })

  test('/produksjonsplan/treffsikkerhet kommer hjem til analysefamilien', async ({ page }) => {
    await page.goto('/salg')
    const familien = await rammebredde(page)
    await page.goto('/produksjonsplan/treffsikkerhet')
    const naa = await rammebredde(page)

    expect(naa, 'den var 880 px fordi den brukte kort, ikke fordi noen mente det')
      .toBeGreaterThan(SMAL)
    expect(Math.abs(naa - familien)).toBeLessThan(2)
  })

  // -------------------------------------------------------------------
  // DE NYE MØNSTRENE MÅLES ABSOLUTT, IKKE MOT EN SØSTER
  //
  // For /salg og /rutiner/oppsett er påstanden «ingenting endret seg», og
  // da er nabosida riktig fasit. For /utsolgt og /ansatte er påstanden
  // den motsatte: dagens bredde var tilfeldig og SKAL endres. Da beviser
  // en søstersammenligning ingenting, og kjeden må måles for seg.
  //
  // Første utgave sammenlignet /ansatte mot /persondata og var rød med
  // 436 px avvik. Den sa ikke hvilket av de to tallene som var galt —
  // derfor står begge i meldinga nå.
  // -------------------------------------------------------------------

  test('/utsolgt: dataliste → bred → målt', async ({ page }) => {
    // 5 kolonner, og 880 px i dag bare fordi den brukte kort.
    await bevisBredde(page, '/utsolgt', 'bred')
  })

  test('/ansatte: liste → smal → målt', async ({ page }) => {
    // Fullbredde i dag — men uten en eneste kolonne. Bygget på `Rad`,
    // hvis slot-vokabular er enspaltet per konstruksjon.
    await bevisBredde(page, '/ansatte', 'smal')
  })

  test('de allerede migrerte holder sin egen kjede', async ({ page }) => {
    await bevisBredde(page, '/salg', 'bred')
    await bevisBredde(page, '/produksjonsplan/treffsikkerhet', 'bred')
    await bevisBredde(page, '/rutiner/oppsett', 'smal')
  })

  test('rammen holder seg innenfor spalta på liten skjerm', async ({ page }) => {
    // FØRSTE UTGAVE AV DENNE TESTEN MÅLTE FEIL TING, OG DEN FANT EN ANNENS FEIL
    //
    // Den målte `document.scrollWidth` og var rød på /salg med 129 px. Det
    // er en ekte feil, men den er ikke rammens: `Datatabell` rendrer
    // `<div className="tabellramme">` som scroll-container, og den divven
    // har ingen CSS-regel i det hele tatt. På mobil reddes kortbaserte
    // sider av `.kort { overflow-x: auto }` i globals.css; sider som
    // bruker `Datatabell` bart — som /salg — har ingen slik container.
    // Feilen er eldre enn piloten og ligger i `Datatabell`, ikke her.
    //
    // Rammens eget ansvar er smalere og måles derfor presist: den skal
    // aldri selv bli bredere enn spalta den fikk. Blir den det, er det
    // `max-width` uten `width: 100%`, eller flex-barn med `min-width:
    // auto` som drar den ut — begge deler ville vært rammens skyld.
    await page.setViewportSize({ width: 390, height: 844 })
    for (const sti of ['/salg', '/rutiner/oppsett', '/produksjonsplan/treffsikkerhet', '/utsolgt', '/ansatte']) {
      await page.goto(sti)
      await expect(page.locator('.sq-sideramme')).toBeVisible()
      const { ramme, spalte } = await page.evaluate(() => {
        const el = document.querySelector('main.innhold')!
        const s = getComputedStyle(el)
        return {
          ramme: document.querySelector('.sq-sideramme')!.getBoundingClientRect().width,
          spalte: el.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight),
        }
      })
      expect(ramme, `${sti}: rammen er bredere enn spalta den fikk`)
        .toBeLessThanOrEqual(spalte + 1)
    }
  })
})
