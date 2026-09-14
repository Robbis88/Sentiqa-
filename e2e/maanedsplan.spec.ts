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
// =====================================================================
// ÉN DIAGNOSE FOR BEGGE HANDLINGENE
// =====================================================================
//
// B og C har byttet paa aa feile i fire kjoeringer, og hver gang har
// bare den ene hatt diagnostikk nok til aa si hvorfor. Da fikser man
// én av gangen og laerer ingenting om den andre.
//
// Her ligger den én gang, og begge bruker den.
//
// ---------------------------------------------------------------------
// SLUTTUTFALLENE ER TO
//
//   a) kortet er flyttet, med riktig VARIG status
//   b) handlingen returnerte feil
//
// `.sq-slett-ok` er BEVIS, ikke et sluttutfall: kvitteringen kommer
// foer oppfriskningen lander, og knappen avmonteres naar kortet flytter.
// Avsluttet man paa den, maalte man timing. Den fanges loepende og
// brukes ved timeout til aa skille tilstandene.
// =====================================================================
type Flyttediagnose = {
  dom: string
  bilde: string
}

async function diagnoserFlytting(opts: {
  side: import('@playwright/test').Page
  /** Kortet slik det staar i koeen, som funksjon — det forsvinner. */
  iKoe: () => import('@playwright/test').Locator
  /** Kortet slik det skal staa etterpaa. */
  iAvgjort: () => import('@playwright/test').Locator
  /** Statusordet som skal staa paa kortet naar alt virket. */
  status: string
  /** Knappen, for aa se om handlingen henger. */
  knapp: import('@playwright/test').Locator
  /** Alt vi har lyttet paa siden foer klikket. */
  spor: { dialoger: () => number; nett: string[]; konsoll: string[]; sidefeil: string[] }
}): Promise<Flyttediagnose> {
  const { side, iKoe, iAvgjort, status, knapp, spor } = opts
  const ok = side.locator('.sq-slett-ok')
  const feil = side.locator('.sq-slett-feil')

  const les = async () => ({
    dialoger: spor.dialoger(),
    knappDisabled: (await knapp.count()) > 0 ? await knapp.isDisabled() : null,
    ok: (await ok.allTextContents()).join(' | '),
    feil: (await feil.allTextContents()).join(' | '),
    iKoe: await iKoe().count(),
    iAvgjort: await iAvgjort().count(),
    status: (await iAvgjort().locator('.sq-plankort-status').allTextContents()).join(' | '),
  })

  let settOk = ''
  let sluttfoert = false
  try {
    await expect.poll(async () => {
      const t = await les()
      if (t.ok !== '') settOk = t.ok
      const flyttet = t.iKoe === 0 && t.iAvgjort === 1 && t.status === status
      return flyttet || t.feil !== ''
    }, { timeout: 25_000 }).toBe(true)
    sluttfoert = true
  } catch {
    sluttfoert = false
  }

  const raa = await les()
  const t = { ...raa, ok: raa.ok || settOk }
  const flyttet = t.iKoe === 0 && t.iAvgjort === 1 && t.status === status

  const dom =
    flyttet ? 'E  full kjede virker'
      : t.feil !== '' ? 'D  serverhandlingen returnerte FEIL'
        : t.dialoger === 0 && spor.nett.every((n) => !n.startsWith('--> POST'))
          ? 'A  ingen innsending — dialogen eller skjemaet stoppet den'
          : t.knappDisabled === true ? 'B  handlingen er PENDING eller henger'
            : t.ok !== ''
              ? 'C  handlingen LYKTES, men flyttingen kom ikke'
              : '?  ingen av de fem — se bildet'

  const bilde = [
    `dialoger         : ${t.dialoger}`,
    `knapp disabled   : ${t.knappDisabled}`,
    `.sq-slett-ok     : ${t.ok || '(tom)'}  (sett underveis: ${settOk || 'aldri'})`,
    `.sq-slett-feil   : ${t.feil || '(tom)'}`,
    `i «Venter»       : ${t.iKoe}`,
    `i «Avgjort»      : ${t.iAvgjort}`,
    `status           : ${t.status || '(ingen)'}  (forventet ${status})`,
    `poll fullfoert   : ${sluttfoert}`,
    `nett             :\n    ${spor.nett.join('\n    ') || '(ingen)'}`,
    `console          :\n    ${spor.konsoll.join('\n    ') || '(ingen)'}`,
    `pageerror        :\n    ${spor.sidefeil.join('\n    ') || '(ingen)'}`,
  ].join('\n  ')

  return { dom, bilde }
}

