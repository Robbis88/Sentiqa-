import { expect, test, type Page } from '@playwright/test'
import { OKTFIL } from './eier'
import { lytt, type Kall } from './oppfriskningslogg'

// =====================================================================
// KVITTERINGEN ER HANDLINGENS SVAR, IKKE OPPFRISKNINGENS
// =====================================================================
//
// `HandlingKnapp` kjoerer `router.refresh()` i sin EGEN `useTransition`,
// atskilt fra handlingens. Kontrakten fila vokter:
//
//   kvitteringen og den aktive knappen kommer av at SERVEREN svarte,
//   ikke av at visningen rakk aa oppdatere seg.
//
// Blir oppfriskningen staaende i 10 sekunder, sier knappen ifra i en
// EGEN linje ved siden av kvitteringen - ikke i stedet for den.
//
// ---------------------------------------------------------------------
// TO TILSTANDER SOM SER LIKE UT, OG BARE ÉN AV DEM ER LOV
// ---------------------------------------------------------------------
//
//   A  advarselen staar, `data-oppfrisker` er fortsatt "true"
//      Transitionen er ikke ferdig. Den nye servertilstanden er ikke
//      bevist committet i visningen, og advarselen er RIKTIG.
//
//   B  advarselen staar, `data-oppfrisker` er "false"
//      Transitionen ER ferdig, og advarselen skulle vaert ryddet. Da
//      sier den «last sida paa nytt» om en side som ER oppdatert.
//      FEIL, og fila feller den.
//
//   C  advarselen er borte
//      Ryddet som forventet.
//
// A og C er begge gyldige utfall og varierer mellom kjoeringer. B er
// det ikke. Uten `data-oppfrisker` kunne de ikke skilles - se
// `handling-knapp.tsx` for hvorfor attributtet er inert.
//
// ---------------------------------------------------------------------
// `requestfinished` BEVISER IKKE AT REACT HAR COMMITTET
// ---------------------------------------------------------------------
//
// Den sier at nettverkskroppen er mottatt. Mellom den og en oppdatert
// skjerm ligger flight-parsing, render og commit. Fila KREVER derfor
// ikke at advarselen er borte i det oeyeblikket nettverket er ferdig -
// den maaler hva som faktisk skjer, og feller bare B.
// =====================================================================

test.use({ storageState: OKTFIL })

// =====================================================================
// FIRE HENDELSER, HOLDT FRA HVERANDRE
// =====================================================================
//
// Foerste utgave gjorde to feil samtidig:
//
//   1  Den blandet `response` og `requestfinished` til ett «ferdig».
//      De er ulike ting: headere mot kropp.
//   2  Lytteren var `async` og awaitet `r.response()` INNE i
//      `requestfinished`. Testen rakk aa lese arrayet foer handleren var
//      ferdig, og handlings-POSTen sto som `ferdig null status null` i
//      en kjoering som ellers var groenn.
//
// Alt bokfoeres synkront naa, og hver hendelse har sitt eget felt.
//
// ---------------------------------------------------------------------
// OBSERVASJONSFUNN, IKKE FORKLART
// ---------------------------------------------------------------------
//
// Paa cf27965 sto handlings-POSTen i normaltidslinja som:
//
//   svar 468 ms   ferdig -1   feilet 470 ms   status 200
//
// Altsaa `requestfailed` TO millisekunder etter at responsen kom med
// status 200, og uten at `requestfinished` fyrte. Kvitteringen ble
// rendret og serverhandlingen ble utfoert, saa den blokkerer ingenting.
//
// Men den er ikke forklart, og skal ikke kalles uskyldig uten videre
// bevis. Den er bare SYNLIG fordi de fire hendelsene holdes fra
// hverandre - den gamle bokfoeringen ville vist `ferdig null` og ikke
// mer.
// =====================================================================
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
      oppfrisker: skjema?.getAttribute('data-oppfrisker') ?? null,
      knappAktiv: !!knapp && !knapp.disabled,
    }
  })
}

