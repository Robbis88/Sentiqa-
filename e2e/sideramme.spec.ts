import { test, expect, type Page } from '@playwright/test'
import { OKTFIL, REDAKTOR_OKTFIL } from './eier'

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

/**
 * Beviser bredden for én rute: rute → Monster → SPALTE → målt bredde.
 *
 * Leser fra `maal()` som alt annet, så det finnes bare ett sted som vet
 * hvilke elementer som teller. Denne påstår KUN bredde — `bevisSide`
 * legger til overflyt- og plasskontrollene.
 */
async function bevisBredde(page: Page, sti: string, ventet: 'smal' | 'bred') {
  await page.goto(sti)
  await expect(page.locator('main.innhold'), sti).toHaveAttribute('data-bredde', ventet)
  await expect(page.locator('.sq-sideramme'), `${sti}: ikke migrert`).toHaveCount(1)
  await expect(page.locator('.sq-sideramme')).toBeVisible()
  const m = await maal(page)
  const fasit = ventet === 'bred' ? m.rom : Math.min(SMAL, m.rom)
  expect(
    Math.abs(m.ramme - fasit),
    `${sti} (${ventet}): rammen er ${Math.round(m.ramme)} px, spalta gir `
    + `${Math.round(m.rom)} px, fasit ${Math.round(fasit)} px`,
  ).toBeLessThan(2)
  return m
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
    // stilles av `maal().dokumentIRammen`.
    //
    // (Første utgave målte `document.scrollWidth` her og var rød på /salg
    // med 129 px. Jeg forklarte det med `.tabellramme` — se side.tsx. Den
    // forklaringen holdt ikke: /skills gir NØYAKTIG samme 129 px uten å ha
    // en tabell i det hele tatt. Derfor navngir måleren nå
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
// `.sq-sideramme` aa maale, og `bevisBredde` feiler paa antallet. Det
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
// Ingen av de fire har tabell. Det var med vilje - da kan et tabellbredt
// innhold ikke forveksles med en breddefeil. (Utvalget ble gjort mens jeg
// trodde `.tabellramme` forklarte dokumentrullingen paa /salg. Den
// forklaringen er motbevist, men kriteriet er fortsatt riktig av en annen
// grunn: en tabell er det bredeste et innhold kan bli.)
//
// HVA SOM FAKTISK MAALES
//
// «Handlinger forsvinner ikke utenfor rammen», «lange tekster bryter» og
// «metadata kolliderer ikke» er tre spoersmaal med ett felles maal: ikke
// noe SKAL stikke utenfor rammen. `maal().utenfor` maaler nettopp det,
// paa hvert eneste synlige etterkommerelement, og navngir synderen.
// Absolutt- og fastposisjonerte elementer er utelatt - et sidepanel eller
// en meny SKAL kunne ligge utenfor spalta.
// =====================================================================

const BOELGE2 = ['/skills', '/puls', '/varsler', '/nyheter']


// =====================================================================
// ÉN MÅLER, FORDI JEG SKREV DEN SAMME FEILEN TRE GANGER
//
// `utenforRammen`, `dokumentoverflyt` og `trangtInnhold` var tre
// funksjoner med hver sin kopi av «hvilke elementer teller». Alle tre
// manglet det samme: at et element inne i en VANNRETT RULLEBANE skal
// være bredere enn rammen — det er hele poenget med en rullebane.
//
// Jeg oppdaget mangelen én funksjon om gangen, og hver CI-kjøring
// avslørte den neste kopien. Tre røde kjøringer for én misforståelse.
// Derfor er de nå én måling med ett felles regelsett; en fjerde kopi
// finnes ikke å glemme.
//
// ---------------------------------------------------------------------
// HVA SOM IKKE TELLER, OG HVORFOR
//
// Hvert unntak er en dør ut av målingen. Udokumentert blir de over tid
// til en «alt er greit»-ventil — testen ser grønn ut mens den måler
// ingenting. Derfor står de her med grunn:
//
// 1. UTENFOR FLYTEN — `position: absolute | fixed`
//    Deltar ikke i spaltas layout. `.sq-skjult` er nettopp dette: 132 px
//    tekst i en 1 px boks, med vilje, så skjermlesere får den og øyet
//    ikke. Uten unntaket felte den /produksjonsplan i CI.
//
// 2. I EN BEVISST RULLEBANE — `overflow-x: auto | scroll` på elementet
//    ELLER en forfar. `.kort { overflow-x: auto }` på mobil er systemets
//    dokumenterte måte å bære brede tabeller på. `.pp-tabell` er 546 px
//    i en 362 px ramme og ruller i kortet sitt. Det er mekanismen som
//    virker. FORFAR-SJEKKEN er det som skiller den fra en ekte overflyt,
//    og det var den jeg glemte tre ganger.
//
// 3. IKKE LAGT UT — `display: none`, `visibility: hidden`, null størrelse.
//    Det finnes ingen boks å ikke få plass i.
//
// 4. `clientWidth === 0` — DEN FARLIGSTE, og bare for «trangt».
//    En kollapset boks vil ALDRI rapportere at innholdet ikke får plass.
//    Unntaket er nødvendig, men et element som feilaktig er null bredt
//    går stille forbi. Faller en side sammen slik, må `utenfor` eller
//    `dokument` ta den — ikke `trangt`.
//
// Sikkerhetsnettet under alle fire er `dokument`: den måler det brukeren
// faktisk merker, at siden ruller sideveis.
// =====================================================================

type Maaling = {
  /** Rammens egen bredde, og spalta den fikk. */
  ramme: number
  rom: number
  /** Synlige etterkommere som stikker utenfor rammen. */
  utenfor: string[]
  /** Innhold som ikke får plass i sin egen boks. */
  trangt: string[]
  /** Dokumentets sideveis overflyt, og hvem som forårsaker den. */
  dokumentPx: number
  /** Ytterste syndere — hele dokumentet, inkludert skallet. */
  dokumentAlle: string[]
  /** …og de av dem som ligger inne i rammen. Bare disse er sidas ansvar. */
  dokumentIRammen: string[]
}

async function maal(page: Page): Promise<Maaling> {
  return page.evaluate(() => {
    const rot = document.documentElement
    const innhold = document.querySelector('main.innhold')!
    const ramme = document.querySelector('.sq-sideramme')
    if (!ramme) throw new Error('fant ingen .sq-sideramme')

    const cs = getComputedStyle(innhold)
    const rom = innhold.clientWidth
      - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight)
    const rammeBoks = ramme.getBoundingClientRect()

    const iRullebane = (el: Element, stopp: Element | null): boolean => {
      let n: Element | null = el
      while (n && n !== stopp) {
        const o = getComputedStyle(n).overflowX
        if (o === 'auto' || o === 'scroll') return true
        n = n.parentElement
      }
      return false
    }
    const navnet = (el: Element) =>
      el.tagName.toLowerCase()
      + (typeof el.className === 'string' && el.className.trim()
        ? '.' + el.className.trim().split(/\s+/).join('.') : '')

    const utenfor: string[] = []
    const trangt: string[] = []
    for (const el of Array.from(ramme.querySelectorAll('*'))) {
      const s = getComputedStyle(el)
      if (s.position === 'absolute' || s.position === 'fixed') continue
      if (s.display === 'none' || s.visibility === 'hidden') continue
      if (iRullebane(el, ramme.parentElement)) continue

      const b = el.getBoundingClientRect()
      if (b.width !== 0 || b.height !== 0) {
        if (b.right > rammeBoks.right + 1 || b.left < rammeBoks.left - 1) {
          utenfor.push(`${navnet(el)} (${Math.round(b.left)}–${Math.round(b.right)} mot `
            + `rammens ${Math.round(rammeBoks.left)}–${Math.round(rammeBoks.right)})`)
        }
      }
      if (el.clientWidth > 0 && el.scrollWidth > el.clientWidth + 1) {
        trangt.push(`${navnet(el)}: innhold ${el.scrollWidth} px i en boks på `
          + `${el.clientWidth} px (white-space: ${s.whiteSpace})`)
      }
    }

    const dokumentPx = rot.scrollWidth - rot.clientWidth
    const alle: Element[] = []
    if (dokumentPx > 1) {
      for (const el of Array.from(document.body.querySelectorAll('*'))) {
        const s = getComputedStyle(el)
        if (s.display === 'none' || s.visibility === 'hidden') continue
        if (s.position === 'fixed') continue
        if (iRullebane(el, document.body)) continue
        const b = el.getBoundingClientRect()
        if (b.width === 0 && b.height === 0) continue
        if (b.right <= rot.clientWidth + 1) continue
        if (alle.some((f) => f.contains(el))) continue
        alle.push(el)
      }
    }
    const beskriv = (el: Element) => {
      const b = el.getBoundingClientRect()
      const s = getComputedStyle(el)
      return `${navnet(el)} [${Math.round(b.left)}→${Math.round(b.right)}] `
        + `w=${Math.round(b.width)} min-w=${s.minWidth} overflow-x=${s.overflowX}`
    }

    return {
      ramme: rammeBoks.width,
      rom,
      utenfor: utenfor.slice(0, 6),
      trangt: trangt.slice(0, 6),
      dokumentPx,
      dokumentAlle: alle.slice(0, 6).map(beskriv),
      dokumentIRammen: alle.filter((el) => ramme.contains(el)).slice(0, 6).map(beskriv),
    }
  })
}

