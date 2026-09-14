import { expect, test, type Page } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// DIAGNOSTIKK: ER `oppfrisker` EN PAALITELIG MAALING AV RSC-HENTINGEN?
// =====================================================================
//
// Bakgrunn. `HandlingKnapp` kjoerer `router.refresh()` i sin EGEN
// `useTransition`, og bruker `isPending` derfra som maal paa «visningen
// hentes fortsatt». Blir den staaende i 10 sekunder, viser knappen en
// advarsel om at visningen ikke kunne oppdateres.
//
// 2026-09-14 fyrte den advarselen i CI paa en HELT VANLIG handling -
// uten kunstig forsinkelse. Det betyr én av to ting, og de er motsatte:
//
//   FALSK POSITIV  `isPending` staar lenge av grunner som ikke betyr
//                  noe, og advarselen ville plaget hver handling.
//   SANN POSITIV   oppfriskningen henger faktisk, og da er problemet
//                  flyttet - ikke fjernet.
//
// Denne fila AVGJOER IKKE hvilken. Den MAALER, slik at avgjoerelsen kan
// tas paa et tall i stedet for en antakelse. Terskelen paa 10 sekunder
// roeres ikke foer maalingen foreligger.
//
// ---------------------------------------------------------------------
// HVA SOM KAN OBSERVERES, OG HVA SOM MAA UTLEDES
// ---------------------------------------------------------------------
//
// `oppfrisker` er en React-hook inne i komponenten. Den kan ikke leses
// fra nettleseren uten aa endre produksjonskoden, og produksjonskoden
// skal vaere byte-identisk i denne runden. Den utledes derfor:
//
//   false -> true   samtidig med at kvitteringen blir synlig. Effekten
//                   som starter oppfriskningen kjoerer i den commiten.
//                   UTLEDET, ikke maalt.
//   true  -> false  ikke observerbar direkte. Men advarselen settes av
//                   en timer paa 10 s som ryddes naar `oppfrisker` gaar
//                   av - saa advarsel = «sto i minst 10 s», ingen
//                   advarsel innen 12 s = «gikk av foer 10 s».
//                   BINAERT, ikke et tidspunkt.
//
// Alt annet - POST, RSC-kall, kvittering, knapp, advarsel, montert -
// maales direkte.
//
// ---------------------------------------------------------------------
// EGEN FIL, EGEN DOM
// ---------------------------------------------------------------------
//
// Testene laa foer i `test.describe.serial`-blokka i maanedsplan.spec.ts.
// Da steg D feilet 2026-09-14, hoppet Playwright over resten av blokka,
// og ingen av dem kjoerte i det hele tatt. En diagnose som forsvinner
// naar noe annet feiler, er en diagnose man ikke har.
//
// Fila arver ikke tilstand: den paastaar ingenting om ANTALL planer.
// Kjoerer `maanedsplan.spec.ts` foerst og har sluppet eller avvist noen,
// sier kvitteringen «Ingen utkast ble skrevet» i stedet for «Bygget N» -
// og begge er gyldige her. Det maales er TIDSLINJA, ikke tallet.
// =====================================================================

test.use({ storageState: OKTFIL })

type Kall = { url: string; sendt: number; ferdig: number | null; status: number | null }

function lytt(side: Page, t0: () => number) {
  const handling: Kall[] = []
  const rsc: Kall[] = []
  const revalidert: (string | null)[] = []

  const finn = (liste: Kall[], url: string) =>
    [...liste].reverse().find((k) => k.url === url && k.ferdig === null)

  side.on('request', (r) => {
    const n = { url: r.url(), sendt: Date.now() - t0(), ferdig: null, status: null }
    if (r.method() === 'POST' && r.headers()['next-action']) handling.push(n)
    else if (r.url().includes('_rsc=')) rsc.push(n)
  })
  side.on('response', (r) => {
    if (r.request().method() === 'POST' && r.request().headers()['next-action']) {
      revalidert.push(r.headers()['x-action-revalidated'] ?? null)
    }
  })
  // `requestfinished` er naar KROPPEN er mottatt. `response` fyrer paa
  // headerne, og ville gitt et for tidlig «ferdig».
  side.on('requestfinished', async (r) => {
    const liste = r.method() === 'POST' && r.headers()['next-action'] ? handling
      : r.url().includes('_rsc=') ? rsc : null
    if (!liste) return
    const k = finn(liste, r.url())
    if (!k) return
    k.ferdig = Date.now() - t0()
    k.status = (await r.response())?.status() ?? null
  })
  side.on('requestfailed', (r) => {
    const liste = r.url().includes('_rsc=') ? rsc : null
    const k = liste && finn(liste, r.url())
    if (k) { k.ferdig = Date.now() - t0(); k.status = -1 }
  })

  return { handling, rsc, revalidert }
}

