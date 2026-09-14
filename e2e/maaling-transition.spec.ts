import { expect, test, type Page, type Request } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// A/B-KONTROLL: PAAVIRKER MUTATIONOBSERVEREN AT HANDLINGEN SVARER?
// =====================================================================
//
// Denne fila MAALER IKKE transitionens varighet. Den avgjoer én ting:
// om en MutationObserver paa `document.body` henger sammen med at
// serverhandlingen ikke svarer.
//
// ---------------------------------------------------------------------
// HVA SOM ER UTELUKKET FOER DENNE
// ---------------------------------------------------------------------
//
// Paa `6a655a0`, tre proever paa fersk base i hver sin kontekst:
//
//   POST sendt 40/45/41 ms   response ALDRI   requestfinished ALDRI
//   aapne forespoersler foer klikk: 0 i alle tre
//   sampler: 6 tilkoblinger, 4 ledige, 0 laasventing, 0 blocking_pids
//   ingen sporring fra handlingen naadde basen i det hele tatt
//
// Testrekkefoelge, tilkoblingssult, laasventing og reset-forurensning
// er dermed avkreftet. I samme kjoering gikk 483 andre tester gjennom,
// flere av dem paa den SAMME knappen.
//
// Den eneste strukturelle forskjellen som staar igjen er observeren.
// Jeg har ingen mekanisme som forklarer hvordan en klientside-observer
// stopper et serversvar - og derfor skal den maales, ikke forklares.
//
// ---------------------------------------------------------------------
// REVERSERT REKKEFOELGE
// ---------------------------------------------------------------------
//
//   1  UTEN    2  MED    3  MED    4  UTEN
//
// Uten reversering ville «foerste handling varmer serveren» og «foerste
// handling endrer basen» sett helt like ut som en observereffekt.
// Henger 2 og 3 mens 1 og 4 svarer, kan ingen av dem forklare det.
//
// ALT ANNET ER LIKT: samme URL, bruker, knapp, dialog, handling,
// ventelogikk, timeout og nettverkslyttere. Ingen route-intercepts,
// ingen kunstig RSC-forsinkelse. Ogsaa settlevinduet paa ett sekund
// staar i BEGGE variantene, saa tidsforloepet er identisk.
// =====================================================================

test.use({ trace: 'on' })

test.skip(!process.env.MAALING, 'Kjoeres bare med MAALING=1. Se vakter.yml.')

const erHandling = (r: Request) =>
  r.method() === 'POST' && !!r.headers()['next-action']

type Teller = { callbacks: number; mutasjoner: number; tid: number }

/**
 * Minimal observer.
 *
 * Skriver BARE til en vanlig array. Ingen DOM-skriving, ingen
 * layoutlesing, ingen locatorer, ingen attributtendring - saa
 * callbacken har ingenting aa observere av sitt eget arbeid, og kan
 * ikke lage en loekke.
 *
 * Det paastaas ikke: `settle`-vinduet under maaler det. Staar sida
 * stille i ett sekund og telleren likevel vokser, observerer den seg
 * selv.
 */
async function settOppObserver(side: Page) {
  await side.evaluate(() => {
    const w = window as unknown as Record<string, unknown>
    const n: { callbacks: number; mutasjoner: number; tid: number; logg: string[] } =
      { callbacks: 0, mutasjoner: 0, tid: 0, logg: [] }
    w.__n = n
    const obs = new MutationObserver((muts) => {
      const t0 = performance.now()
      n.callbacks += 1
      n.mutasjoner += muts.length
      for (const m of muts) n.logg.push(m.type)
      n.tid += performance.now() - t0
    })
    obs.observe(document.body, { attributes: true, childList: true, subtree: true })
    w.__obs = obs
  })
}

async function lesTeller(side: Page): Promise<Teller | null> {
  return side.evaluate(() => {
    const w = window as unknown as Record<string, unknown>
    const n = w.__n as Teller | undefined
    if (!n) return null
    return { callbacks: n.callbacks, mutasjoner: n.mutasjoner, tid: Math.round(n.tid) }
  })
}

type Utfall = {
  proeve: number
  observer: boolean
  sendt: number | null
  svar: number | null
  status: number | null
  ferdig: number | null
  feilet: number | null
  feilgrunn: string | null
  knappAktiv: boolean
  kvittering: string | null
  iRo: Teller | null
  etter: Teller | null
}