/** Alle påstandene en migrert side skal bestå, på gjeldende viewport. */
async function bevisSide(page: Page, sti: string, ventet: 'smal' | 'bred') {
  await page.goto(sti)
  await expect(page.locator('main.innhold'), sti).toHaveAttribute('data-bredde', ventet)
  await expect(page.locator('.sq-sideramme'), `${sti}: ikke migrert`).toHaveCount(1)
  await expect(page.locator('.sq-sideramme')).toBeVisible()

  const m = await maal(page)
  const fasit = ventet === 'bred' ? m.rom : Math.min(SMAL, m.rom)
  expect(
    Math.abs(m.ramme - fasit),
    `${sti} (${ventet}): rammen er ${Math.round(m.ramme)} px, spalta gir `
    + `${Math.round(m.rom)} px, fasit ${Math.round(fasit)} px`,
  ).toBeLessThan(2)

  expect(m.utenfor, `${sti}: innhold utenfor rammen:\n  ${m.utenfor.join('\n  ')}`)
    .toEqual([])
  expect(m.trangt, `${sti}: innhold uten plass i sin egen boks:\n  ${m.trangt.join('\n  ')}`)
    .toEqual([])
  expect(
    m.dokumentIRammen,
    `${sti}: innhold i rammen skyver dokumentet (${m.dokumentPx} px totalt).\n`
    + `  I rammen:\n    ${m.dokumentIRammen.join('\n    ')}\n`
    + `  Alle syndere (skallet inkludert):\n    ${m.dokumentAlle.join('\n    ')}`,
  ).toEqual([])
  return m
}