/** Ett oppslag av alt som er synlig i knappens eget skjema. */
async function blikk(side: Page) {
  return side.evaluate(() => {
    const felt = document.querySelector('input[name="maaned"]')
    const skjema = felt?.closest('form') as HTMLFormElement | null
    const knapp = skjema?.querySelector('button') as HTMLButtonElement | null
    return {
      montert: !!skjema,
      kvittering: skjema?.querySelector('.sq-slett-ok')?.textContent ?? null,
      feil: skjema?.querySelector('.sq-slett-feil')?.textContent ?? null,
      advarsel: !!skjema?.querySelector('.sq-oppfrisk-feil'),
      knappAktiv: !!knapp && !knapp.disabled,
    }
  })
}

test('TIDSLINJE: en helt vanlig, uforsinket oppfriskning', async ({ page }) => {
  test.setTimeout(120_000)
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()

  let start = Date.now()
  const { handling, rsc, revalidert } = lytt(page, () => start)

  const knapp = page.getByRole('button', { name: /Bygg .* på nytt/ })
  await expect(knapp).toBeVisible()
  page.on('dialog', (d) => d.accept())

  start = Date.now()
  await knapp.click()

  // SAMPLING hvert 100. ms i 25 sekunder. Lenge nok til aa se baade at
  // advarselen kommer (10 s) og at den eventuelt IKKE kommer.
  const merke: Record<string, number | null> = {
    kvittering: null, knappAktiv: null, advarselVist: null,
    advarselBorte: null, avmontert: null,
  }
  let sisteKvittering: string | null = null
  let saaAdvarsel = false

  while (Date.now() - start < 25_000) {
    const b = await blikk(page)
    const t = Date.now() - start
    if (!b.montert && merke.avmontert === null) merke.avmontert = t
    if (b.kvittering && merke.kvittering === null) {
      merke.kvittering = t
      sisteKvittering = b.kvittering
    }
    if (b.knappAktiv && merke.kvittering !== null && merke.knappAktiv === null) {
      merke.knappAktiv = t
    }
    if (b.advarsel && merke.advarselVist === null) { merke.advarselVist = t; saaAdvarsel = true }
    if (!b.advarsel && saaAdvarsel && merke.advarselBorte === null) merke.advarselBorte = t
    await page.waitForTimeout(100)
  }

  const slutt = await blikk(page)
  const apneRsc = rsc.filter((k) => k.ferdig === null)
  const sisteRsc = rsc.length ? Math.max(...rsc.map((k) => k.ferdig ?? 1e9)) : null

  // -------------------------------------------------------------------
  // KLASSIFISERING. Fire tilstander, og de er gjensidig utelukkende.
  // -------------------------------------------------------------------
  const rscFerdigFoerAdvarsel = merke.advarselVist !== null
    && apneRsc.length === 0 && sisteRsc !== null && sisteRsc < merke.advarselVist

  const dom = merke.avmontert !== null ? 'C  komponenten ble AVMONTERT'
    : merke.advarselVist === null ? 'D  transitionen avsluttet normalt (ingen advarsel innen 25 s)'
      : rscFerdigFoerAdvarsel ? 'A  ALLE RSC-svar ferdige, men transitionen stod fortsatt pending'
        : 'B  minst ett RSC-svar var fortsatt aapent da advarselen kom'

  const l = (s: string) => console.log(`  ${s}`)
  l('')
  l('================ TIDSLINJE, VANLIG OPPFRISKNING ================')
  for (const k of handling) {
    l(`POST next-action        sendt ${k.sendt} ms   ferdig ${k.ferdig} ms   status ${k.status}`)
  }
  l(`x-action-revalidated    ${revalidert.map((r) => r ?? '(fravaerende)').join(', ') || '(ingen POST)'}`)
  l(`kvittering synlig       ${merke.kvittering} ms`)
  l(`knappen aktiv igjen     ${merke.knappAktiv} ms`)
  l(`oppfrisker false->true  ${merke.kvittering} ms   (UTLEDET: samme commit som kvitteringen)`)
  l(`advarsel vist           ${merke.advarselVist} ms`)
  l(`advarsel fjernet        ${merke.advarselBorte} ms`)
  l(`oppfrisker true->false  ${merke.advarselVist === null ? '< 10 000 ms (ingen advarsel)' : '>= 10 000 ms (advarsel kom)'}   (UTLEDET)`)
  l(`komponent montert       ${slutt.montert}   avmontert ved ${merke.avmontert} ms`)
  l(`RSC-kall                ${rsc.length} totalt, ${apneRsc.length} fortsatt aapne`)
  for (const k of rsc.slice(0, 25)) {
    l(`  _rsc  sendt ${String(k.sendt).padStart(6)} ms  ferdig ${String(k.ferdig ?? -1).padStart(6)} ms  status ${k.status}`)
  }
  l(`siste RSC ferdig        ${sisteRsc} ms`)
  l(`kvitteringstekst        ${JSON.stringify(sisteKvittering)}`)
  l('')
  l(`DOM: ${dom}`)
  l('===============================================================')

  // -------------------------------------------------------------------
  // DET SOM FAKTISK PAASTAAS HER er bare frikoblingen. Klassifiseringen
  // over er en MAALING, ikke en port - den skal rapporteres, ikke feile.
  // -------------------------------------------------------------------
  expect(merke.kvittering, 'kvitteringen kom aldri').not.toBeNull()
  expect(merke.kvittering!, 'kvitteringen ventet paa oppfriskningen').toBeLessThan(6_000)
  expect(merke.knappAktiv, 'knappen ble aldri aktiv igjen').not.toBeNull()
  expect(slutt.montert, 'skjemaet forsvant fra sida').toBe(true)
  expect(revalidert, 'handlingen revaliderte').toEqual([null])
})

