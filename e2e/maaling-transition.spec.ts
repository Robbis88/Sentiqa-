import { expect, test, type Page, type Request } from '@playwright/test'
import { OKTFIL } from './eier'

// =====================================================================
// MIDLERTIDIG DIAGNOSTIKK — hvor lenge staar oppfriskningstransitionen?
// =====================================================================
//
// Spoersmaalet: 10-sekundersterskelen i `HandlingKnapp` — ligger den
// inne i normalvariasjonen, eller trygt over?
//
// Det kan bare avgjoeres paa AKTIV VARIGHET, maalt fra da effekten saa
// `oppfrisker === true` til den saa `false`. Tid fra KLIKK er et annet
// nullpunkt: mellom klikket og transition-start ligger serverhandlingen,
// svaret og commiten som setter kvitteringen.
//
// ---------------------------------------------------------------------
// HVORFOR EGEN FIL OG EGET CI-STEG
// ---------------------------------------------------------------------
//
// Maalingen laa foerst sist i `oppfriskning.spec.ts`. Der sto den
// nedstroems for to tester som MED VILJE holder forespoersler aapne —
// `KLASSIFISER` holder fem RSC-kall i ti sekunder, `treg oppfriskning`
// forsinker alle i aatte. Kjoeringen paa `1dd555c` ga:
//
//     POST next-action   t=0,32 s   status=-1   timings {-1,-1,-1}
//     siste nettverkshendelse: 0,33 s
//
// Serverhandlingen fikk ALDRI svar, og sida var stille i 30 sekunder.
// Vi kunne ikke skille aarsak fra ettervirkning av vaare egne hold.
//
// ALFABETISK FILREKKEFOELGE ER IKKE ISOLASJON. Fila kjoeres i et eget
// CI-steg, mot en base som er resatt rett foer — og resatt igjen rett
// etter, fordi Playwright-oppsettet skriver planrader og ruller inn en
// TOTP-faktor i `auth.mfa_factors`.
//
// ---------------------------------------------------------------------
// INGEN ROUTE-INTERCEPTS, OG DET ER MAALT
// ---------------------------------------------------------------------
//
// Denne fila kaller aldri `page.route`. Hver proeve faar dessuten sin
// EGEN kontekst og side, saa intercepts og hengende forespoersler fra
// noe annet ikke kan foelge med. At koeen faktisk er tom foer klikket,
// telles — det paastaas ikke.
//
// MUTATIONOBSERVER, IKKE POLLING. En advarsel som vises og fjernes paa
// 5 ms skal ikke kunne bli usynlig mellom to proevetakinger.
// =====================================================================

// SPOR ALLTID, ogsaa naar det gaar bra. Et spor fra en VELLYKKET maaling
// er like mye verdt her: det er der vi ser hva som er normalt.
test.use({ trace: 'on' })

// KJOERES BARE I SITT EGET CI-STEG, mot en base som er resatt rett foer
// og resatt igjen rett etter. Uten denne porten ville den ogsaa kjoert
// som en del av den ordinaere suiten - og da maaler den nettopp den
// forurensningen den finnes for aa unngaa.
test.skip(!process.env.MAALING, 'Kjoeres bare med MAALING=1. Se vakter.yml.')

type Nettverk = {
  sendt: number | null
  svar: number | null
  status: number | null
  ferdig: number | null
  feilet: number | null
  feilgrunn: string | null
}

type Hendelse = { hva: string; t: number }

const erHandling = (r: Request) =>
  r.method() === 'POST' && !!r.headers()['next-action']

async function settOppObserver(side: Page) {
  await side.evaluate(() => {
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
          skriv('oppfrisker=' + ((m.target as HTMLElement).getAttribute('data-oppfrisker') ?? '?'))
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
    // HELE BODY: `router.refresh()` kan bytte ut noder, og en observer
    // festet paa skjemaet alene ville sluttet aa se etter det.
    obs.observe(document.body, {
      attributes: true,
      attributeFilter: ['data-oppfrisker', 'disabled'],
      childList: true,
      subtree: true,
    })
    w.__obs = obs
  })
}