/** Lytterne, satt opp FOER klikket. Se `diagnoserFlytting`. */
function lyttPaaAlt(side: import('@playwright/test').Page) {
  let dialoger = 0
  const nett: string[] = []
  const konsoll: string[] = []
  const sidefeil: string[] = []

  side.on('dialog', (d) => { dialoger += 1; return d.accept() })
  side.on('console', (m) => {
    if (m.type() === 'error' || m.type() === 'warning') konsoll.push(`${m.type()}: ${m.text()}`)
  })
  side.on('pageerror', (e) => sidefeil.push(e.message))
  side.on('request', (q) => {
    const rsc = q.headers()['rsc']
    if (q.method() === 'POST') {
      nett.push(`--> POST ${q.url()} next-action=${q.headers()['next-action'] ?? '(ingen)'}`)
    } else if (rsc) nett.push(`--> RSC ${q.method()} ${q.url()}`)
  })
  side.on('response', (v) => {
    const q = v.request()
    if (q.method() === 'POST') nett.push(`<-- ${v.status()} POST ${v.url()}`)
    else if (q.headers()['rsc']) nett.push(`<-- ${v.status()} RSC ${v.url()}`)
  })
  side.on('requestfailed', (q) => {
    nett.push(`XX  ${q.method()} ${q.url()} ${q.failure()?.errorText ?? ''}`)
  })

  return { dialoger: () => dialoger, nett, konsoll, sidefeil }
}

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

      const iAvgjort = () => avgjort(page).locator('.sq-plankort')
        .filter({ hasText: 'Grenseby' }).filter({ hasText: 'juli' })
      const knapp = iKoe().getByRole('button', { name: 'Slipp' })

      // LYTTERNE FØRST. Alt som skjer etter klikket skal være fanget.
      const spor = lyttPaaAlt(page)
      await knapp.click()

      const { dom, bilde } = await diagnoserFlytting({
        side: page, iKoe, iAvgjort, status: 'Sluppet', knapp, spor,
      })
      console.log(`\n  SLIPP-DIAGNOSE — ${dom}\n  ${bilde}\n`)
      expect(dom, `Slipp-flyten:\n  ${bilde}\n`).toBe('E  full kjede virker')

      // Og da holder de opprinnelige påstandene av seg selv.
      await expect(iKoe()).toHaveCount(0)
      await expect(iAvgjort()).toHaveCount(1)
      await expect(iAvgjort().locator('.sq-plankort-status')).toHaveText('Sluppet')
      // En sluppet plan kan ikke slippes igjen.
      await expect(iAvgjort().getByRole('button', { name: 'Slipp' })).toHaveCount(0)

      // DEN NAADDE MOTTAKEREN. Navigering er riktig her: en ANNEN rute,
      // revalidert paa serveren av `slippPlan`.
      await page.goto('/min-plan')
      await expect(page.locator('.sq-plankort').filter({ hasText: 'juli 2026' }))
        .toHaveCount(1)
    })

  // ===================================================================
  // C  AVVIS -> KORTET FLYTTER SEG, OG PLANEN NAAR IKKE MOTTAKEREN
  // ===================================================================
  // ===================================================================
  // C  AVVIS — DIAGNOSTISK KOMPLETT
  // ===================================================================
  //
  // Testen har feilet tre ganger, og hver gang har jeg TRUKKET EN
  // KONKLUSJON JEG IKKE HADDE MÅLT. Sist: «kortet flyttet seg ikke og
  // ingen feil kom, altså kjørte handlingen aldri». Det følger ikke.
  // Minst fire tilstander gir samme timeout:
  //
  //   A  dialogen stoppet innsendingen
  //   B  handlingen startet og står pending
  //   C  handlingen returnerte feil
  //   D  handlingen returnerte ok, men klientoppfriskningen uteble
  //   E  alt virket
  //
  // Den gamle pollen så bare etter «flyttet» og «feil». Den kunne
  // derfor ikke skille D fra A — og jeg rapporterte A.
  //
  // Her samles ALT som skiller dem, og utfallet klassifiseres. Feiler
  // den, står hele bildet i loggen, og `trace: 'retain-on-failure'` gir
  // sporingen ved siden av.
  // ===================================================================
  test('C  avvis: kortet flytter seg til Avgjort med status Avvist',
    async ({ page }) => {
      await page.goto('/maanedsplan')

      const iKoe = () => venter(page).locator('.sq-plankort')
        .filter({ hasText: 'Underby' }).filter({ hasText: 'juni' })
      const iAvgjort = () => avgjort(page).locator('.sq-plankort')
        .filter({ hasText: 'Underby' }).filter({ hasText: 'juni' })
      await expect(iKoe()).toHaveCount(1)

      const knapp = iKoe().getByRole('button', { name: 'Avvis' })

      // LYTTERNE FØRST. `Avvis` har `sporsmaal`, altså en `confirm` —
      // og Playwright AUTO-AVVISER en dialog ingen håndterer, så
      // `preventDefault` i `HandlingKnapp` ville stoppet innsendingen.
      // `lyttPaaAlt` godtar den, og teller.
      const spor = lyttPaaAlt(page)
      await knapp.click()

      const { dom, bilde } = await diagnoserFlytting({
        side: page, iKoe, iAvgjort, status: 'Avvist', knapp, spor,
      })
      console.log(`\n  AVVIS-DIAGNOSE — ${dom}\n  ${bilde}\n`)
      expect(dom, `Avvis-flyten:\n  ${bilde}\n`).toBe('E  full kjede virker')

      await expect(iKoe()).toHaveCount(0)
      await expect(iAvgjort()).toHaveCount(1)
      await expect(iAvgjort().locator('.sq-plankort-status')).toHaveText('Avvist')
      await expect(iAvgjort().getByRole('button', { name: 'Avvis' })).toHaveCount(0)

      // En avvist plan naar aldri mottakeren. `textContent` — en
      // negativ paastand paa `innerText` ville bestaatt mens kortet var
      // skjult.
      await page.goto('/min-plan')
      await expect(page.locator('.sq-plankort-liste')).not.toContainText('juni')
    })

  // ===================================================================
  // D ER FJERNET, OG BEVISET ER DELT I TO
  // ===================================================================
  //
  // Testen het «D  feilet handling: feilmeldingen staar, og sida friskes
  // ikke opp». Den beviste en SERVERKONTRAKT gjennom en kunstig
  // nettleserkappleype: den satte verdien paa en React-kontrollert
  // `<input type="hidden" value={maaned}>` fra DOM-en og haapet at React
  // ikke skrev den tilbake foer innsendingen.
  //
  // Det gikk bra lenge. 2026-09-14 gikk det ikke:
  //
  //   kjoering 1  React nullstilte feltet. Handlingen kjoerte med JULI,
  //               lyktes, og testen felte paa at feilmeldingen uteble -
  //               den saa ut som «avvisningen virker ikke».
  //   kjoering 2  Feltsetting og klikk ble flyttet inn i samme
  //               `evaluate` for aa lukke kapploepet. Da ble det ikke
  //               sendt noen serverhandling I DET HELE TATT, og testen
  //               felte paa en timeout uten aa ha maalt noe.
  //
  // To ulike roede, ingen av dem om kontrakten. En test som felles av
  // rammeverkets rendringsrytme maaler rendringsrytmen, ikke kontrakten.
  //
  // Veien videre var ikke aa manipulere feltet HARDERE. React eier sitt
  // eget kontrollerte felt, og en test som tvinger det fra seg det
  // eierskapet maaler noe som ikke finnes i produksjon.
  //
  // BEVISET LIGGER NAA TO STEDER, begge autoritative:
  //
  //   AVVISNINGEN      `src/app/(beskyttet)/maanedsplan/avvisning.test.ts`
  //                    Konstruert FormData med 2026-05-01, direkte mot
  //                    serverhandlingen. Ingen nettleser, ingen React,
  //                    ikke noe kapploep. Med kanarifugl paa at juli
  //                    IKKE avvises av samme port.
  //
  //   FEILVISNINGEN    `src/components/ui/handling-knapp.test.tsx`
  //                    En handling som svarer `{ feil: … }`: feilen
  //                    staar, knappen er aktiv, og sida friskes IKKE
  //                    opp.
  //
  // Det D ellers maalte - at kortet staar uendret - foelger av at
  // avvisningen skjer foer noen skriving. Det er samme paastand, maalt
  // der den avgjoeres.
  // ===================================================================
})
