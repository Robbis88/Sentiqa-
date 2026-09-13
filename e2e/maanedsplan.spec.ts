import { expect, test } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// Mat- og svinnanalysen på månedsplanen — den faktiske flaten.
// =====================================================================
//
// Enhetstestene måler visningsobjektet. Denne måler at tallene faktisk
// står på skjermen, at en blokkert analyse IKKE forsvinner, og at
// kortet holder på telefonbredde.
//
// Seedet har tre utkast, ett for hver tilstand som må tåles:
//
//   Underby  juli  bekreftelse + usikker enkeltmåling
//   Grenseby juli  tiltak + retning tilgjengelig
//   Underby  juni  blokkert, med årsak og måned
//
// ---------------------------------------------------------------------
// `toContainText`, IKKE `innerText`
//
// `innerText` gir bare rendret tekst og kan ikke skille «finnes ikke»
// fra «er skjult». En negativ påstand hører til `textContent`. Se
// AGENTS.md — det har flaket her før.

// =====================================================================
// ØKTA. Uten denne linja kjører fila UTLOGGET.
//
// Prosjektet `chromium` avhenger av `oppsett`, som logger inn eieren og
// lagrer økta i `OKTFIL` — men avhengigheten kjører bare steget, den
// deler ikke økta. Hver spec-fil må be om den selv.
//
// Glemte man den, ble hver `goto` sendt til /logg-inn og HVER påstand
// feilet med «element(s) not found». Det ser ut som en feil i sida.
// =====================================================================
test.use({ storageState: OKTFIL })

const kort = (side: import('@playwright/test').Page, stasjon: string) =>
  side.locator('.sq-plankort').filter({ hasText: stasjon }).first()

test.beforeEach(async ({ page }) => {
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
})

test('Underby juli: bekreftelse med alle tallene', async ({ page }) => {
  const k = kort(page, 'Underby').filter({ hasText: 'Synlig matkast' })
  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()

  // Merket sier dommen.
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('bekreftelse')

  // De seks spørsmålene, som tall på skjermen.
  await expect(blokk).toContainText('838 292')      // hvor ligger vi
  await expect(blokk).toContainText('32 019')       // synlig kast
  await expect(blokk).toContainText('3,82 %')       // faktisk
  await expect(blokk).toContainText('6,23 %')       // budsjett
  await expect(blokk).toContainText('52 245')       // justert budsjett
  await expect(blokk).toContainText('−2,41 pp')     // avvik
  await expect(blokk).toContainText('20 226')       // avvik i kroner
  await expect(blokk).toContainText('bedre enn budsjett')
  await expect(blokk).toContainText('Kastprosenten faller')
  await expect(blokk).toContainText('Under kastbudsjettet')
})

test('Underby juli: uforklart matavvik er usikkert, ikke en manko', async ({ page }) => {
  const blokk = kort(page, 'Underby')
    .locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(blokk).toBeVisible()

  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('usikker måling')
  await expect(blokk).toContainText('+31 902 kr')
  await expect(blokk).toContainText('Usikker enkeltmåling')
  await expect(blokk).toContainText('telling')
  await expect(blokk).toContainText('periodisering')
  await expect(blokk).toContainText('fakturaflyt')
  await expect(blokk).toContainText('teoretisk bruttofortjeneste minus faktisk')
  await expect(blokk).toContainText('overproduksjon')

  // ORDENE SOM IKKE SKAL STÅ DER. `textContent` gjennom toContainText —
  // en negativ påstand på `innerText` ville bestått mens blokken var
  // skjult.
  await expect(blokk).not.toContainText('manko')
  await expect(blokk).not.toContainText('gevinst')
})