// =====================================================================
// DE FIRE SOM LAA I DEN SERIELLE BLOKKA
// =====================================================================
//
// Flyttet hit 2026-09-14. De laa i `test.describe.serial` i
// maanedsplan.spec.ts, og da steg D feilet ble hele resten av blokka
// hoppet over - ingen av dem kjoerte. En vakt som forsvinner naar noe
// annet feiler, er ikke en vakt.
//
// De paastaar ingenting om ANTALL planer, saa de taaler hvilken
// tilstand A-D enn etterlater.
// =====================================================================

function tellHandlinger(side: Page) {
  const kall: string[] = []
  const svar: { status: number; revalidert: string | null }[] = []
  side.on('request', (r) => {
    const h = r.headers()['next-action']
    if (r.method() === 'POST' && h) kall.push(h)
  })
  side.on('response', (r) => {
    if (r.request().method() !== 'POST') return
    if (!r.request().headers()['next-action']) return
    svar.push({
      status: r.status(),
      revalidert: r.headers()['x-action-revalidated'] ?? null,
    })
  })
  return { kall, svar }
}

const byggeknapp = (side: Page) =>
  side.getByRole('button', { name: /Bygg .* på nytt/ })

test('to raske klikk gir NØYAKTIG én serverhandling', async ({ page }) => {
  await page.goto('/maanedsplan')
  page.on('dialog', (d) => d.accept())
  const { kall } = tellHandlinger(page)
  const knapp = byggeknapp(page)

  // BEGGE I SAMME TIKK, forbi Playwrights egen ventelogikk. `click()`
  // venter paa at knappen er klikkbar, og ville dermed gjort klikk to til
  // en ANNEN kjoering i stedet for et dobbeltklikk.
  await knapp.evaluate((el: HTMLElement) => { el.click(); el.click() })

  await expect(page.locator('.sq-slett-ok').first()).toBeVisible({ timeout: 20_000 })
  await expect(knapp).toBeEnabled()

  console.log(`  next-action-POSTer ved dobbeltklikk: ${kall.length}`)
  expect(kall.length, `serverhandlinger sendt: ${kall.length}`).toBe(1)
})