const byggeknapp = (side: Page) =>
  side.getByRole('button', { name: /Bygg .* på nytt/ })

/** Kall som verken er ferdige eller feilet. */
const aapne = (rsc: Kall[]) =>
  rsc.filter((k) => k.ferdig === null && k.feilet === null).length

function skrivKall(l: (s: string) => void, navn: string, kall: Kall[]) {
  for (const k of kall) {
    l(`${navn}  sendt ${String(k.sendt).padStart(6)}`
      + `  svar ${String(k.svar ?? -1).padStart(6)}`
      + `  ferdig ${String(k.ferdig ?? -1).padStart(6)}`
      + `  feilet ${String(k.feilet ?? -1).padStart(6)}`
      + `  status ${k.status}`)
  }
}

// =====================================================================
test('TIDSLINJE: en helt vanlig, uforsinket oppfriskning', async ({ page }) => {
  test.setTimeout(120_000)
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()

  let start = Date.now()
  const { handling, rsc, revalidert } = lytt(page, () => start)

  const knapp = byggeknapp(page)
  await expect(knapp).toBeVisible()
  page.on('dialog', (d) => d.accept())

  start = Date.now()
  await knapp.click()

  const merke: Record<string, number | null> = {
    kvittering: null, knappAktiv: null, advarselVist: null,
    advarselBorte: null, avmontert: null, oppfriskerAv: null,
  }
  let sisteKvittering: string | null = null
  let saaAdvarsel = false
  let saaOppfrisker = false

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
    if (b.oppfrisker === 'true') saaOppfrisker = true
    if (saaOppfrisker && b.oppfrisker === 'false' && merke.oppfriskerAv === null) {
      merke.oppfriskerAv = t
    }
    if (b.advarsel && merke.advarselVist === null) {
      merke.advarselVist = t
      saaAdvarsel = true
    }
    if (!b.advarsel && saaAdvarsel && merke.advarselBorte === null) merke.advarselBorte = t
    await page.waitForTimeout(100)
  }

  const slutt = await blikk(page)
  const l = (s: string) => console.log(`  ${s}`)
  l('')
  l('================ TIDSLINJE, VANLIG OPPFRISKNING ================')
  skrivKall(l, 'POST next-action', handling)
  l(`x-action-revalidated  ${revalidert.map((r) => r ?? '(fravaerende)').join(', ') || '(ingen)'}`)
  l(`kvittering synlig     ${merke.kvittering} ms`)
  l(`knappen aktiv igjen   ${merke.knappAktiv} ms`)
  l(`oppfrisker sett true  ${saaOppfrisker}   (MAALT paa data-oppfrisker)`)
  l(`oppfrisker -> false   ${merke.oppfriskerAv} ms`)
  l(`advarsel vist         ${merke.advarselVist} ms`)
  l(`advarsel fjernet      ${merke.advarselBorte} ms`)
  l(`sluttilstand          oppfrisker=${slutt.oppfrisker} advarsel=${slutt.advarsel}`)
  l(`komponent montert     ${slutt.montert}   avmontert ved ${merke.avmontert} ms`)
  l(`RSC-kall              ${rsc.length} totalt, ${aapne(rsc)} fortsatt aapne`)
  l(`siste RSC ferdig      ${rsc.length ? Math.max(...rsc.map((k) => k.ferdig ?? -1)) : null} ms`)
  l(`kvitteringstekst      ${JSON.stringify(sisteKvittering)}`)
  l('===============================================================')

  expect(merke.kvittering, 'kvitteringen kom aldri').not.toBeNull()
  expect(merke.kvittering!, 'kvitteringen ventet paa oppfriskningen').toBeLessThan(6_000)
  expect(merke.knappAktiv, 'knappen ble aldri aktiv igjen').not.toBeNull()
  expect(slutt.montert, 'skjemaet forsvant fra sida').toBe(true)
  expect(revalidert, 'handlingen revaliderte').toEqual([null])
  expect(handling.length, 'mer enn én serverhandling').toBe(1)
  expect(handling[0].status, 'handlingen svarte ikke 200').toBe(200)

  // EN NORMAL OPPFRISKNING SKAL FULLFOERE. Uten disse fire kunne testen
  // vaert groenn ogsaa naar transitionen henger - og da maaler den bare
  // at kvitteringen kom.
  expect(saaOppfrisker, 'oppfriskningen startet aldri - data-oppfrisker ble aldri true')
    .toBe(true)
  expect(merke.oppfriskerAv,
    'oppfrisker gikk ALDRI tilbake til false paa en uforsinket oppfriskning')
    .not.toBeNull()
  expect(slutt.advarsel, 'advarsel paa en helt vanlig oppfriskning').toBe(false)
  expect(aapne(rsc), 'RSC-kall sto fortsatt aapne etter 25 s').toBe(0)
})

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

