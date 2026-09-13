import { expect, test } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// MOTTAKERFLATEN. Planen slik den faktisk når fram.
// =====================================================================
//
// Fram til denne PR-en fantes den ikke. RLS-policyen `maanedsplan_les_
// butikksjef` (0200) ga butikksjefen lesetilgang til sluppede planer,
// koden sa «hun leser sin egen plan når den er sluppet», og
// `tilEpost()` sto ferdig skrevet i `src/lib/kurs/epost.ts` — men ingen
// rute viste planen, og ingen kalte `tilEpost`.
//
// Roberts ord: «At RLS gir butikksjefen lesetilgang er ikke det samme
// som at hun har en brukerflate.» Denne testen er den flaten, målt.
//
// ---------------------------------------------------------------------
// HVA DEN MÅLER, OG HVA DEN IKKE KAN MÅLE
//
// Playwright-økten er EIERENS — `eier.setup.ts` logger inn én gang, og
// alle spec-filene arver den. Testen beviser derfor at RUTEN finnes, at
// den filtrerer på status, at den tegner de samme tallene som eierens
// kort, og at den ikke bærer eierens knapper.
//
// Den beviser IKKE at butikksjefen er avgrenset til egne stasjoner.
// Det er RLS-spørsmålet, og det måles av tenantmatrisen i
// `supabase/tests/` — ikke her. To ting som ser like ut og bevises på
// hvert sitt sted.
//
// ---------------------------------------------------------------------
// SEEDET
//
//   Grenseby  mai   SLUPPET   tiltak + retning + URANGERT plan
//   Underby   juli  utkast    (skal ALDRI vises her)
//   Grenseby  juli  utkast    (skal ALDRI vises her)
//   Underby   juni  utkast    (skal ALDRI vises her)

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

const kort = (side: import('@playwright/test').Page) =>
  side.locator('.sq-plankort').first()

test.beforeEach(async ({ page }) => {
  await page.goto('/min-plan')
  await expect(page.getByRole('heading', { name: 'Månedsplanen din' })).toBeVisible()
})

test('den sluppede planen står der, med tallene sine', async ({ page }) => {
  const k = kort(page)
  await expect(k).toContainText('Grenseby')
  await expect(k).toContainText('mai 2026')
  await expect(k).toContainText('Motvind')

  const blokk = k.locator('.sq-analyse').filter({ hasText: 'Synlig matkast' })
  await expect(blokk).toBeVisible()
  await expect(blokk.locator('.sq-analyse-merke')).toHaveText('tiltak')
  await expect(blokk).toContainText('16,80 %')       // hvor ligger vi nå
  await expect(blokk).toContainText('13,59 %')       // hva var budsjettet
  await expect(blokk).toContainText('+3,21 pp')      // over eller under
  await expect(blokk).toContainText('over budsjett')
})

test('retningen sier PERIODEN, ikke bare «ned»', async ({ page }) => {
  const u = kort(page).locator('.sq-analyse').filter({ hasText: 'Uforklart matavvik' })
  await expect(u.locator('.sq-analyse-merke')).toHaveText('retning tilgjengelig')
  await expect(u).toContainText('+2 941 kr')
  await expect(u).toContainText('de siste 3 månedene')
  // «Ned» er bedre, men ikke løst — og det står det.
  await expect(u).toContainText('har falt')
  await expect(u).toContainText('fortsatt')
})

test('en urangert plan sier hvorfor, ikke «alt er i orden»', async ({ page }) => {
  const k = kort(page)
  // DEN FARLIGE FORMEN: `punkter` er tom fordi motoren ikke KUNNE velge,
  // ikke fordi ingenting går feil vei. Sto det «Ingen av løftestengene
  // peker feil vei» her, hadde butikksjefen fått en falsk god nyhet.
  await expect(k).not.toContainText('Ingen av løftestengene peker feil vei')

  const u = k.locator('.sq-plankort-urangert')
  await expect(u).toBeVisible()
  await expect(u).toContainText('ikke økonomisk rangert')
  await expect(u).toContainText('2 løftestenger')
  await expect(u).toContainText('royaltysatser')
  // KANDIDATENE VED NAVN. «Vi kunne ikke rangere» uten å si hva som sto
  // likt er et forbehold uten innhold.
  await expect(u).toContainText('Matkast')
  await expect(u).toContainText('Påvirkbare driftskostnader')
})

test('et UTKAST når aldri mottakeren', async ({ page }) => {
  // Tre utkast ligger i seedet. Ingen av dem hører hjemme her: et brev
  // som ikke er sluppet er ikke et brev, det er eierens forslag til seg
  // selv. `textContent` — en negativ påstand på `innerText` ville
  // bestått mens kortet var skjult.
  // INGEN TELLING AV KORT.
  //
  // Første utgave krevde `toHaveCount(1)`. Den var bundet til at INGEN
  // annen test slapp en plan — og `maanedsplan.spec.ts` gjør nettopp det
  // nå. To spec-filer som deler database kan ikke ha påstander om totaler.
  //
  // Det som faktisk skal holde er REGELEN: et utkast når aldri hit.
  // Underby juni er utkast i seeden og skal aldri stå her.
  const liste = page.locator('.sq-plankort-liste')
  await expect(liste).not.toContainText('juni')
  await expect(liste).toContainText('mai 2026')
})

test('mottakeren har ingen knapper å trykke på', async ({ page }) => {
  // Slipp og Avvis er EIERENS. Kunne butikksjefen avvise sin egen plan,
  // var godkjenningen meningsløs.
  const k = kort(page)
  await expect(k.getByRole('button', { name: 'Slipp' })).toHaveCount(0)
  await expect(k.getByRole('button', { name: 'Avvis' })).toHaveCount(0)
  await expect(k.locator('.knapperad')).toHaveCount(0)
})

test('fanerada fører hit fra /regnskap', async ({ page }) => {
  // VEIEN INN. `/min-plan` ligger i samme fanegruppe som `/regnskap`,
  // og det er med vilje: butikksjefen åpner tallene sine og finner
  // planen som en fane ved siden av dem. En rute uten vei inn er en
  // rute ingen finner — og det var nettopp tilstanden før denne PR-en,
  // bare uten ruta i tillegg.
  await page.goto('/regnskap')
  const fane = page.getByRole('link', { name: 'Månedsplanen din' }).first()
  await expect(fane).toBeVisible()
  await fane.click()
  await expect(page.getByRole('heading', { name: 'Månedsplanen din' })).toBeVisible()
})

test('norsk tegnsett står riktig', async ({ page }) => {
  const liste = page.locator('.sq-plankort-liste')
  await expect(liste).toContainText('kastbudsjettet')
  await expect(liste).toContainText('Påvirkbare driftskostnader')
  await expect(liste).not.toContainText('Ã')
})

// =====================================================================
// TELEFONBREDDE. Butikksjefen leser dette mellom to andre ting.
// =====================================================================
test.describe('telefonbredde', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('analyseblokkene stables, og sida ruller ikke sideveis', async ({ page }) => {
    await page.goto('/min-plan')
    const blokker = kort(page).locator('.sq-analyse')
    await expect(blokker.first()).toBeVisible()

    const a = await blokker.nth(0).boundingBox()
    const b = await blokker.nth(1).boundingBox()
    expect(a && b).toBeTruthy()
    expect(b!.y).toBeGreaterThan(a!.y + a!.height - 4)

    const bredde = await page.evaluate(
      () => [document.documentElement.scrollWidth, window.innerWidth],
    )
    expect(bredde[0]).toBeLessThanOrEqual(bredde[1] + 1)
  })
})