test('Grenseby juli: tiltak med budsjettavviket som forklaring', async ({ page }) => {
  const blokk = kort(page, 'Grenseby')
    .locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('tiltak')
  await expect(blokk).toContainText('19,33 %')
  await expect(blokk).toContainText('13,59 %')
  await expect(blokk).toContainText('+5,74 pp')
  await expect(blokk).toContainText('over budsjett')
  await expect(blokk).toContainText('ingen stabil forbedring')
  // Ikke en påstand dataene ikke bærer.
  await expect(blokk).not.toContainText('feil vei')
})

test('Grenseby juli: retning med PERIODEN i setningen', async ({ page }) => {
  const blokk = kort(page, 'Grenseby')
    .locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('retning tilgjengelig')
  await expect(blokk).toContainText('+3 815 kr')
  await expect(blokk).toContainText('de siste 3 månedene')
  // «Økt» i et positivt uforklart avvik betyr VERRE.
  await expect(blokk).toContainText('har økt')
})

test('en blokkert analyse forsvinner IKKE', async ({ page }) => {
  // Juni på Underby. Før P2 falt matkast bare ut av punktene, og kortet
  // så komplett ut — da tror den som leser at alt er i orden.
  const k = page.locator('.sq-plankort').filter({ hasText: 'Underby' }).nth(1)
  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('ikke beregnet')
  await expect(blokk).toContainText('Datagrunnlag mangler')
  await expect(blokk).toContainText('ikke avstemt')
  await expect(blokk).toContainText('Gjelder måneden 2026-04-01')

  const u = k.locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(u).toContainText('Matgruppen ble ikke funnet')
  await expect(u).toContainText('Gjelder måneden 2026-04-01')

  // SAMME KORT BÆRER EN PLAN FRA FØR `0216`: `rangering` er null.
  // Sida skrev før `?? { mulig: true, kandidater: [] }`, og da sto det
  // «Ingen av løftestengene peker feil vei denne måneden» på en plan
  // ingen har målt. Vi vet ikke hva den gamle motoren gjorde.
  await expect(k).toContainText('Rangering er ikke tilgjengelig')
  await expect(k).not.toContainText('Ingen av løftestengene peker feil vei')
})

test('norsk tegnsett står riktig på skjermen', async ({ page }) => {
  const side = page.locator('.sq-plankort-liste').first()
  await expect(side).toContainText('måneder')
  await expect(side).toContainText('Uforklart matavvik')
  // Ingen mojibake fra feil koding.
  await expect(side).not.toContainText('Ã')
})

// =====================================================================
// MOBIL
//
// Prosjektet kjører bare Desktop Chrome. Bredden settes derfor her —
// det er layouten som skal måles, ikke en ny nettlesermotor.
// =====================================================================
test.describe('telefonbredde', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('analyseblokkene stables og teksten er hel', async ({ page }) => {
    await page.goto('/maanedsplan')
    const blokker = kort(page, 'Underby').locator('.sq-analyse')
    await expect(blokker.first()).toBeVisible()

    // ÉN KOLONNE. To blokker ved siden av hverandre på 390 px ville
    // klippet tallene.
    const a = await blokker.nth(0).boundingBox()
    const b = await blokker.nth(1).boundingBox()
    expect(a && b).toBeTruthy()
    expect(b!.y).toBeGreaterThan(a!.y + a!.height - 4)

    // Tallene er fortsatt hele.
    await expect(blokker.nth(0)).toContainText('838 292')
    await expect(blokker.nth(0)).toContainText('−2,41 pp')
  })

  test('sida ruller ikke sideveis', async ({ page }) => {
    await page.goto('/maanedsplan')
    await expect(page.locator('.sq-plankort').first()).toBeVisible()
    const bredde = await page.evaluate(
      () => [document.documentElement.scrollWidth, window.innerWidth],
    )
    // En analyseblokk som er bredere enn skjermen gir en side som må
    // dras sidelengs — det er en feil, ikke en detalj.
    expect(bredde[0]).toBeLessThanOrEqual(bredde[1] + 1)
  })
})

