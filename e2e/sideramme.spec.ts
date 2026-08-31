import { test, expect, type Page } from '@playwright/test'
import { REDAKTOR_OKTFIL } from './eier'

// =====================================================================
// SIDERAMMEN — MÅLT, IKKE RESONNERT
//
// Bredden var ikke bestemt noe sted før dette. Den falt ut av om siden
// tilfeldigvis brukte `className="kort"`, siden `.innhold .kort` er den
// eneste breddereglen i systemet. Talt over alle 71 sider var bare ett av
// åtte mønstre entydig; se `SPALTE` i src/lib/redesign/monstre.ts.
//
// ---------------------------------------------------------------------
// FASITEN ER KJEDEN, IKKE NABOSIDA. DET LÆRTE JEG AV TO RØDE KJØRINGER.
//
// Første utgave målte hver migrert side mot en urørt søsterside i samme
// mønster — «er de like brede, har vi ikke endret noe». Den feilet to
// ganger, og ingen av gangene på grunn av kontrakten:
//
//   /ansatte mot /persondata    436 px avvik
//   /rutiner/oppsett mot /persondata   forutsetningen brast: 1316 px
//
// Begge er samme feil. /persondata gir 1316 px for butikksjefen — hun
// ser ingen `.kort` der i det hele tatt — og 880 for eieren. Baselinen
// var altså ikke en konstant, men en funksjon av hvem som ser og hvilke
// data som finnes. Og for en rute der bredden SKAL endres, beviser en
// søstersammenligning uansett ingenting.
//
// Nå måles kjeden absolutt, per rute:
//
//   rute → data-bredde → SPALTE → ramme == (bred ? spalta : min(880, spalta))
//
// Påstanden «vi endret ikke det som allerede var riktig» flyttet til
// `sideramme.test.ts`, der den er deterministisk: den nye standard-
// bredden må være NØYAKTIG det samme tallet som `.innhold .kort` ga.
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

/**
 * Den smale spalta.
 *
 * Samme tall som den gamle regelen `.innhold .kort { max-width: 880px }`,
 * og det er ikke en tilfeldighet: `sideramme.test.ts` krever at
 * `--sq-spalte` og den gamle kortbredden er identiske. Endrer noen den
 * ene, sier vitest fra før denne fila i det hele tatt kjører.
 */
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

  // -------------------------------------------------------------------
  // ÉN PÅSTAND PER RUTE, OG DEN ER ABSOLUTT
  //
  // Både rutene som skal endre bredde og de som ikke skal, måles med
  // samme fasit — se `bevisBredde`. Feiler en av dem, står målt bredde,
  // tilgjengelig spalte og forventet tall i meldinga, så neste leser
  // slipper å gjette hvilket av tallene som var galt. Det måtte jeg.
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

// =====================================================================
// BOELGE 1 — DE TO SISTE DATALISTENE
//
// /kampanjer og /trafikk er plattform-redaktoerens. Hun er seedet i
// supabase/seed.sql og rullet inn i TOTP av e2e/eier.setup.ts, som lagrer
// oekta i REDAKTOR_OKTFIL. Ingen ny testinfrastruktur - samme mekanisme
// som port0-4b.spec.ts alt bruker.
//
// TILGANGEN BEVISES AV MAALINGEN SELV. Portneren i begge sidene svarer
//
//     if (bruker.rolle !== 'plattform_redaktor') return <p>...</p>
//
// FOER den innpakkede returen. Uten ekte tilgang finnes det ingen
// `.sq-sideramme` aa maale, og `rammebredde()` feiler paa antallet. Det
// er derfor ingen egen tilgangstest her.
//
// Hva rollen IKKE naar er allerede bevist i port0-4b.spec.ts: hun
// avvises paa /salg fordi hun staar utenfor alle kjeder, og butikksjef
// og nettbrett avvises paa /plattform. Den dekningen dupliseres ikke.
//
// /trafikk uten service-noekkel i miljoeet rendrer «Mangler
// service-noekkel» - ogsaa den innenfor rammen, med vilje. Da maaler
// testen fortsatt riktig kjede, i stedet for aa flake paa hva miljoeet
// tilfeldigvis har.
// =====================================================================

test.describe('sideramme — plattform-redaktørens datalister', () => {
  test.use({ storageState: REDAKTOR_OKTFIL })

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 1000 })
  })

  test('/kampanjer: dataliste → bred → målt', async ({ page }) => {
    await bevisBredde(page, '/kampanjer', 'bred')
  })

  test('/trafikk: dataliste → bred → målt', async ({ page }) => {
    await bevisBredde(page, '/trafikk', 'bred')
  })

  test('rammen holder seg innenfor spalta også på mobil', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    for (const sti of ['/kampanjer', '/trafikk']) {
      await page.goto(sti)
      await expect(page.locator('.sq-sideramme')).toBeVisible()
      const { ramme, rom } = await page.evaluate(() => {
        const el = document.querySelector('main.innhold')!
        const s = getComputedStyle(el)
        return {
          ramme: document.querySelector('.sq-sideramme')!.getBoundingClientRect().width,
          rom: el.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight),
        }
      })
      expect(ramme, `${sti}: rammen er bredere enn spalta`).toBeLessThanOrEqual(rom + 1)
    }
  })
})