test('handlingssvaret baerer ikke x-action-revalidated', async ({ page }) => {
  await page.goto('/maanedsplan')
  page.on('dialog', (d) => d.accept())
  const { svar } = tellHandlinger(page)

  await byggeknapp(page).click()
  await expect(page.locator('.sq-slett-ok').first()).toBeVisible({ timeout: 20_000 })
  await expect(byggeknapp(page)).toBeEnabled()

  console.log(`  handlingssvar: status=${svar[0]?.status} `
    + `x-action-revalidated=${svar[0]?.revalidert ?? '(fravaerende)'}`)
  expect(svar.length).toBe(1)
  expect(svar[0].status).toBe(200)
  expect(
    svar[0].revalidert,
    'Handlingen revaliderte. Da sender Next en fersk flight-payload for '
    + 'ruta du staar paa, inne i handlingens egen overgang.',
  ).toBeNull()
})

test('treg oppfriskning (8 s) holder ikke kvitteringen tilbake', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('/maanedsplan')
  page.on('dialog', (d) => d.accept())

  // 8 sekunder er UNDER advarselsterskelen paa 10. Kvitteringen skal
  // komme med én gang, og advarselen skal IKKE staa der.
  await page.route(/_rsc=/, async (rute) => {
    await new Promise((r) => setTimeout(r, 8_000))
    await rute.continue()
  })

  const start = Date.now()
  await byggeknapp(page).click()
  await expect(page.locator('.sq-slett-ok').first()).toBeVisible({ timeout: 6_000 })
  await expect(byggeknapp(page)).toBeEnabled()

  const brukt = Date.now() - start
  console.log(`  kvittering etter ${brukt} ms (RSC forsinket 8 000 ms)`)
  expect(brukt, `kvitteringen kom etter ${brukt} ms - den ventet paa RSC`)
    .toBeLessThan(6_000)

  await page.unroute(/_rsc=/)
})

// =====================================================================
// ADVARSELEN MAA KUNNE INNTREFFE, ELLERS ER DEN DOED KODE
// =====================================================================
//
// `router.refresh()` returnerer `void`. En henging er usynlig for
// `try/catch` - den fanger bare et synkront kast. Det andre tilfellet
// fanges av TIDEN: `oppfrisker` staar i sin transition til hentingen er
// ferdig, og blir den staaende i 10 sekunder, sier komponenten ifra.
//
// Den mekanismen hviler paa en ANTAKELSE om Next: at `router.refresh()`
// inne i `startTransition` holder `isPending` sann til RSC-hentingen er
// ferdig. Er den feil, fyrer advarselen ALDRI, og en test som bare
// sjekket at den ikke staar der ville vaert groenn i begge tilfeller.
//
// RSC-SVARENE HOLDES AAPNE, ikke forsinket med en fast tid. Da er «minst
// ett kall er fortsatt aapent» noe som MAALES, ikke antas - og
// slippetidspunktet er vaart, saa «forsvant den etterpaa» kan ogsaa
// maales.
// =====================================================================

function holdRsc(side: Page) {
  const slipper: (() => void)[] = []
  let hold = true
  const rute = async (r: import('@playwright/test').Route) => {
    if (hold) await new Promise<void>((ok) => slipper.push(ok))
    await r.continue()
  }
  return {
    paa: () => side.route(/_rsc=/, rute),
    slipp: () => { hold = false; slipper.splice(0).forEach((f) => f()) },
    av: () => side.unroute(/_rsc=/, rute),
  }
}