// =====================================================================
// Å BYGGE MÅNEDENS UTKAST PÅ NYTT — DEN POSITIVE PRODUKSJONSVEIEN
// =====================================================================
//
// Knappen finnes fordi den eneste veien til et nytt utkast var å kjøre
// en regnskapsfil om igjen — og det skriver `regnskapslinjer`,
// `bilagssum`, `bp_linje` og provenienstabellene på veien.
//
// Seedet har minste gyldige regnskapsgrunnlag for juli 2026 på ALLE tre
// stasjonene i Analysekjeden, så juli er en komplett datamåned. Da
// vises knappen, og hele kjeden kan måles:
//
//   komplett grunnlag -> knappen vises -> eieren bekrefter ->
//   serverhandlingen kjører -> juliutkast bygges -> snapshot lagres ->
//   fredede rader står urørt
//
// SEEDETS JULI-TILSTAND:
//   Underby  5101   utkast   skal SKRIVES
//   Grenseby 5102   utkast   skal SKRIVES
//   Overby   5103   AVVIST   skal stå urørt og NAVNGIS
//
// Og utenfor juli:
//   Underby  juni   utkast   annen måned — skal ikke røres
//   Grenseby mai    sluppet  avgjort — skal ikke røres
// =====================================================================

/** Kortet for én stasjon i én måned, uansett hvilken seksjon det står i. */
const plankort = (side: import('@playwright/test').Page, stasjon: string, mnd: string) =>
  side.locator('.sq-plankort').filter({ hasText: stasjon }).filter({ hasText: mnd })

test.describe('bygg på nytt — det som ikke endrer noe', () => {
  test('knappen sier hvilken måned, hvor mange stasjoner, og hva som IKKE skjer',
    async ({ page }) => {
      await page.goto('/maanedsplan')
      const seksjon = page.locator('section').filter({ hasText: 'Bygg juli 2026 på nytt' })
      await expect(seksjon).toBeVisible()

      // FORVENTNINGEN FRA DATAGRUNNLAGET, ikke antall planrader.
      await expect(seksjon).toContainText('Grunnlaget forventer 3 stasjoner')

      // Forklaringen må si hva som IKKE skjer. «Bygg på nytt» alene
      // leses som «kjør importen om igjen».
      await expect(seksjon).toContainText('Ingen fil lastes opp')
      await expect(seksjon).toContainText('ingen import kjøres')
      await expect(seksjon).toContainText('Bare utkast skrives om')
    })

  test('den kjører ALDRI av seg selv', async ({ page }) => {
    // En side som skriver når den åpnes er en side ingen kan stole på.
    await page.goto('/maanedsplan')
    await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
    await page.reload()
    await expect(page.locator('.sq-plankort').first()).toBeVisible()
    await expect(page.locator('body')).not.toContainText('Bygget')
  })

  test('spørsmålet navngir måneden og begge tallene', async ({ page }) => {
    await page.goto('/maanedsplan')
    let tekst = ''
    page.on('dialog', async (d) => { tekst = d.message(); await d.dismiss() })
    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await expect.poll(() => tekst).toContain('juli 2026')
    expect(tekst).toContain('Grunnlaget forventer 3 stasjoner')
    expect(tekst).toContain('Ingen regnskapsdata')
    expect(tekst).toContain('Sluppet, sendt og avvist står urørt')
  })

  test('avbryt betyr avbryt', async ({ page }) => {
    // `window.confirm` uten `preventDefault` kjører handlingen uansett
    // hva man svarer. Det har skjedd i dette huset før.
    await page.goto('/maanedsplan')
    page.on('dialog', (d) => d.dismiss())
    await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()
    await page.waitForTimeout(500)
    await expect(page.locator('body')).not.toContainText('Bygget')
  })

  test('butikksjefens flate har ingen byggeknapp', async ({ page }) => {
    // NEGATIV TILSTAND PÅ EN ANNEN AKSE: mottakeren skal aldri kunne
    // bygge planen sin på nytt. `textContent` — en negativ påstand på
    // `innerText` ville bestått mens knappen var skjult.
    await page.goto('/min-plan')
    await expect(page.locator('body')).not.toContainText('på nytt')
    await expect(page.getByRole('button', { name: /Bygg/ })).toHaveCount(0)
  })
})

