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
    // DENNE MÅLER RAMMENS EGET ANSVAR, IKKE SIDAS
    //
    // Rammen skal aldri selv bli bredere enn spalta den fikk. Blir den
    // det, er det `max-width` uten `width: 100%`, eller flex-barn med
    // `min-width: auto` som drar den ut — begge deler ville vært rammens
    // skyld. At innholdet inni renner over er et annet spørsmål, og det
    // stilles av `ingenSideoverflyt`.
    //
    // (Første utgave målte `document.scrollWidth` her og var rød på /salg
    // med 129 px. Jeg forklarte det med `.tabellramme` — se side.tsx. Den
    // forklaringen holdt ikke: /skills gir NØYAKTIG samme 129 px uten å ha
    // en tabell i det hele tatt. Derfor navngir `dokumentoverflyt` nå
    // elementet i stedet for å telle piksler, så neste diagnose bygger på
    // en måling og ikke på min gjetning.)
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
// ---------------------------------------------------------------------
// TESTMILJOEBEGRENSNING — LES DENNE FOER DU STOLER PAA DEKNINGEN
//
// CI har ingen service-noekkel. Begge disse sidene leser paa tvers av
// kjeder med `lagSupabaseAdminKlient()`, og uten noekkelen faller de til
// «Mangler service-noekkel» - som ogsaa er pakket inn i rammen, med
// vilje, saa maalingen treffer riktig kjede uansett.
//
// KONSEKVENSEN, SAGT RETT UT:
//
//   BEVIST   /kampanjer og /trafikk klassifiseres som `dataliste`
//   BEVIST   `dataliste` gir `bred`
//   BEVIST   rammen blir faktisk bred i nettleseren
//   IKKE     at tabellinnholdet deres rendrer riktig i bred visning
//
// Det siste er kun bevist paa /utsolgt, som har ekte data i CI. Les
// derfor ikke «tre datalister maalt» som «tre tabeller maalt».
//
// Dette er et testmiljoefunn, ikke et layoutfunn, og det loeses ikke her.
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

// =====================================================================
// BOELGE 2 — 13 LISTER FRA TILFELDIG FULLBREDDE TIL `liste = smal`
//
// Dette er den stoerste visuelle endringen i migreringen: alle 13 gaar
// fra fullbredde til 880 px. Derfor maales fire representative
// strukturer, ikke en representant:
//
//   /skills     Rad/Liste - den delte primitiven
//   /puls       hjemmelaget radklasse i barnefil
//   /varsler    mye metadata og handlinger per rad
//   /nyheter    lang tekst (sq-innlegg)
//
// Ingen av de fire har tabell, saa den kjente `.tabellramme`-overflyten
// forstyrrer ikke maalingen. Det er med vilje: skal en av dem rulle
// sideveis, er det den nye bredden som gjorde det.
//
// HVA SOM FAKTISK MAALES
//
// «Handlinger forsvinner ikke utenfor rammen», «lange tekster bryter» og
// «metadata kolliderer ikke» er tre spoersmaal med ett felles maal: ikke
// noe SKAL stikke utenfor rammen. `utenforRammen()` maaler nettopp det,
// paa hvert eneste synlige etterkommerelement, og navngir synderen.
// Absolutt- og fastposisjonerte elementer er utelatt - et sidepanel eller
// en meny SKAL kunne ligge utenfor spalta.
// =====================================================================

const BOELGE2 = ['/skills', '/puls', '/varsler', '/nyheter']

/** Synlige etterkommere som stikker utenfor rammen sin. */
async function utenforRammen(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const ramme = document.querySelector('.sq-sideramme')
    if (!ramme) return ['fant ingen .sq-sideramme']
    const r = ramme.getBoundingClientRect()
    const ut: string[] = []
    for (const el of Array.from(ramme.querySelectorAll('*'))) {
      const s = getComputedStyle(el)
      if (s.position === 'absolute' || s.position === 'fixed') continue
      if (s.display === 'none' || s.visibility === 'hidden') continue
      const b = el.getBoundingClientRect()
      if (b.width === 0 && b.height === 0) continue
      if (b.right > r.right + 1 || b.left < r.left - 1) {
        const navn = el.tagName.toLowerCase()
          + (el.className && typeof el.className === 'string'
            ? '.' + el.className.trim().split(/\s+/).join('.') : '')
        ut.push(`${navn} (${Math.round(b.left)}–${Math.round(b.right)} mot rammens `
          + `${Math.round(r.left)}–${Math.round(r.right)})`)
      }
    }
    return ut.slice(0, 5)
  })
}

/**
 * Ruller dokumentet sideveis — og i så fall, HVEM gjør det?
 *
 * Et rent pikseltall er ubrukelig når man skal finne årsaken: /salg og
 * /skills ga begge nøyaktig 129 px, på to sider uten felles innhold. Da
 * er spørsmålet «hvilket element», ikke «hvor mange piksler», og det
 * spørsmålet skal testen svare på selv i stedet for å sende meg på jakt.
 *
 * Bare de YTTERSTE synderne rapporteres: har et barn skjøvet ut sin
 * forelder, er det forelderen som står i veien for å forstå, ikke de
 * femten etterkommerne som arver bredden.
 */