test('MAALING: transitionens varighet, tre proever i hver sin kontekst', async ({ browser }) => {
  test.setTimeout(300_000)
  const l = (s: string) => console.log(`  ${s}`)
  const dommer: string[] = []

  l('')
  l('======= TRANSITIONENS VARIGHET — ISOLERT MAALING =======')

  for (let proeve = 1; proeve <= 3; proeve++) {
    // EGEN KONTEKST. Ingen route-intercepts, ingen hengende forespoersler,
    // ingen delt klienttilstand fra forrige proeve.
    const ctx = await browser.newContext({ storageState: OKTFIL })
    const side = await ctx.newPage()

    const ufullfoerte = new Set<Request>()
    const post: Nettverk = {
      sendt: null, svar: null, status: null, ferdig: null, feilet: null, feilgrunn: null,
    }
    let t0 = Date.now()
    const naa = () => Date.now() - t0

    side.on('request', (r) => {
      ufullfoerte.add(r)
      if (erHandling(r) && post.sendt === null) post.sendt = naa()
    })
    side.on('response', (r) => {
      if (erHandling(r.request()) && post.svar === null) {
        post.svar = naa()
        post.status = r.status()
      }
    })
    side.on('requestfinished', (r) => {
      ufullfoerte.delete(r)
      if (erHandling(r) && post.ferdig === null) post.ferdig = naa()
    })
    side.on('requestfailed', (r) => {
      ufullfoerte.delete(r)
      if (erHandling(r) && post.feilet === null) {
        post.feilet = naa()
        post.feilgrunn = r.failure()?.errorText ?? null
      }
    })

    await side.goto('/maanedsplan')
    await expect(side.getByRole('heading', { name: 'Månedsplaner' })).toBeVisible()
    // KOEEN SKAL VAERE TOM FOER VI MAALER. Telles, ikke antas.
    await side.waitForLoadState('networkidle')
    const aapneFoer = ufullfoerte.size

    const knapp = side.getByRole('button', { name: /Bygg .* på nytt/ })
    await expect(knapp).toBeVisible()
    side.on('dialog', (d) => d.accept())

    await settOppObserver(side)
    t0 = Date.now()
    await side.evaluate(() => {
      const w = window as unknown as Record<string, unknown>
      ;(w.__logg as Hendelse[])
        .push({ hva: 'KLIKK', t: Math.round(performance.now() - (w.__t0 as number)) })
    })
    await knapp.click()

    // 30 SEKUNDER, IKKE MER. Uten svar paa 30 s er det et FUNN, ikke en
    // for kort timeout.
    try {
      await side.waitForFunction(() => {
        const f = document.querySelector('input[name="maaned"]')
        return f?.closest('form')?.getAttribute('data-oppfrisker') === 'false'
      }, undefined, { timeout: 30_000 })
    } catch { /* klassifiseres under */ }

    const logg: Hendelse[] = await side.evaluate(() => {
      const w = window as unknown as Record<string, unknown>
      ;(w.__obs as MutationObserver).disconnect()
      return w.__logg as Hendelse[]
    })

    const forst = (p: string) => logg.find((r) => r.hva === p)?.t ?? null
    const klikk = forst('KLIKK') ?? 0
    const laast = forst('knapp-disabled=true')
    const apen = logg.find((r) => r.hva === 'knapp-disabled=false')?.t ?? null
    const kvitt = forst('kvittering+')
    const paa = forst('oppfrisker=true')
    const av = paa === null ? null
      : (logg.find((r) => r.hva === 'oppfrisker=false' && r.t > paa)?.t ?? null)
    const advPaa = forst('advarsel+')
    const advAv = advPaa === null ? null
      : (logg.find((r) => r.hva === 'advarsel-' && r.t > advPaa)?.t ?? null)
    const varighet = paa !== null && av !== null ? av - paa : null

    // ---------------------------------------------------------------
    // KLASSIFISERING. Fire utfall, og de er gjensidig utelukkende.
    // ---------------------------------------------------------------
    let dom: string
    if (post.svar === null) {
      dom = 'SERVERHANDLING UTEN SVAR — POST sendt '
        + post.sendt + ' ms, ingen respons innen 30 s'
        + (post.feilet !== null ? ` (requestfailed ${post.feilet} ms: ${post.feilgrunn})` : '')
    } else if (kvitt === null) {
      dom = 'SVAR IKKE COMMITTET — POST svarte ' + post.status
        + ' paa ' + post.svar + ' ms, men kvitteringen naadde aldri DOM-en'
    } else if (paa === null || av === null) {
      dom = 'UGYLDIG TRANSITIONSMAALING — kvitteringen kom, men '
        + (paa === null ? '`oppfrisker` ble aldri true' : '`oppfrisker` gikk aldri tilbake til false')
    } else if (varighet! < 10_000) {
      dom = 'A  aktiv ' + varighet + ' ms — UNDER terskelen. Fravaer av advarsel er riktig.'
    } else if (advPaa !== null) {
      dom = 'B  aktiv ' + varighet + ' ms — OVER terskelen, og advarselen ble vist. '
        + 'Mekanismen virker, men normal drift treffer terskelen.'
    } else {
      dom = 'C  aktiv ' + varighet + ' ms — OVER terskelen, men advarselen ble ALDRI vist. '
        + 'Timer-/maalelogikken er ufullstendig.'
    }
    dommer.push(`proeve ${proeve}: ${dom}`)

    l('')
    l(`--- proeve ${proeve} ---`)
    l(`aapne forespoersler foer klikk   ${aapneFoer}`)
    l('NETTVERK, serverhandlingen:')
    l(`   request sendt                 ${post.sendt} ms`)
    l(`   response                      ${post.svar} ms   status ${post.status}`)
    l(`   requestfinished               ${post.ferdig} ms`)
    l(`   requestfailed                 ${post.feilet} ms   ${post.feilgrunn ?? ''}`)
    l('DOM-HENDELSER, fra observerstart:')
    for (const r of logg) l(`   ${String(r.t).padStart(7)} ms  ${r.hva}`)
    l('VARIGHETER:')
    l(`   knapp laast minus klikk       ${laast === null ? 'aldri' : laast - klikk} ms`)
    l(`   kvittering minus klikk        ${kvitt === null ? 'aldri' : kvitt - klikk} ms`)
    l(`   knapp aapen minus klikk       ${apen === null ? 'aldri' : apen - klikk} ms`)
    l(`   true-start minus klikk        ${paa === null ? 'aldri' : paa - klikk} ms`)
    l(`   AKTIV VARIGHET true->false    ${varighet === null ? 'aldri' : varighet} ms   (terskel 10 000)`)
    l(`   advarsel vist minus true      ${advPaa === null || paa === null ? 'ikke vist' : advPaa - paa} ms`)
    l(`   advarsel fjernet minus vist   ${advAv === null || advPaa === null ? 'ikke fjernet' : advAv - advPaa} ms`)
    l(`DOM: ${dom}`)

    await ctx.close()
  }

  l('')
  l('--- oppsummert ---')
  for (const d of dommer) l(`   ${d}`)
  l('========================================================')

  // MAALING, IKKE PORT. Ingen av utfallene feller kjoeringen — de skal
  // alle rapporteres. Det eneste som paastaas er at vi i det hele tatt
  // fikk tre proever ut av den.
  expect(dommer, 'maalingen ga ikke tre proever').toHaveLength(3)
})