// =====================================================================
// DEN MUTERENDE MÅNEDSPLANFLYTEN
// =====================================================================
//
// `test.describe.serial` — og det er en beslutning, ikke en formalitet.
//
// A bygger snapshot, B slipper, C avviser, D måler feiltilstand mot det
// som DA finnes. Stegene deler rader, og rekkefølgen er en del av
// påstanden. Uten `.serial` ville den avhengigheten vært skjult i
// Playwrights standardoppførsel, og en framtidig `fullyParallel: true`
// ville gjort flyten til fem tester som skriver i hverandre.
//
// ---------------------------------------------------------------------
// RADENE DENNE FLYTEN EIER
//
//   Underby  5101  juli 2026   utkast   bygges om (A), leses (D)
//   Grenseby 5102  juli 2026   utkast   bygges om (A), SLIPPES (B)
//   Overby   5103  juli 2026   avvist   skal stå urørt hele veien
//   Underby  5101  juni 2026   utkast   AVVISES (C)
//
// Ingen andre spec-filer må anta antall eller status på disse fire.
// `min-plan.spec.ts` leser BARE Grenseby mai 2026, som flyten aldri
// rører, og teller ingen kort.
//
// ---------------------------------------------------------------------
// HVERT STEG SJEKKER SIN EGEN FORUTSETNING
//
// «Ingen test skal bli grønn bare fordi en tidligere test allerede
// utførte handlingen.» Derfor slår hvert steg fast hva det forventer
// Å FINNE før det gjør noe — og steg 0 slår fast hele seedtilstanden
// før den første mutasjonen.
//
// `retries: 0` i `playwright.config.ts` er en forutsetning her: en
// retry ville startet midt i flyten på en halvt mutert base.
// `src/lib/redesign/e2e-oppsett.test.ts` feller en endring.
// =====================================================================
test.describe.serial('månedsplanflyten — muterer ekte rader', () => {
  // Økta arves fra `test.use` øverst i fila.
  const venter = (side: import('@playwright/test').Page) =>
    side.locator('section').filter({ hasText: 'Venter på deg' })
  const avgjort = (side: import('@playwright/test').Page) =>
    side.locator('section').filter({ hasText: 'Avgjort' })

  // ===================================================================
  // 0  SEEDTILSTANDEN, FØR FØRSTE MUTASJON
  // ===================================================================
  test('0  seedtilstanden er som forventet', async ({ page }) => {
    await page.goto('/maanedsplan')

    // Tre utkast venter, og to er avgjort.
    await expect(venter(page).locator('.sq-plankort')
      .filter({ hasText: 'Underby' }).filter({ hasText: 'juli' })).toHaveCount(1)
    await expect(venter(page).locator('.sq-plankort')
      .filter({ hasText: 'Grenseby' }).filter({ hasText: 'juli' })).toHaveCount(1)
    await expect(venter(page).locator('.sq-plankort')
      .filter({ hasText: 'Underby' }).filter({ hasText: 'juni' })).toHaveCount(1)

    // Overby juli er AVVIST fra seeden, ikke av denne flyten.
    const overby = plankort(page, 'Overby', 'juli').first()
    await expect(overby.locator('.sq-plankort-status')).toHaveText('Avvist')

    // Og juli-snapshottene er seedens, ikke bygget av oss.
    await expect(plankort(page, 'Underby', 'juli').first())
      .not.toContainText('Datagrunnlag mangler')
  })

  // ===================================================================
  // A  BYGG -> KVITTERING OG NYE SNAPSHOT PAA SAMME SIDE
  // ===================================================================
  //
  // INGEN `page.reload()`, INGEN NY `page.goto()`.
  //
  // Det er hele poenget: serverhandlingen revaliderer ikke sin egen
  // rute (det gjorde kvitteringen til gissel for ruteroppdateringen og
  // ga tjue sekunders venting), og `HandlingKnapp` med `oppfrisk`
  // kaller `router.refresh()` naar svaret er kommet. Bruker man
  // `reload()` i testen, maaler man ikke den mekanismen — man maaler
  // nettleserens egen omlasting, og da kunne oppfriskningen vært borte
  // uten at noe ble rødt.
  // ===================================================================
  test('A  bygg: kvittering OG nye snapshot uten manuell omlasting',
    async ({ page }) => {
      await page.goto('/maanedsplan')

      // FOER: Underby juli baerer seedens snapshot, som IKKE er blokkert.
      // Selve overgangen er det som maales - ikke hvilket domsord seeden
      // tilfeldigvis har.
      const underby = () => plankort(page, 'Underby', 'juli').first()
      await expect(underby()).not.toContainText('Datagrunnlag mangler')

      page.on('dialog', (d) => d.accept())
      await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()

      // KVITTERINGEN.
      await expect(page.locator('.sq-slett-ok'))
        .toContainText('Bygget 2 utkast for 2026-07', { timeout: 20_000 })
      await expect(page.locator('.sq-slett-ok')).toContainText('Overby')

      // OG DE NYE SNAPSHOTTENE, paa samme side. Grunnlaget har ingen
      // svinnrader og intet kastbudsjett, saa nipunktsporten blokkerer
      // — et BLOKKERT snapshot er et skrevet snapshot.
      await expect(underby().locator('.sq-analyse').first())
        .toContainText('Datagrunnlag mangler', { timeout: 15_000 })

      // KVITTERINGEN STAAR FORTSATT etter oppfriskningen. `router.refresh()`
      // henter serverkomponentene uten aa nullstille klienttilstand; gjorde
      // den det, ville bekreftelsen blinket bort.
      await expect(page.locator('.sq-slett-ok')).toContainText('Bygget 2 utkast')

      // DEN AVVISTE STAAR UROERT.
      await expect(plankort(page, 'Overby', 'juli').first())
        .toContainText('Resultatet i juli er 10 000 kroner')
    })

  // ===================================================================
  // B  SLIPP -> KORTET FLYTTER SEG, OG PLANEN NAAR BUTIKKSJEFEN
  // ===================================================================
  test('B  slipp: kortet flytter seg til Avgjort med status Sluppet',
    async ({ page }) => {
      await page.goto('/maanedsplan')

      // FORUTSETNINGEN, SLAATT FAST FOERST. Uten den ville testen
      // bestaatt ogsaa hvis et tidligere steg alt hadde sluppet den.
      const iKoe = () => venter(page).locator('.sq-plankort')
        .filter({ hasText: 'Grenseby' }).filter({ hasText: 'juli' })
      await expect(iKoe()).toHaveCount(1)

      await iKoe().getByRole('button', { name: 'Slipp' }).click()

      // DE TO FEILENE SKILLES — UTEN Å KAPPLØPE MED EN KOMPONENT SOM
      // FORSVINNER.
      //
      // Første forsøk ventet på `.sq-slett-ok`. Den lever i
      // `HandlingKnapp`, og knappen AVMONTERES i det kortet flytter til
      // «Avgjort» — så påstanden vant eller tapte på om oppfriskningen
      // rakk å bli ferdig først. Den feilet med «element(s) not found»
      // på en handling som hadde lyktes.
      //
      // FEILMELDINGEN er derimot stabil: feiler handlingen, flytter
      // kortet seg ikke, knappen blir stående, og teksten blir stående
      // med den. Vi venter på det første av to utfall og krever
      // deretter at det var flyttingen — da sier feilmeldingen hvilken
      // av de to tingene som gikk galt.
      const feilet = page.locator('.sq-slett-feil')
      await expect
        .poll(async () => (await iKoe().count()) === 0 || (await feilet.count()) > 0,
          { timeout: 20_000, message: 'verken flyttet kortet seg eller kom det en feil' })
        .toBe(true)
      expect(await feilet.allTextContents(), 'handlingen feilet').toEqual([])

      // FLYTTET, UTEN OMLASTING.
      await expect(iKoe()).toHaveCount(0)

      // DEN VARIGE KVITTERINGEN.
      //
      // `.sq-slett-ok` lever i `HandlingKnapp`, og knappen avmonteres
      // naar kortet flytter til «Avgjort» - den er borte i det
      // oppfriskningen er ferdig. Aa maale den ville vaert aa maale et
      // blink.
      //
      // Det brukeren faktisk sitter igjen med, er STATUSEN paa kortet.
      const flyttet = avgjort(page).locator('.sq-plankort')
        .filter({ hasText: 'Grenseby' }).filter({ hasText: 'juli' })
      await expect(flyttet).toHaveCount(1)
      await expect(flyttet.locator('.sq-plankort-status')).toHaveText('Sluppet')

      // Og knappene er borte: en sluppet plan kan ikke slippes igjen.
      await expect(flyttet.getByRole('button', { name: 'Slipp' })).toHaveCount(0)

      // DEN NAADDE MOTTAKEREN. Navigering er riktig her: en ANNEN rute,
      // revalidert paa serveren av `slippPlan`.
      await page.goto('/min-plan')
      await expect(page.locator('.sq-plankort').filter({ hasText: 'juli 2026' }))
        .toHaveCount(1)
    })

  // ===================================================================
  // C  AVVIS -> KORTET FLYTTER SEG, OG PLANEN NAAR IKKE MOTTAKEREN
  // ===================================================================
  test('C  avvis: kortet flytter seg til Avgjort med status Avvist',
    async ({ page }) => {
      await page.goto('/maanedsplan')

      const iKoe = () => venter(page).locator('.sq-plankort')
        .filter({ hasText: 'Underby' }).filter({ hasText: 'juni' })
      await expect(iKoe()).toHaveCount(1)

      // AVVIS SPØR FØRST. `Slipp` gjør det ikke, og det er derfor B
      // virket uten dette: Playwright AUTO-AVVISER en dialog ingen
      // håndterer, så `preventDefault` i `HandlingKnapp` stoppet
      // innsendingen og ingenting skjedde. Kortet ble stående, og
      // feilen så ut som en oppfriskning som ikke virket.
      // TELLES, ikke bare håndteres.
      //
      // `kvitter()` returnerer ALLTID noe — `feil` eller `ok`. Kom det
      // verken en flytting eller en feilmelding, kjørte handlingen
      // aldri, og da er det innsendingen som ble stoppet. Denne
      // telleren skiller «dialogen kom aldri» fra «dialogen ble
      // besvart, men handlingen gjorde ingenting».
      let dialoger = 0
      page.on('dialog', (d) => { dialoger += 1; return d.accept() })

      await iKoe().getByRole('button', { name: 'Avvis' }).click()

      await expect
        .poll(() => dialoger,
          { timeout: 10_000, message: 'bekreftelsesdialogen for Avvis kom aldri' })
        .toBe(1)

      // DE TO FEILENE SKILLES — UTEN Å KAPPLØPE MED EN KOMPONENT SOM
      // FORSVINNER.
      //
      // Første forsøk ventet på `.sq-slett-ok`. Den lever i
      // `HandlingKnapp`, og knappen AVMONTERES i det kortet flytter til
      // «Avgjort» — så påstanden vant eller tapte på om oppfriskningen
      // rakk å bli ferdig først. Den feilet med «element(s) not found»
      // på en handling som hadde lyktes.
      //
      // FEILMELDINGEN er derimot stabil: feiler handlingen, flytter
      // kortet seg ikke, knappen blir stående, og teksten blir stående
      // med den. Vi venter på det første av to utfall og krever
      // deretter at det var flyttingen — da sier feilmeldingen hvilken
      // av de to tingene som gikk galt.
      const feilet = page.locator('.sq-slett-feil')
      await expect
        .poll(async () => (await iKoe().count()) === 0 || (await feilet.count()) > 0,
          { timeout: 20_000, message: 'verken flyttet kortet seg eller kom det en feil' })
        .toBe(true)
      expect(await feilet.allTextContents(), 'handlingen feilet').toEqual([])
      await expect(iKoe()).toHaveCount(0, { timeout: 20_000 })

      // DEN VARIGE KVITTERINGEN, som i B: knappen avmonteres, statusen
      // blir staaende.
      const flyttet = avgjort(page).locator('.sq-plankort')
        .filter({ hasText: 'Underby' }).filter({ hasText: 'juni' })
      await expect(flyttet).toHaveCount(1)
      await expect(flyttet.locator('.sq-plankort-status')).toHaveText('Avvist')
      await expect(flyttet.getByRole('button', { name: 'Avvis' })).toHaveCount(0)

      // En avvist plan naar aldri mottakeren. `textContent` — en
      // negativ paastand paa `innerText` ville bestaatt mens kortet var
      // skjult.
      await page.goto('/min-plan')
      await expect(page.locator('.sq-plankort-liste')).not.toContainText('juni')
    })

  // ===================================================================
  // D  EN FEILET HANDLING SKAL IKKE SE UT SOM SUKSESS
  // ===================================================================
  test('D  feilet handling: feilmeldingen staar, og sida friskes ikke opp',
    async ({ page }) => {
      await page.goto('/maanedsplan')
      const foer = await plankort(page, 'Underby', 'juli').first().textContent()

      // Feltet sier en annen maaned enn serveren finner. Serveren slaar
      // maalmaaneden opp paa nytt og avviser — feltet kan bare gi et nei.
      await page.locator('form:has(input[name="maaned"]) input[name="maaned"]')
        .evaluate((el: HTMLInputElement) => { el.value = '2026-05-01' })

      page.on('dialog', (d) => d.accept())
      await page.getByRole('button', { name: /Bygg juli 2026 på nytt/ }).click()

      // FEILEN STAAR.
      await expect(page.locator('.sq-slett-feil'))
        .toContainText('Last sida på nytt', { timeout: 20_000 })

      // OG INGEN FALSK SUKSESS: ingen kvittering, og kortet staar
      // bokstavelig uendret.
      //
      // Sammenlignet med det som FAKTISK sto der foer, ikke med en fast
      // forventning: testene i fila deler database, og test A har
      // bygget juli om foer denne kjoerer.
      await expect(page.locator('.sq-slett-ok')).toHaveCount(0)
      const etter = await plankort(page, 'Underby', 'juli').first().textContent()
      expect(etter, 'kortet endret seg av en FEILET handling').toBe(foer)
    })

  test('dobbeltklikk gir \u00e9n kjøring', async ({ page }) => {
    await page.goto('/maanedsplan')
    page.on('dialog', (d) => d.accept())
    const knapp = page.getByRole('button', { name: /Bygg juli 2026 på nytt/ })

    await knapp.click()
    // Knappen er `disabled` mens handlingen venter. Playwright venter
    // paa at den blir klikkbar igjen, saa et klikk nummer to her ville
    // vaert en ANNEN kjoering - ikke et dobbeltklikk. Vi maaler i
    // stedet at den faktisk ER laast.
    await expect(knapp).toBeDisabled()
    await expect(page.locator('.sq-slett-ok'))
      .toContainText('Bygget', { timeout: 20_000 })
    await expect(knapp).toBeEnabled()
  })

})