test('KLASSIFISER: hva skjer naar oppfriskningen holdes', async ({ page }) => {
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
  const apneVedKvittering = aapne(rsc)

  // 2  ADVARSELEN.
  await expect(page.locator('.sq-oppfrisk-feil')).toBeVisible({ timeout: 20_000 })
  const tAdvarsel = Date.now() - start
  const apneVedAdvarsel = aapne(rsc)
  const vedAdvarsel = await blikk(page)

  // 3  SLIPP DEM.
  hold.slipp()
  await expect.poll(() => aapne(rsc),
    { timeout: 20_000, message: 'RSC-kall fullfoerte ikke etter slipp' }).toBe(0)
  const tSluppet = Date.now() - start

  // 4  SAMPLE I FEM SEKUNDER ETTERPAA - OG KREV INGENTING.
  //
  //    `requestfinished` beviser at kroppen er mottatt, ikke at React
  //    har parset flighten, rendret og committet. Aa kreve at advarselen
  //    er borte i det oeyeblikket ville vaert aa maale ett ledd og lese
  //    resultatet av et annet.
  //
  //    Her maales det som faktisk skjer, og utfallet klassifiseres.
  let tOppfriskerAv: number | null = null
  let tAdvarselBorte: number | null = null
  const t4 = Date.now()
  while (Date.now() - t4 < 5_000) {
    const b = await blikk(page)
    const t = Date.now() - t4
    if (b.oppfrisker === 'false' && tOppfriskerAv === null) tOppfriskerAv = t
    if (!b.advarsel && tAdvarselBorte === null) tAdvarselBorte = t
    if (tOppfriskerAv !== null && tAdvarselBorte !== null) break
    await page.waitForTimeout(100)
  }
  const slutt = await blikk(page)

  const dom = !slutt.advarsel
    ? 'C  advarselen ble ryddet som forventet'
    : slutt.oppfrisker === 'true'
      ? 'A  transitionen settler ALDRI - `oppfrisker` staar fortsatt true, '
        + 'saa `true -> false`-grenen kjoerer aldri. Advarselen er RIKTIG, '
        + 'og problemet ligger i at oppfriskningen ikke fullfoerer.'
      : 'B  `oppfrisker` er false, men advarselen staar likevel - '
        + 'flagglogikken rydder ikke `froset`.'

  const l = (s: string) => console.log(`  ${s}`)
  l('')
  l('========== KLASSIFISERING, HOLDT OPPFRISKNING ==========')
  skrivKall(l, 'POST next-action', handling)
  l(`x-action-revalidated       ${revalidert.map((r) => r ?? '(fravaerende)').join(', ')}`)
  l(`kvittering synlig          ${tKvittering} ms`)
  l(`knappen aktiv              ${tKnapp} ms`)
  l(`aapne RSC ved kvittering   ${apneVedKvittering} av ${rsc.length}`)
  l(`advarsel vist              ${tAdvarsel} ms`)
  l(`aapne RSC ved advarsel     ${apneVedAdvarsel} av ${rsc.length}`)
  l(`data-oppfrisker v/advarsel ${vedAdvarsel.oppfrisker}`)
  l(`alle RSC ferdige           ${tSluppet} ms`)
  l('--- etter slipp, maalt fra siste requestfinished ---')
  l(`oppfrisker -> false        ${tOppfriskerAv === null ? 'ALDRI innen 5000' : tOppfriskerAv} ms`)
  l(`advarsel borte             ${tAdvarselBorte === null ? 'ALDRI innen 5000' : tAdvarselBorte} ms`)
  l(`sluttilstand               oppfrisker=${slutt.oppfrisker} advarsel=${slutt.advarsel}`)
  l(`skjema montert             ${slutt.montert}`)
  l(`nye aapne RSC              ${aapne(rsc)}`)
  skrivKall(l, '  _rsc', rsc)
  l('')
  l(`DOM: ${dom}`)
  l('=======================================================')

  // DET SOM PAASTAAS er bare det som allerede er etablert. Utfallet
  // over er en MAALING, ikke en port.
  expect(apneVedKvittering, 'ingen RSC-kall var aapne - holdet virket ikke')
    .toBeGreaterThan(0)
  expect(tKvittering, 'kvitteringen ventet paa den holdte RSC-hentingen')
    .toBeLessThan(6_000)
  expect(tAdvarsel, 'advarselen kom ikke rundt 10 s').toBeGreaterThan(9_000)
  expect(apneVedAdvarsel, 'alle RSC var ferdige - da maaler ikke testen en henging')
    .toBeGreaterThan(0)
  expect(vedAdvarsel.oppfrisker,
    'transitionen var ikke pending da advarselen kom - da maaler timeren noe '
    + 'annet enn den tror').toBe('true')
  await expect(page.locator('.sq-slett-ok').first(),
    'kvitteringen skal staa VED SIDEN AV advarselen').toBeVisible()
  expect(slutt.montert, 'skjemaet forsvant').toBe(true)
  expect(handling.length, 'det ble sendt mer enn én serverhandling').toBe(1)
  expect(revalidert, 'handlingen revaliderte').toEqual([null])
  expect(aapne(rsc), 'nye RSC-kall aapnet seg mens vi maalte').toBe(0)

  // A OG C ER BEGGE GYLDIGE UTFALL. B ER DET IKKE.
  //
  //   A  transitionen staar fortsatt -> advarselen er RIKTIG. Den nye
  //      servertilstanden er ikke bevist committet i visningen.
  //   C  transitionen ble ferdig     -> advarselen er ryddet.
  //   B  transitionen ble ferdig, men advarselen staar likevel. Da
  //      rydder ikke flagglogikken `froset`, og det er en ekte feil.
  //
  // Uten denne porten ble B bare LOGGET, og en ekte flaggfeil ville
  // passert i stillhet bak en groenn suite.
  expect(dom.startsWith('B'), dom).toBe(false)

  await hold.av()
})

// =====================================================================
// DE TRE ENKLE
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

test('to raske klikk gir NØYAKTIG én serverhandling', async ({ page }) => {
  await page.goto('/maanedsplan')
  page.on('dialog', (d) => d.accept())
  const { kall } = tellHandlinger(page)
  const knapp = byggeknapp(page)

  // BEGGE I SAMME TIKK, forbi Playwrights egen ventelogikk.
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
  expect(svar[0].revalidert, 'handlingen revaliderte').toBeNull()
})

test('treg oppfriskning (8 s) holder ikke kvitteringen tilbake', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('/maanedsplan')
  page.on('dialog', (d) => d.accept())

  // 8 sekunder er UNDER advarselsterskelen paa 10.
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
