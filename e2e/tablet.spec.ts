import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Bolge 5: nettbrettet.
//
// Dette er ikke responsiv desktop. Det er en egen operativ flate, og de
// to spor ikke om det samme:
//
//   Desktop   Hva krever oppmerksomhet, og hvorfor?
//   Nettbrett Hva skal jeg gjore naa?
//
// Bevisene under maaler nettopp det skillet - at flatene IKKE ligner
// hverandre - i tillegg til de fire tingene som gjelder for enhver
// arbeidsflate: rolle, treffomraade, kontrast og aksessibilitet.
//
// TO NETTBRETT MED VILJE. `nettbrett@` staar i den tomme Testkjeden og
// beviser tomtilstanden. `nettbrett-analyse@` staar i Analysekjeden med
// IK-mat-punkter aa maale, og beviser arbeidsflyten. En koe uten
// oppgaver er ikke en koe.
// =====================================================================

const TOMT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }
const MED_DATA = {
  epost: 'nettbrett-analyse@test.sentiqa.no',
  passord: 'test-nettbrett-analyse-2026',
}
/**
 * Rutene nettbrettet naar. Samme mengde som `naabart()` gir rollen.
 *
 * FIRE KOM TIL I BOLGE 5, og ingen av dem er nye flater. `/sjekkpunkt`
 * var koens hoyest prioriterte rad, `/ikmat/maaling` er der temperaturen
 * faktisk skrives, `/stempling` er timene hennes og `/produksjonsplan`
 * sto i koen hver dag. Alle fire ble naadd av nettbrettet lenge for de
 * sto her - de ble bare aldri MAALT. Treffomraade, kontrast og
 * desktop-lekkasje var usjekket paa nettopp de flatene der arbeidet skjer.
 *
 * `/vaar-stasjon` er den eneste virkelig nye.
 */
const RUTENE = [
  '/oversikt',
  '/rutiner',
  '/anvisninger',
  '/lenker',
  '/ikmat',
  '/ikmat/maaling',
  '/merker',
  '/mine-opplysninger',
  '/nyheter',
  '/produksjonsplan',
  '/sjekkpunkt',
  '/stempling',
  '/vaar-stasjon',
  '/varsler',
]

/**
 * Samme maalestokk som design-skrallen bruker (src/lib/redesign/design.ts).
 *
 * BEGGE TIDLIGERE UTGAVER HAR VAERT HALVBLINDE, hver paa sin maate. Den
 * forste lette bare etter surrogatpar og fant ikke tegn merket med
 * U+FE0F. Den andre la til den varianten - og var fortsatt blind for
 * hake-i-boks (U+2705) og utropstegn (U+2757), som er ETT kodepunkt inne
 * i BMP og tegnes som emoji uten aa be om det. De to sto paa nettbrettet
 * gjennom hele bolge 5 mens tellingen sa null, og utropstegnet bar
 * kritikalitet helt alene.
 *
 * Unicode har navnet paa skillet vi mente: `Emoji_Presentation`. Naa
 * slipper vi aa gjette paa kodepunktomraader - og hake, kryss, trekant
 * og piler gaar fortsatt fri, fordi de er tekst som stotter et ord.
 *
 * Bygget fra en streng framfor en literal, som for: monsteret er rene
 * kodepunkt-escapes, og de overlever ikke alltid en tur gjennom et
 * verktoy som normaliserer tegn.
 */
const EMOJI = new RegExp('\\p{Emoji_Presentation}|\\p{Extended_Pictographic}\\uFE0F', 'gu')