test.describe('bølge 2 — liste blir smal', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const bredde of [1440, 1600]) {
    test(`kjeden holder på ${bredde} px`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: 1000 })
      for (const sti of BOELGE2) {
        const m = await bevisSide(page, sti, 'smal')
        // Spalta er romslig nok på begge bredder, så rammen skal TREFFE
        // 880 — ikke bare «ikke mer enn».
        expect(m.rom, `${sti}: spalta er bare ${Math.round(m.rom)} px`).toBeGreaterThan(SMAL)
        expect(Math.round(m.ramme), `${sti} på ${bredde} px`).toBe(SMAL)
      }
    })
  }

  test('mobil: rammen og innholdet holder seg innenfor viewporten', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    for (const sti of BOELGE2) {
      const m = await bevisSide(page, sti, 'smal')
      expect(m.ramme, `${sti}: rammen er bredere enn spalta på mobil`)
        .toBeLessThanOrEqual(m.rom + 1)
    }
  })

  test('avvisningssida har samme bredde som sida den avviser', async ({ page }) => {
    // /kunnskap avviser butikksjefen. Før bølge 2 fikk hun fullbredde der
    // og 880 px på sidene hun har tilgang til — samme rute, to bredder,
    // avhengig av hvem som ser. Avvisningen er også en tilstand av sida.
    await page.setViewportSize({ width: 1440, height: 1000 })
    await bevisSide(page, '/kunnskap', 'smal')
  })
})

// =====================================================================
// BØLGE 3 — ARBEIDSFLYT
//
//   /avvik            er en `redirect('/ikmat')`. Ingen UI, ingen bredde,
//                     ingenting å migrere eller måle.
//   /bemanning        ukekalender: 7 dagkolonner + fast klokkekolonne
//   /produksjonsplan  7 faste kolonner, to skjules på mobil.
//                     DUAL-SHELL: samme rute serverer også TabletSkall,
//                     og den grenen er med vilje ikke pakket inn.
//
// DEN KRITISKE: /bemanning KOMPRIMERES, DEN FLYTER IKKE OVER
//
// `.bem-kalender` har `table-layout: fixed`. Ved 1316 px får hver dag
// ~178 px, ved 880 ~115 px. Tabellen stikker ALDRI utenfor — den bare
// klemmes. Et øyemål er ikke et kriterium, så `maal().trangt` stiller
// det mekaniske spørsmålet i stedet: finnes det innhold som ikke får
// plass i sin egen boks?
// =====================================================================