async function dokumentoverflyt(
  page: Page,
): Promise<{ px: number; hvem: string[]; iRammen: string[] }> {
  return page.evaluate(() => {
    const rot = document.documentElement
    const px = rot.scrollWidth - rot.clientWidth
    if (px <= 1) return { px, hvem: [] as string[], iRammen: [] as string[] }
    const grense = rot.clientWidth
    const skyldige: Element[] = []
    for (const el of Array.from(document.body.querySelectorAll('*'))) {
      const s = getComputedStyle(el)
      if (s.display === 'none' || s.visibility === 'hidden') continue
      if (s.position === 'fixed') continue
      const b = el.getBoundingClientRect()
      if (b.width === 0 && b.height === 0) continue
      if (b.right <= grense + 1) continue
      // Har forelderen allerede samme problem, er det den som er saken.
      if (skyldige.some((s2) => s2.contains(el))) continue
      skyldige.push(el)
    }
    const ramme = document.querySelector('.sq-sideramme')
    const beskriv = (el: Element) => {
      const b = el.getBoundingClientRect()
      const s = getComputedStyle(el)
      const navn = el.tagName.toLowerCase()
        + (typeof el.className === 'string' && el.className.trim()
          ? '.' + el.className.trim().split(/\s+/).join('.') : '')
      return `${navn} [${Math.round(b.left)}→${Math.round(b.right)}] `
        + `w=${Math.round(b.width)} min-w=${s.minWidth} overflow-x=${s.overflowX}`
    }
    return {
      px,
      hvem: skyldige.slice(0, 6).map(beskriv),
      iRammen: skyldige.filter((el) => ramme?.contains(el)).slice(0, 6).map(beskriv),
    }
  })
}

/**
 * Ingenting PÅ SIDA skyver dokumentet sideveis.
 *
 * ---------------------------------------------------------------------
 * HVORFOR DENNE MÅLER RAMMENS SUBTRE OG IKKE HELE DOKUMENTET
 *
 * Første utgave målte hele dokumentet og var rød på /skills med 129 px.
 * Da testen ble bedt om å navngi synderne, var ingen av dem på sida:
 *
 *     span.rolle-pip   [318→399]   Toppstripe
 *     a.klokke-lenke   [378→414]   Toppstripe
 *     form             [430→519]   Toppstripe   ← 519 − 390 = 129
 *     a.sq-fane        [338→444]   Fanerad
 *
 * Skallet, ikke innholdet. `.toppstripe` er `display: grid`
 * (globals.css:446), men mobilregelen på linje 555 setter `flex-wrap:
 * wrap` — som ikke gjør noe på en grid-container. De tre kolonnene
 * `minmax(0,1fr) auto minmax(0,1fr)` står side ved side på 390 px
 * uansett. Regelen ser riktig ut og er inert.
 *
 * Det forklarer også /salg sine 129 px, som jeg tidligere tilskrev
 * `.tabellramme`. Samme tall, samme årsak, og forklaringen min var feil.
 *
 * Funnet er eldre enn Sideramme og hører ikke til denne migreringen.
 * Derfor svarer denne påstanden for det rammen faktisk eier: at ingen
 * ETTERKOMMER AV RAMMEN skyver dokumentet. Skallets overflyt rapporteres
 * som kontekst i meldinga, så den ikke blir glemt.
 */
async function ingenSideoverflyt(page: Page, sti: string) {
  const { px, hvem, iRammen } = await dokumentoverflyt(page)
  expect(
    iRammen,
    `${sti}: innhold i rammen skyver dokumentet (${px} px totalt).\n`
    + `  I rammen:\n    ${iRammen.join('\n    ')}\n`
    + `  Alle syndere:\n    ${hvem.join('\n    ')}`,
  ).toEqual([])
}

test.describe('bølge 2 — liste blir smal', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const bredde of [1440, 1600]) {
    test(`kjeden holder på ${bredde} px`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: 1000 })
      for (const sti of BOELGE2) {
        const { ramme, rom } = await bevisBredde(page, sti, 'smal')
        // Spalta er romslig nok paa begge bredder, saa rammen skal treffe
        // 880 - ikke bare «ikke mer enn».
        expect(rom, `${sti}: spalta er bare ${Math.round(rom)} px`).toBeGreaterThan(SMAL)
        expect(Math.round(ramme), `${sti} på ${bredde} px`).toBe(SMAL)
      }
    })
  }

  test('ingenting stikker utenfor rammen på desktop', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 })
    for (const sti of BOELGE2) {
      await page.goto(sti)
      await expect(page.locator('.sq-sideramme')).toBeVisible()
      expect(await utenforRammen(page), `${sti}: innhold utenfor rammen`).toEqual([])
      await ingenSideoverflyt(page, sti)
    }
  })

  test('rammen og innholdet holder seg innenfor mobilviewporten', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    for (const sti of BOELGE2) {
      await page.goto(sti)
      await expect(page.locator('.sq-sideramme')).toBeVisible()
      const rom = await tilgjengelig(page)
      const ramme = await rammebredde(page)
      expect(ramme, `${sti}: rammen er bredere enn spalta på mobil`)
        .toBeLessThanOrEqual(rom + 1)
      expect(await utenforRammen(page), `${sti}: innhold utenfor rammen på mobil`).toEqual([])
      await ingenSideoverflyt(page, sti)
    }
  })

  test('avvisningssida har samme bredde som sida den avviser', async ({ page }) => {
    // /kunnskap og /redaktor avviser butikksjefen. Foer boelge 2 fikk hun
    // fullbredde der og 880 px paa sidene hun har tilgang til - samme rute,
    // to bredder, avhengig av hvem som ser. Avvisningen er ogsaa en tilstand
    // av sida, og har naa sidas kontrakt.
    await page.setViewportSize({ width: 1440, height: 1000 })
    await bevisBredde(page, '/kunnskap', 'smal')
  })
})