test('A/B: henger handlingen bare naar observeren staar paa?', async ({ browser }) => {
  test.setTimeout(300_000)
  const l = (s: string) => console.log(`  ${s}`)
  const utfall: Utfall[] = []

  // UTEN, MED, MED, UTEN.
  const plan = [false, true, true, false]

  l('')
  l('===== A/B-KONTROLL: MUTATIONOBSERVER OG SERVERHANDLINGEN =====')

  for (let i = 0; i < plan.length; i++) {
    const medObserver = plan[i]
    const ctx = await browser.newContext({ storageState: OKTFIL })
    const side = await ctx.newPage()

    const post = {
      sendt: null as number | null, svar: null as number | null,
      status: null as number | null, ferdig: null as number | null,
      feilet: null as number | null, feilgrunn: null as string | null,
    }
    let t0 = Date.now()
    const naa = () => Date.now() - t0

    side.on('request', (r) => { if (erHandling(r) && post.sendt === null) post.sendt = naa() })
    side.on('response', (r) => {
      if (erHandling(r.request()) && post.svar === null) {
        post.svar = naa()
        post.status = r.status()
      }
    })
    side.on('requestfinished', (r) => { if (erHandling(r) && post.ferdig === null) post.ferdig = naa() })
    side.on('requestfailed', (r) => {
      if (erHandling(r) && post.feilet === null) {
        post.feilet = naa()
        post.feilgrunn = r.failure()?.errorText ?? null
      }
    })

    await side.goto('/maanedsplan')
    await expect(side.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
    await side.waitForLoadState('networkidle')

    const knapp = side.getByRole('button', { name: /Bygg .* på nytt/ })
    await expect(knapp).toBeVisible()
    side.on('dialog', (d) => d.accept())

    if (medObserver) await settOppObserver(side)

    // SETTLEVINDU I BEGGE VARIANTENE, saa tidsforloepet er likt. For
    // observervarianten er det samtidig loekkekontrollen: en telling
    // som vokser mens sida staar stille, observerer seg selv.
    await side.waitForTimeout(1_000)
    const iRo = medObserver ? await lesTeller(side) : null

    t0 = Date.now()
    // Loeftet opprettes FOER klikket i begge variantene.
    const svarLoftet = side
      .waitForResponse((r) => erHandling(r.request()), { timeout: 30_000 })
      .catch(() => null)
    await knapp.click()
    await svarLoftet

    const etter = medObserver ? await lesTeller(side) : null
    const dom = await side.evaluate(() => {
      const felt = document.querySelector('input[name="maaned"]')
      const skjema = felt?.closest('form') as HTMLFormElement | null
      const k = skjema?.querySelector('button') as HTMLButtonElement | null
      return {
        knappAktiv: !!k && !k.disabled,
        kvittering: skjema?.querySelector('.sq-slett-ok')?.textContent ?? null,
      }
    })

    if (medObserver) {
      await side.evaluate(() => {
        const w = window as unknown as Record<string, unknown>
        ;(w.__obs as MutationObserver).disconnect()
      })
    }

    utfall.push({
      proeve: i + 1, observer: medObserver,
      ...post, knappAktiv: dom.knappAktiv, kvittering: dom.kvittering,
      iRo, etter,
    })

    await ctx.close()
  }

  for (const u of utfall) {
    l('')
    l(`--- proeve ${u.proeve} · observer ${u.observer ? 'PAA' : 'AV'} ---`)
    l(`   POST sendt            ${u.sendt} ms`)
    l(`   response              ${u.svar === null ? 'ALDRI' : u.svar + ' ms'}   status ${u.status}`)
    l(`   requestfinished       ${u.ferdig === null ? 'aldri' : u.ferdig + ' ms'}`)
    l(`   requestfailed         ${u.feilet === null ? 'aldri' : u.feilet + ' ms  ' + u.feilgrunn}`)
    l(`   knappen aktiv etterpaa ${u.knappAktiv}`)
    l(`   kvittering            ${u.kvittering === null ? 'ALDRI' : JSON.stringify(u.kvittering.slice(0, 60))}`)
    if (u.observer) {
      l(`   observer i ro (1 s)   callbacks ${u.iRo?.callbacks}  mutasjoner ${u.iRo?.mutasjoner}  tid ${u.iRo?.tid} ms`)
      l(`   observer etter klikk  callbacks ${u.etter?.callbacks}  mutasjoner ${u.etter?.mutasjoner}  tid ${u.etter?.tid} ms`)
      l(`   loekkekontroll        ${(u.iRo?.callbacks ?? 0) === 0 ? 'OK - null callbacks mens sida sto stille' : 'MISTENKELIG - telte mens sida sto stille'}`)
    }
  }

  const uten = utfall.filter((u) => !u.observer)
  const med = utfall.filter((u) => u.observer)
  const svarte = (u: Utfall) => u.svar !== null
  const alleUtenSvarte = uten.every(svarte)
  const ingenMedSvarte = med.every((u) => !svarte(u))
  const alleSvarte = utfall.every(svarte)
  const ingenSvarte = utfall.every((u) => !svarte(u))
  const blandetUten = uten.some(svarte) && uten.some((u) => !svarte(u))
  const blandetMed = med.some(svarte) && med.some((u) => !svarte(u))

  const dom = blandetUten || blandetMed
    ? 'BLANDET INNEN SAMME VARIANT - kontrollen er ikke deterministisk. '
      + 'Ingen aarsakskonklusjon skal trekkes.'
    : alleUtenSvarte && ingenMedSvarte
      ? 'OBSERVEREN ER STERKT IMPLISERT - begge uten svarte, begge med hang. '
        + 'Maalemetoden forkastes.'
      : ingenSvarte
        ? 'ALLE FIRE HANG - observeren er frikjent. Undersoek handlingen og '
          + 'serveren foer databasekallet.'
        : alleSvarte
          ? 'ALLE FIRE SVARTE - den tidligere hengingen er IKKE reprodusert. '
            + 'Observeren er verken bevist skyldig eller uskyldig.'
          : 'UVENTET MOENSTER - se tabellen over.'

  l('')
  l(`DOM: ${dom}`)
  l('==============================================================')

  // MAALING, IKKE PORT. Alle fire utfall skal rapporteres.
  expect(utfall, 'kontrollen ga ikke fire proever').toHaveLength(4)
})