const BOELGE3 = ['/bemanning', '/produksjonsplan']

test.describe('bølge 3 — arbeidsflyt blir smal', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  for (const bredde of [1440, 1600]) {
    test(`kjeden holder på ${bredde} px`, async ({ page }) => {
      await page.setViewportSize({ width: bredde, height: 1000 })
      for (const sti of BOELGE3) {
        const m = await bevisSide(page, sti, 'smal')
        expect(m.rom, `${sti}: spalta er bare ${Math.round(m.rom)} px`).toBeGreaterThan(SMAL)
        expect(Math.round(m.ramme), `${sti} på ${bredde} px`).toBe(SMAL)
      }
    })
  }

  test('mobil: rammen og innholdet holder seg innenfor viewporten', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    for (const sti of BOELGE3) {
      const m = await bevisSide(page, sti, 'smal')
      expect(m.ramme, `${sti}: rammen er bredere enn spalta på mobil`)
        .toBeLessThanOrEqual(m.rom + 1)
    }
  })
})

// =====================================================================
// BOELGE 4 — DE SISTE FIRE, OG DEN ENE SOM IKKE SKAL MIGRERES
//
// Denne boelgen gaar MOTSATT VEI av 2 og 3: alle tre var 880 px (de
// bruker kort) og skal bli brede. Det er foerste gang kontrakten
// UTVIDER en spalte i stedet for aa stramme den, saa fasiten
// `ramme == rom` er den som proeves.
//
//   /analyse      analyse   880 -> bred   eier (retailer_admin, TOTP)
//   /lederstotte  analyse   880 -> bred   butikksjef
//   /plattform    dashbord  880 -> bred   plattform-redaktoer (TOTP)
//
// /sikkerhet ER IKKE MED, OG DET ER ET FUNN
//
// Den ligger paa `src/app/sikkerhet/page.tsx` - UTENFOR `(beskyttet)`.
// Den rendrer sin egen `<main className="logg-inn">` med
// `.kort.sq-smal-flate` og `<footer className="auth-bunn">`, altsaa
// innloggingsflatens formspraak. Det er en autentiseringsside, ikke en
// innstillingsside i desktopskallet: den har verken `.innhold` eller
// `data-bredde`, og en Sideramme der ville vaert inert.
//
// `RUTEMONSTER` sier `innstillinger`. Det er feil klassifisering, ikke
// feil bredde - og etter regelen skal det rapporteres, ikke lappes.
// =====================================================================

test.describe('bølge 4 — analyse og dashbord blir brede', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 1000 })
  })

  test('/lederstotte: analyse → bred → målt', async ({ page }) => {
    await loggInn(page)
    await bevisSide(page, '/lederstotte', 'bred')
  })

  test.describe('eierens flate', () => {
    test.use({ storageState: OKTFIL })
    test('/analyse: analyse → bred → målt', async ({ page }) => {
      await page.setViewportSize({ width: 1600, height: 1000 })
      const m = await bevisSide(page, '/analyse', 'bred')
      // Den VAR 880 px. Nå skal den fylle spalta, som er bredere.
      expect(m.ramme, '/analyse fyller ikke spalta').toBeGreaterThan(SMAL)
    })
  })

  test.describe('plattform-redaktørens flate', () => {
    test.use({ storageState: REDAKTOR_OKTFIL })
    test('/plattform: dashbord → bred → målt', async ({ page }) => {
      await page.setViewportSize({ width: 1600, height: 1000 })
      const m = await bevisSide(page, '/plattform', 'bred')
      expect(m.ramme, '/plattform fyller ikke spalta').toBeGreaterThan(SMAL)
    })
  })

  test('mobil: de brede kollapser til viewporten', async ({ page }) => {
    // En `bred` side har ingen maksbredde. Da er det `width: 100%` og
    // `min-width: 0` på barna som holder den inne — nettopp det som
    // manglet da rammen ble skrevet.
    await page.setViewportSize({ width: 390, height: 844 })
    await loggInn(page)
    const m = await bevisSide(page, '/lederstotte', 'bred')
    expect(m.ramme, '/lederstotte er bredere enn spalta på mobil')
      .toBeLessThanOrEqual(m.rom + 1)
  })
})