test('advarselen kommer naar oppfriskningen blir staaende', async ({ page }) => {
  test.setTimeout(120_000)
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()

  let start = Date.now()
  const { handling, rsc, revalidert } = lytt(page, () => start)
  const hold = holdRsc(page)
  await hold.paa()

  const knapp = byggeknapp(page)
  await expect(knapp).toBeVisible()
  page.on('dialog', (d) => d.accept())

  start = Date.now()
  await knapp.click()

  // 1  KVITTERINGEN FOER OPPFRISKNINGEN. Alle RSC-kall henger.
  await expect(page.locator('.sq-slett-ok').first()).toBeVisible({ timeout: 6_000 })
  const tKvittering = Date.now() - start
  await expect(knapp).toBeEnabled()
  const tKnapp = Date.now() - start
  const apneVedKvittering = rsc.filter((k) => k.ferdig === null).length

  // 2  ADVARSELEN. Kommer den ikke, holder ikke refreshen sin egen
  //    transition aapen - og da er hele mekanismen doed kode.
  await expect(page.locator('.sq-oppfrisk-feil')).toBeVisible({ timeout: 20_000 })
  const tAdvarsel = Date.now() - start
  const apneVedAdvarsel = rsc.filter((k) => k.ferdig === null).length
  const montertVedAdvarsel = await page.locator('form:has(input[name="maaned"])').count()

  const l = (s: string) => console.log(`  ${s}`)
  l('')
  l('========== TIDSLINJE, HOLDT OPPFRISKNING ==========')
  for (const k of handling) {
    l(`POST next-action      sendt ${k.sendt} ms  ferdig ${k.ferdig} ms  status ${k.status}`)
  }
  l(`x-action-revalidated  ${revalidert.map((r) => r ?? '(fravaerende)').join(', ')}`)
  l(`kvittering synlig     ${tKvittering} ms`)
  l(`knappen aktiv         ${tKnapp} ms`)
  l(`aapne RSC ved kvittering  ${apneVedKvittering}`)
  l(`advarsel vist         ${tAdvarsel} ms`)
  l(`aapne RSC ved advarsel    ${apneVedAdvarsel} av ${rsc.length}`)
  l(`skjema montert        ${montertVedAdvarsel === 1}`)

  expect(apneVedKvittering, 'ingen RSC-kall var aapne - holdet virket ikke').toBeGreaterThan(0)
  expect(tKvittering, 'kvitteringen ventet paa den holdte RSC-hentingen').toBeLessThan(6_000)
  expect(tAdvarsel, 'advarselen kom ikke rundt 10 s').toBeGreaterThan(9_000)
  expect(apneVedAdvarsel, 'alle RSC var ferdige - da maaler ikke testen en henging')
    .toBeGreaterThan(0)
  await expect(page.locator('.sq-slett-ok').first(),
    'kvitteringen skal staa VED SIDEN AV advarselen').toBeVisible()
  expect(montertVedAdvarsel, 'skjemaet forsvant').toBe(1)
  expect(handling.length, 'det ble sendt mer enn én serverhandling').toBe(1)

  // 3  SLIPP DEM, og se hva som skjer.
  hold.slipp()
  await expect.poll(() => rsc.filter((k) => k.ferdig === null).length,
    { timeout: 20_000, message: 'RSC-kall fullfoerte ikke etter slipp' }).toBe(0)
  const tSluppet = Date.now() - start
  l(`alle RSC ferdige      ${tSluppet} ms`)

  // 4  KJENT MANGEL, MAALT HER FRAMFOR AA BLI ANTATT.
  //
  //    `visningFroset` settes av timeren, men settes bare tilbake til
  //    `false` naar et NYTT handlingssvar kommer. Naar oppfriskningen
  //    fullfoerer, ryddes timeren - flagget blir staaende. Advarselen
  //    sier da «last sida paa nytt» om en side som ER oppdatert.
  //
  //    `expect.soft` med vilje: de ti maalingene over skal rapporteres
  //    selv naar denne feller, og roedt skal peke paa NOEYAKTIG denne
  //    setningen. Rettingen hoerer hjemme i produksjonskoden, og denne
  //    committen er diagnostisk.
  const advarselEtter = await page.locator('.sq-oppfrisk-feil').count()
  l(`advarsel etter slipp  ${advarselEtter === 0 ? 'borte' : 'staar fortsatt'}`)
  l('==================================================')
  expect.soft(advarselEtter,
    'KJENT MANGEL: advarselen blir staaende etter at oppfriskningen '
    + 'fullfoerte. `visningFroset` har ingen vei tilbake til false uten '
    + 'et nytt handlingssvar. Krever en produksjonsendring.').toBe(0)

  await hold.av()
})