/**
 * Popupene settes paa snooze foer noe navigeres.
 *
 * HVORFOR: sjekkpunkt-popupen aapner seg selv 2,5 sekunder etter
 * lasting, og fra bolge 5 har analysekjeden faktiske sjekkpunkter aa
 * vise. Da ville den lagt seg over flata midt i en axe-kjoring eller en
 * treffomraademaaling, og bevisene hadde blitt flakete - gronne eller
 * roede etter hvor fort maskinen var den dagen.
 *
 * Popupen er et DYTT, ikke en flate. Den stiller de samme spoersmaalene
 * som /sjekkpunkt, og DEN ruta har egne bevis nedenfor - der svaret
 * faktisk gis. Aa slaa av dyttet mens vi maaler sida under, maaler
 * dermed ikke bort noe: emojiene i popupen fanges av design-skrallen,
 * som leser kilden og ikke DOM-en.
 *
 * `addInitScript` kjorer for hver navigasjon, ogsaa etter innlogging.
 */
async function loggInn(page: Page, b: { epost: string; passord: string }) {
  await page.addInitScript(() => {
    try {
      localStorage.setItem('sjekk-vist', String(Date.now()))
    } catch {
      /* privat modus - da aapner popupen seg, og det taaler vi */
    }
  })
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', b.epost)
  await page.fill('input[name="passord"]', b.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

async function paaFlata(page: Page, sti: string) {
  const svar = await page.goto(sti)
  expect(svar?.status(), `${sti} svarte ${svar?.status()}`).toBeLessThan(400)
  await expect(page.locator('.tablet'), `${sti} er ikke nettbrettets flate`).toBeVisible()
}

// ---------------------------------------------------------------------
// 1. ROLLE: flata er nettbrettets, og bare nettbrettets
// ---------------------------------------------------------------------
test.describe('nettbrettet faar sin egen verden', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti} er nettbrettets flate`, async ({ page }) => {
      const feil: string[] = []
      page.on('pageerror', (e) => feil.push(e.message))
      await paaFlata(page, sti)

      // «IKKE KOPIER DESKTOP INN I TABLET» - maalt to ganger, fordi
      // regelen har to halvdeler, og forste utgave av denne testen tok
      // bare den ene.
      //
      // 1. SPRAAKET. `Nokkeltall` og `Signal` er lederflatens verktoy
      //    for «hva krever oppmerksomhet, og hvorfor». Nettbrettet spor
      //    om noe annet, og skal ikke ha dem.
      const lekkasje = await page.evaluate(() => [
        '.sq-nokkeltall', '.sq-signal', '.sq-puls', '.sq-sak',
      ].filter((k) => document.querySelector(k) !== null))
      expect(lekkasje, `${sti}: lederflatens analysespraak paa nettbrettet`).toEqual([])

      // 2. FLATA. Byggeklossene DELES - sidehodet, radene, tabellen -
      //    og det er meningen: ett system, to paletter. Men da maa
      //    palettbyttet faktisk virke. Foerste maaling fant lederens
      //    hvite kort midt i det moerke skallet paa fem ruter.
      const lyse = await page.evaluate(() => {
        const flate = (el: Element): string => {
          let n: Element | null = el
          while (n) {
            const b = getComputedStyle(n).backgroundColor
            const m = b.match(/rgba?\(([^)]+)\)/)
            if (m) {
              const d = m[1].split(',').map((x) => Number(x))
              if ((d[3] ?? 1) > 0.5) return `${d[0]},${d[1]},${d[2]}`
            }
            n = n.parentElement
          }
          return '0,0,0'
        }
        const ut: string[] = []
        for (const sel of ['.sq-sidehode', '.sq-rad-lenke', '.sq-tom', '.tabell', '.kort']) {
          for (const el of document.querySelectorAll(sel)) {
            const r = el.getBoundingClientRect()
            if (r.width === 0 || r.height === 0) continue
            const [rr, gg, bb] = flate(el).split(',').map(Number)
            // Enkel lyshet. Vi trenger ikke WCAG her - vi trenger aa
            // vite om flata er dag eller natt.
            if ((rr * 299 + gg * 587 + bb * 114) / 1000 > 128) {
              ut.push(`${sel} paa rgb(${flate(el)})`)
            }
          }
        }
        return [...new Set(ut)]
      })
      expect(lyse, `${sti}: lys flate i den moerke verdenen`).toEqual([])

      expect(feil, `Klientfeil paa ${sti}:\n  ${feil.join('\n  ')}`).toEqual([])
    })
  }

  test('lederens ruter er stengt', async ({ page }) => {
    for (const sti of ['/bemanning', '/salg', '/regnskap', '/ansatte']) {
      await page.goto(sti)
      await expect(page.locator('body'), sti).toContainText(/ikke tilgang|Kun eier|logg inn|eier/i)
    }
  })
})

// ---------------------------------------------------------------------
// 2. TREFFOMRAADE: hansker, ikke mus
// ---------------------------------------------------------------------
test.describe('treffomraadene taaler hansker', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti}`, async ({ page }) => {
      await paaFlata(page, sti)
      // 44 px er iOS-minimum for bar finger. Nettbrettet betjenes med
      // arbeidshansker av en som staar med noe i den andre haanda, og
      // skallet setter derfor 48 der det raar. Grensa her er 44: det er
      // det ABSOLUTTE minimumet, og en test som krevde 48 ville felt
      // ting som er gode nok.
      const smaa = await page.evaluate(() => {
        const ut: string[] = []
        for (const el of document.querySelectorAll('button, a[href], input, select, textarea, summary')) {
          const r = el.getBoundingClientRect()
          if (r.width === 0 && r.height === 0) continue
          if (getComputedStyle(el).display === 'inline') continue
          // EN AVKRYSSINGSBOKS TREFFES VIA ETIKETTEN SIN. Ruta er 24 px
          // fordi det er en rute; fingeren moter etiketten rundt, og
          // det er DEN som maa vaere stor nok. Aa maale boksen ville
          // vaert aa maale feil ting - og aa blaase den opp til 44
          // ville gitt en rute som ser ut som en knapp.
          const t = (el as HTMLInputElement).type
          if (t === 'checkbox' || t === 'radio') {
            const lab = el.closest('label')
            const lr = lab?.getBoundingClientRect()
            if (lr && lr.height >= 44 && lr.width >= 44) continue
            ut.push(`etiketten rundt ${t} "${(lab?.textContent ?? '').trim().slice(0, 28)}" `
              + `${Math.round(lr?.width ?? 0)}x${Math.round(lr?.height ?? 0)}`)
            continue
          }
          if (r.height < 44 || r.width < 44) {
            ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 28)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
          }
        }
        return ut
      })
      expect(smaa, `For smaa paa ${sti}:\n  ${smaa.join('\n  ')}\n`).toEqual([])
    })
  }
})

