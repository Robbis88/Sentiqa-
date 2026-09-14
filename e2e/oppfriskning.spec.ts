import { expect, test, type Page, type Request } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// DIAGNOSTIKK: ER `oppfrisker` EN PAALITELIG MAALING AV RSC-HENTINGEN?
// =====================================================================
//
// `HandlingKnapp` kjoerer `router.refresh()` i sin EGEN `useTransition`.
// Blir den staaende i 10 sekunder, viser knappen en advarsel om at
// visningen ikke kunne oppdateres.
//
// MAALT PAA `a6df5cc`, SAMME SHA, TO KJOERINGER:
//
//   attempt 1   advarsel borte etter        4 ms
//   attempt 2   advarsel borte etter   ALDRI innen 5 000 ms
//
// Begge med alle fem RSC-kall bekreftet ferdige foerst. Det er ikke et
// lesetidspunkt - det er to ulike utfall av samme kode.
//
// ---------------------------------------------------------------------
// TO TILFELLER SOM SER LIKE UT UTENFRA
// ---------------------------------------------------------------------
//
//   A  transitionen settler aldri   `oppfrisker` blir staaende true,
//                                   `true -> false`-grenen kjoerer aldri,
//                                   og `froset` blir derfor staaende.
//                                   Advarselen er da RIKTIG.
//   B  flagget ryddes ikke          `oppfrisker` er false, men
//                                   advarselen staar likevel. Da er
//                                   flagglogikken feil.
//
// De kan ikke skilles uten aa se `oppfrisker`. Derfor baerer skjemaet et
// INERT `data-oppfrisker`-attributt - ingen styling, ingen atferd, ingen
// semantikk for hjelpemidler. (`aria-busy` ville ikke vaert inert: den
// forteller skjermlesere at regionen oppdateres, og da ville et
// diagnostisk behov endret hva brukere opplever.)
//
// ---------------------------------------------------------------------
// `requestfinished` BEVISER IKKE AT REACT HAR COMMITTET
// ---------------------------------------------------------------------
//
// Den sier at nettverkskroppen er mottatt. Mellom den og en oppdatert
// skjerm ligger flight-parsing, render og commit. Denne fila KREVER
// derfor ikke at advarselen forsvinner naar nettverket er ferdig - den
// MAALER hva som skjer, og klassifiserer utfallet.
// =====================================================================

test.use({ storageState: OKTFIL })