// ---------------------------------------------------------------------
// 3. KONTRAST OG AKSESSIBILITET
// ---------------------------------------------------------------------
test.describe('den moerke flata er lesbar', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  for (const sti of RUTENE) {
    test(`${sti} har ingen axe-brudd`, async ({ page }) => {
      await paaFlata(page, sti)
      // Kontrasten maales HER, ikke i jsdom: den krever layout. Den
      // deterministiske vakten i farger.test.ts maaler tokenparene;
      // denne maaler det som faktisk ble tegnet.
      const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
      const funn = res.violations.flatMap((v) => v.nodes.map(
        (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
      ))
      expect(funn, `\n${sti}\n${funn.join('\n')}\n`).toEqual([])
    })
  }

  test('ingen emoji baerer mening paa flata', async ({ page }) => {
    // Emoji har sine egne farger, oversettes ikke med resten av
    // grensesnittet, og leses ulikt av skjermlesere. Nettbrettet hadde
    // 24 av dem. Merkelappen brukeren selv velger paa /merker er
    // brukerinnhold og staar i et attributt, ikke i teksten.
    //
    // ETT UNNTAK, MED NAVN: de fem fjesene i pulsmaalingen. Der ER
    // emojien selve spoersmaalet - en femtrinns skala tegnet som
    // ansikter leses av folk som ikke leser norsk godt, og det er halve
    // grunnen til at vi spor paa nettbrettet i det hele tatt. De sto
    // med `aria-label="1"` … `"5"`, saa en skjermleser sa «knapp, 1»
    // fem ganger uten aa royke om 1 var best eller verst. Naa staar
    // ordet i etiketten, og det er DET som maales her.
    const PULSFJES = ['\u{1F623}', '\u{1F641}', '\u{1F610}', '\u{1F642}', '\u{1F604}']
    const funn: string[] = []
    for (const sti of RUTENE) {
      await paaFlata(page, sti)
      // `textContent`, ikke `innerText`. Det siste normaliserer teksten
      // paa vei ut av nettleseren og spiser variasjonsvelgeren U+FE0F -
      // og da faller tegn merket med den ut av moensteret mens
      // surrogatparene blir staaende. Foerste utgave av dette beviset
      // var halvblind av noyaktig det.
      const tekst = await page.evaluate(() => document.body.textContent ?? '')
      for (const e of tekst.match(EMOJI) ?? []) {
        if (PULSFJES.includes(e)) continue
        funn.push(`${sti}: ${e}`)
      }
      // Aapner pulsen seg, skal skalaen vaere lesbar med ord.
      const fjes = page.locator('.puls-face')
      for (let i = 0; i < await fjes.count(); i++) {
        const merke = await fjes.nth(i).getAttribute('aria-label')
        if (!merke || /^\d+$/.test(merke)) {
          funn.push(`${sti}: pulsfjes ${i + 1} har etiketten "${merke}" — et tall sier ikke om det er bra`)
        }
      }
    }
    expect(funn, `Emoji paa nettbrettet:\n  ${funn.join('\n  ')}`).toEqual([])
  })
})

// ---------------------------------------------------------------------
// 4. ARBEIDSFLYT: fra «hva skal jeg gjore» til gjort
// ---------------------------------------------------------------------
test.describe('IK-mat: koen, ikke regnearket', () => {
  test.describe.configure({ mode: 'serial' })

  test('koen sier hva som gjenstaar, gruppert slik hun jobber', async ({ page }) => {
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/ikmat')

    // Fem punkter, ingen maalt.
    await expect(page.locator('.tablet-hode h1')).toContainText('5 igjen')

    // EN RAD PER GRUPPE, ikke en rad per punkt. Det er skillet mellom en
    // koe og et regneark: hun gaar til kjolerommet en gang, ikke tre.
    const grupper = page.locator('.ikmat-rutine')
    await expect(grupper).toHaveCount(2)
    await expect(grupper.first()).toContainText('0/3')
    await expect(grupper.last()).toContainText('0/2')

    // Og det skal IKKE finnes en maaletabell her lenger.
    expect(await page.locator('table').count(), 'Regnearket er tilbake').toBe(0)
  })

  test('raden foerer til maalingen, og maalingen teller ned', async ({ page }) => {
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/ikmat')

    await page.locator('.ikmat-rutine', { hasText: 'Daglig' }).first()
      .getByRole('link').click()
    await expect(page).toHaveURL(/\/ikmat\/maaling/)

    // EN ENHET AV GANGEN (bolge 5). Fram til da sto alle tre under
    // hverandre med hvert sitt felt aapent, og hun maatte selv finne
    // igjen raden hun sto paa etter hver lagring - med et termometer i
    // den andre haanda.
    await expect(page.locator('.tmaal-navn')).toHaveCount(1)
    await expect(page.locator('.tmaal-navn')).toContainText('Kjoledisk pakkemat')
    await expect(page.locator('.tmaal-krav')).toContainText('4')
    await expect(page.locator('.tmaal-teller')).toContainText('1')

    // Lederens sideform skal ikke finnes paa flata der arbeidet skjer.
    await expect(page.locator('.sq-sidehode')).toHaveCount(0)
    await expect(page.locator('.maaling-rad')).toHaveCount(0)

    // Riktig tastatur. Med hansker og en desimal er dette ikke pynt.
    const felt = page.locator('.tmaal-felt input')
    await expect(felt).toHaveAttribute('inputmode', 'decimal')

    // Maal den. Kravet er under 4 grader; 3 er innenfor.
    await felt.fill('3')
    await page.locator('.tmaal-felt button').click()

    // NESTE ENHET TAR PLASSEN. Uten dette kravet ville en flate som
    // bare tommer feltet og blir staaende, sett riktig ut.
    await expect(page.locator('.tmaal-navn'))
      .toContainText('Fryser bakeri', { timeout: 15_000 })
    await expect(page.locator('.tmaal-teller')).toContainText('2')

    // Og den maalte staar igjen under, med tallet sitt.
    await expect(page.locator('.rutine-liste')).toContainText('Kjoledisk pakkemat')
    await expect(page.locator('.rutine-liste')).toContainText('3')

    // Tilbake i koen skal tallet ha falt. Uten dette beviser ingenting
    // av det over at maalingen faktisk ble lagret.
    await paaFlata(page, '/ikmat')
    await expect(page.locator('.tablet-hode h1')).toContainText('4 igjen')
    await expect(page.locator('.ikmat-rutine', { hasText: 'Daglig' }).first())
      .toContainText('1/3')
  })

  test('en verdi utenfor kravet ber om strakstiltak foer den lagres', async ({ page }) => {
    // AVVIK ER EN INSTRUKS, IKKE EN STRAFF. Og forklaringen kommer naar
    // den trengs: setningen om at et avvik opprettes automatisk sto
    // oeverst paa sida, foer noen hadde maalt noe.
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/ikmat/maaling')

    const navn = page.locator('.tmaal-navn')
    await expect(navn).toHaveCount(1)

    // Godt over ethvert kjolekrav.
    await page.locator('.tmaal-felt input').fill('40')

    const boks = page.locator('.tmaal-avvik')
    await expect(boks).toBeVisible()
    await expect(boks).toContainText(/avvik/i)
    await expect(boks.locator('textarea')).toBeVisible()
    // Og den er knyttet til VERDIEN, ikke til flata: tommes feltet, er
    // den borte. Uten dette kravet ville en boks som alltid sto der,
    // vaert gronn her.
    //
    // (Feltet tommes i stedet for aa fylles med et «innenfor»-tall.
    // Hvilken enhet som staar for tur avhenger av hva forrige test
    // maalte, og en fryser paa -18 og en varmedisk paa +60 har ikke ett
    // felles tall som er innenfor for begge.)
    await page.locator('.tmaal-felt input').fill('')
    await expect(boks).toHaveCount(0)
  })
})