type Kall = {
  url: string
  sendt: number
  /** Responsheaderne mottatt. */
  svar: number | null
  status: number | null
  /** Kroppen mottatt. */
  ferdig: number | null
  feilet: number | null
}

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
function lytt(side: Page, t0: () => number) {
  const handling: Kall[] = []
  const rsc: Kall[] = []
  const revalidert: (string | null)[] = []

  const erHandling = (r: Request) =>
    r.method() === 'POST' && !!r.headers()['next-action']
  const listeFor = (r: Request) =>
    erHandling(r) ? handling : r.url().includes('_rsc=') ? rsc : null
  const finn = (liste: Kall[], r: Request, felt: 'svar' | 'ferdig' | 'feilet') =>
    [...liste].reverse().find((k) => k.url === r.url() && k[felt] === null)

  side.on('request', (r) => {
    const liste = listeFor(r)
    if (!liste) return
    liste.push({
      url: r.url(),
      sendt: Date.now() - t0(),
      svar: null,
      status: null,
      ferdig: null,
      feilet: null,
    })
  })
  side.on('response', (r) => {
    const req = r.request()
    const liste = listeFor(req)
    if (!liste) return
    if (erHandling(req)) revalidert.push(r.headers()['x-action-revalidated'] ?? null)
    const k = finn(liste, req, 'svar')
    if (!k) return
    k.svar = Date.now() - t0()
    k.status = r.status()
  })
  side.on('requestfinished', (r) => {
    const liste = listeFor(r)
    const k = liste && finn(liste, r, 'ferdig')
    if (k) k.ferdig = Date.now() - t0()
  })
  side.on('requestfailed', (r) => {
    const liste = listeFor(r)
    const k = liste && finn(liste, r, 'feilet')
    if (k) k.feilet = Date.now() - t0()
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

// =====================================================================
// HVOR LENGE ER `oppfrisker` AKTIV PAA EN VANLIG OPPFRISKNING?
// =====================================================================
//
// FEILEN DENNE RETTER. Attempt 3 paa 2054c93 maalte «oppfrisker -> false
// 10 551 ms» paa en uforsinket oppfriskning, og jeg holdt det tallet opp
// mot terskelen paa 10 000 ms. Det er to ULIKE NULLPUNKTER:
//
//   10 551 ms   maalt fra KLIKKET
//   10 000 ms   maalt fra da effekten saa `oppfrisker === true`
//
// Mellom klikket og transition-start ligger serverhandlingen, svaret og
// commiten som setter kvitteringen. Den avstanden er ikke null - den var
// 531 ms i samme kjoering. Tallene kan altsaa ikke sammenlignes, og
// «terskelen ligger i normalvariasjonen» var en slutning uten grunnlag.
//
// ---------------------------------------------------------------------
// MUTATIONOBSERVER, IKKE POLLING
// ---------------------------------------------------------------------
//
// 100 ms prøvetaking kan ikke se en advarsel som vises og fjernes i
// mellomrommet. Observeren staar i SIDA, startes FOER handlingen, og
// skriver hver overgang med tidsstempel til et array. Da kan ingen
// overgang bli usynlig - den ligger i loggen selv om den varte i 5 ms.
//
// Tre proever i samme kjoering. Variasjonen vi har sett er stor (709,
// 948 og 10 551 ms fra klikk), og ett enkelt tall ville ikke sagt om
// dette er normalen eller et utslag.
// =====================================================================
test('MAALING: hvor lenge staar transitionen paa en uforsinket oppfriskning', async ({ page }) => {
  test.setTimeout(180_000)
  await page.goto('/maanedsplan')
  await expect(page.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
  page.on('dialog', (d) => d.accept())

  const l = (s: string) => console.log(`  ${s}`)
  l('')
  l('===== TRANSITIONENS VARIGHET, MAALT MED MUTATIONOBSERVER =====')

  for (let proeve = 1; proeve <= 3; proeve++) {
    const knapp = byggeknapp(page)
    await expect(knapp).toBeVisible()

    // OBSERVEREN FOERST. Alt som skjer etter dette punktet er logget.
    await page.evaluate(() => {
      const w = window as unknown as Record<string, unknown>
      const t0 = performance.now()
      const logg: { hva: string; t: number }[] = []
      w.__t0 = t0
      w.__logg = logg
      const skriv = (hva: string) =>
        logg.push({ hva, t: Math.round(performance.now() - t0) })

      const felt = document.querySelector('input[name="maaned"]')
      const skjema = felt?.closest('form') as HTMLFormElement | null
      skriv('start:oppfrisker=' + (skjema?.getAttribute('data-oppfrisker') ?? '?'))

      const sjekk = (n: Node, tegn: string) => {
        if (n.nodeType !== 1) return
        const e = n as HTMLElement
        if (e.classList?.contains('sq-oppfrisk-feil')) skriv('advarsel' + tegn)
        if (e.classList?.contains('sq-slett-ok')) skriv('kvittering' + tegn)
        if (e.classList?.contains('sq-slett-feil')) skriv('feilmelding' + tegn)
      }

      const obs = new MutationObserver((muts) => {
        for (const m of muts) {
          if (m.type === 'attributes' && m.attributeName === 'data-oppfrisker') {
            skriv('oppfrisker=' + (m.target as HTMLElement).getAttribute('data-oppfrisker'))
          }
          if (m.type === 'attributes' && m.attributeName === 'disabled') {
            skriv('knapp-disabled=' + String((m.target as HTMLButtonElement).disabled))
          }
          if (m.type === 'childList') {
            m.addedNodes.forEach((n) => sjekk(n, '+'))
            m.removedNodes.forEach((n) => sjekk(n, '-'))
          }
        }
      })
      // HELE BODY. `router.refresh()` kan bytte ut noder, og en observer
      // festet paa skjemaet alene ville sluttet aa se etter det.
      obs.observe(document.body, {
        attributes: true,
        attributeFilter: ['data-oppfrisker', 'disabled'],
        childList: true,
        subtree: true,
      })
      w.__obs = obs
    })

    await page.evaluate(() => {
      const w = window as unknown as Record<string, unknown>
      ;(w.__logg as { hva: string; t: number }[])
        .push({ hva: 'KLIKK', t: Math.round(performance.now() - (w.__t0 as number)) })
    })
    await knapp.click()

    // Vent til transitionen er over. Er den ikke over, leser vi loggen
    // likevel - en diagnose skal ikke feile paa det den maaler.
    try {
      await page.waitForFunction(() => {
        const felt = document.querySelector('input[name="maaned"]')
        return felt?.closest('form')?.getAttribute('data-oppfrisker') === 'false'
      }, undefined, { timeout: 30_000 })
    } catch { /* logges som «aldri» under */ }

    const logg = await page.evaluate(() => {
      const w = window as unknown as Record<string, unknown>
      ;(w.__obs as MutationObserver).disconnect()
      return w.__logg as { hva: string; t: number }[]
    })

    const foerste = (p: string) => logg.find((r) => r.hva === p)?.t ?? null
    const klikk = foerste('KLIKK') ?? 0
    const paa = logg.find((r) => r.hva === 'oppfrisker=true')?.t ?? null
    const av = paa === null ? null
      : (logg.find((r) => r.hva === 'oppfrisker=false' && r.t > paa)?.t ?? null)
    const advPaa = foerste('advarsel+')
    const advAv = advPaa === null ? null
      : (logg.find((r) => r.hva === 'advarsel-' && r.t > advPaa)?.t ?? null)
    const kvitt = foerste('kvittering+')

    const varighet = paa !== null && av !== null ? av - paa : null

    const dom = varighet === null
      ? 'UAVKLART  transitionen ble aldri ferdig innen 30 s'
      : varighet < 10_000
        ? 'A  transitionen var aktiv ' + varighet + ' ms - UNDER terskelen. '
          + 'Fravaer av advarsel er riktig.'
        : advPaa !== null
          ? 'B  transitionen var aktiv ' + varighet + ' ms - OVER terskelen, '
            + 'og advarselen ble vist. Mekanismen virker, men normal drift '
            + 'treffer terskelen.'
          : 'C  transitionen var aktiv ' + varighet + ' ms - OVER terskelen, '
            + 'men advarselen ble ALDRI vist. Timer-/maalelogikken er ufullstendig.'

    l('')
    l(`--- proeve ${proeve} ---`)
    l('ABSOLUTT, fra observerstart:')
    for (const r of logg) l(`   ${String(r.t).padStart(7)} ms  ${r.hva}`)
    l('VARIGHETER:')
    l(`   true-start minus klikk        ${paa === null ? 'aldri' : paa - klikk} ms`)
    l(`   false minus true-start        ${varighet === null ? 'aldri' : varighet} ms   (terskel 10 000)`)
    l(`   kvittering minus klikk        ${kvitt === null ? 'aldri' : kvitt - klikk} ms`)
    l(`   advarsel vist minus true-start ${advPaa === null || paa === null ? 'ikke vist' : advPaa - paa} ms`)
    l(`   advarsel fjernet minus vist   ${advAv === null || advPaa === null ? 'ikke fjernet' : advAv - advPaa} ms`)
    l(`DOM: ${dom}`)

    // MAALING, IKKE PORT. Det eneste som paastaas er at observeren
    // faktisk saa noe - uten det maaler proeven ingenting.
    expect(paa, 'observeren saa aldri at transitionen startet').not.toBeNull()
    expect(kvitt, 'kvitteringen kom aldri').not.toBeNull()
  }

  l('==============================================================')
})