// ---------------------------------------------------------------------
// 5. DEN TOMME BUTIKKEN
// ---------------------------------------------------------------------
test.describe('nettbrettet i en butikk uten oppsett', () => {
  test('sier at det ikke er satt opp, i stedet for aa staa tomt', async ({ page }) => {
    await loggInn(page, TOMT)
    await paaFlata(page, '/ikmat')
    await expect(page.locator('body')).toContainText(/Ingen kontrollpunkter/i)
  })

  test('hjem staar seg uten data', async ({ page }) => {
    await loggInn(page, TOMT)
    await paaFlata(page, '/oversikt')
    const overskrifter = await page.evaluate(() => [...document.querySelectorAll('h1, h2, h3')]
      .map((e) => (e.textContent ?? '').trim()).filter(Boolean))
    expect(overskrifter.length, 'Nettbrettets hjem er tomt').toBeGreaterThan(0)
  })
})


// ---------------------------------------------------------------------
// 5. INFORMASJONSARKITEKTUREN: tre faner, ett navigasjonslag
// ---------------------------------------------------------------------
//
// Bolge 5. Nettbrettet hadde FIRE faner og FEM fliser paa hjem - ni
// innganger til aatte ruter, med Rutiner og Anvisninger i begge lag.
//
// Fanene svarer paa hvert sitt aerend:
//
//   I dag    Hva skal jeg gjore naa?
//   Rutiner  Hva skal gjores - utfor rutinearbeid.
//   Hjelp    Jeg trenger hjelp eller informasjon.
//
test.describe('tre faner, ingen fliser', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  test('fanerada har noyaktig tre valg', async ({ page }) => {
    await paaFlata(page, '/oversikt')
    const faner = page.locator('.tablet-nav .tablet-fane')
    await expect(faner).toHaveCount(3)
    await expect(faner.nth(0)).toContainText(/I dag/i)
    await expect(faner.nth(1)).toContainText(/Rutiner/i)
    await expect(faner.nth(2)).toContainText(/Hjelp/i)
  })

  test('flisrutenettet er borte', async ({ page }) => {
    // MAALT PAA FRAVAER, og det er med vilje. Flisene var ikke stygge -
    // de var et ANDRE navigasjonslag, og kom de tilbake ville flata
    // fortsatt sett riktig ut i et skjermbilde.
    await paaFlata(page, '/oversikt')
    await expect(page.locator('.tablet-tiles')).toHaveCount(0)
    await expect(page.locator('.tablet-tile')).toHaveCount(0)
  })

  test('«Hjelp» staar som valgt naar man er nede i foten dens', async ({ page }) => {
    // Lenker, Nyheter og «Slik maaler vi» naas fra foten under Hjelp.
    // Uten dette ser det ut som man falt ut av navigasjonen: ingen fane
    // er valgt, og da vet man ikke hvor man er.
    for (const sti of ['/anvisninger', '/lenker', '/nyheter', '/mine-opplysninger']) {
      await paaFlata(page, sti)
      const aktiv = page.locator('.tablet-nav .tablet-fane.aktiv')
      await expect(aktiv, `${sti} markerer ingen fane som valgt`).toHaveCount(1)
      await expect(aktiv, `${sti} markerer feil fane`).toContainText(/Hjelp/i)
    }
  })

  test('hver destinasjon fra de gamle flisene har fortsatt en vei', async ({ page }) => {
    // DET SOM MAA BEVISES NAAR MAN FJERNER NAVIGASJON. Fem fliser gikk
    // til fem steder. Ingen av dem skal vaere blitt uNAAbare.
    const veier: [string, string, string][] = [
      ['/rutiner', '/oversikt', 'fane'],
      ['/anvisninger', '/oversikt', 'fane'],
      ['/ikmat', '/rutiner', 'fot'],
      ['/produksjonsplan', '/rutiner', 'fot'],
      ['/merker', '/vaar-stasjon', 'rad'],
    ]
    for (const [maal, fra, hvordan] of veier) {
      await paaFlata(page, fra)
      const lenke = page.locator(`a[href="${maal}"]`).first()
      await expect(lenke, `${maal} naas ikke fra ${fra} (${hvordan})`).toBeVisible()
    }
  })
})

// ---------------------------------------------------------------------
// 6. NIVAA 1: «I dag» spor om arbeid, ikke om okonomi
// ---------------------------------------------------------------------
test.describe('I dag handler om dagen', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page, MED_DATA)
  })

  test('okonomien staar ikke paa hjem, men finnes paa Vaar stasjon', async ({ page }) => {
    // TO HALVDELER, OG DEN ANDRE ER DEN VIKTIGE. Foerste utgave av dette
    // beviset sjekket bare at premiesaldoen var borte fra hjem - og det
    // ville vaert groent ogsaa om noen hadde SLETTET den. En test som
    // bare maaler fravaer, godkjenner et tap.
    await paaFlata(page, '/oversikt')
    await expect(page.locator('.premie-saldo')).toHaveCount(0)
    await expect(page.locator('.vekst-eng')).toHaveCount(0)
    await expect(page.locator('.maaling-tablet')).toHaveCount(0)

    await paaFlata(page, '/vaar-stasjon')
    await expect(page.locator('.premie-saldo')).toHaveCount(1)
  })

  test('Vaar stasjon naas med en rad fra I dag', async ({ page }) => {
    await paaFlata(page, '/oversikt')
    await page.locator('a[href="/vaar-stasjon"]').first().click()
    await expect(page).toHaveURL(/\/vaar-stasjon$/)
    await expect(page.locator('.tablet')).toBeVisible()
  })

  test('stemplingsraden sier hva et trykk forer til', async ({ page }) => {
    // Nettbrettet har TO ting som ligner «logg inn»: vakt-PIN-en i
    // toppstripa (hvem holder nettbrettet) og stemplingen (naar jobbet
    // jeg). Raden skal si hvilken av dem den er.
    await paaFlata(page, '/oversikt')
    const rad = page.locator('.stempling-rad')
    await expect(rad).toHaveCount(1)
    await expect(rad).toContainText(/Stemple/i)
    await rad.click()
    await expect(page).toHaveURL(/\/stempling$/)
  })
})

// ---------------------------------------------------------------------
// 7. NIVAA 3: ett sporsmaal, en enhet
// ---------------------------------------------------------------------
test.describe('sjekkpunkt: ett sporsmaal av gangen', () => {
  test.describe.configure({ mode: 'serial' })

  test('koens kritiske rad forer til en flate hun kan svare paa', async ({ page }) => {
    // BLINDGATA SOM BLE LUKKET. Koen la sjekkpunktene oeverst, kritisk
    // foerst, og lenket til /sjekkpunkt - som ga lederens adminpanel med
    // «Nytt sjekkpunkt» og sletteknapper. Svaret ble i praksis gitt i en
    // popup som dukket opp av seg selv etter 2,5 sekunder.
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/sjekkpunkt')

    // Lederens verktoy skal ikke finnes her.
    await expect(page.locator('.sq-sidepanel')).toHaveCount(0)
    await expect(page.getByRole('button', { name: /Nytt sjekkpunkt/i })).toHaveCount(0)

    // ETT sporsmaal, ikke to. Med to under hverandre hakes de av
    // nedover uten aa leses, og et «nei» paa et kritisk punkt skal
    // foelges opp samme dag.
    await expect(page.locator('.tsjekk')).toHaveCount(1)
    await expect(page.locator('.tsjekk-sporsmaal')).toHaveCount(1)

    // KRITISK FOERST. Seeden har to punkter der det kritiske har det
    // SENESTE klokkeslettet - uten det kunne rekkefolgen like gjerne
    // vaert tilfeldig, og beviset ville ikke merket forskjellen.
    await expect(page.locator('.tsjekk-sporsmaal')).toContainText('kjolerommet')
    await expect(page.locator('.tsjekk-kritisk')).toBeVisible()

    // To like store svar. Ingen av dem er «primaer»: et nei er like
    // riktig et svar som et ja.
    await expect(page.locator('.tsjekk-ja')).toBeVisible()
    await expect(page.locator('.tsjekk-nei')).toBeVisible()
  })

  test('et svar sender henne til neste sporsmaal', async ({ page }) => {
    await loggInn(page, MED_DATA)
    await paaFlata(page, '/sjekkpunkt')

    const foerst = (await page.locator('.tsjekk-sporsmaal').textContent())?.trim()
    await page.locator('.tsjekk-ja').click()

    // Neste tar plassen, og det besvarte staar igjen i lista under.
    await expect(page.locator('.tsjekk-sporsmaal'))
      .not.toContainText(foerst ?? '', { timeout: 15_000 })
    await expect(page.locator('.rutine-liste')).toContainText(foerst ?? '')
  })
})
