import { test, expect, type Page } from '@playwright/test'

// =====================================================================
// KORREKTHETSTRINN: vaktidentitet.
//
// Kontrakten som skal håndheves:
//
//   ansatt_nr      utpeker personen
//   PIN            beviser at det er riktig person
//   sentiqa_vakt   husker resultatet — og er ALDRI selv bevis
//
// DET SOM VAR GALT var to ting, og bare den første var åpenbar.
//
//   INNGANGSDØRA   `checkInn` slo opp på `pin_hash`. PIN-en VAR
//                  identiteten, så enhver gyldig PIN logget deg inn som
//                  den som eide den. Man trengte ikke utpeke noen: med
//                  femti ansatte traff et tilfeldig firesifret forsøk
//                  én av to hundre, og feltet sto i klartekst i
//                  toppstripa, i en butikk.
//
//   DØRA VED SIDEN `lesAktivAnsatt()` JSON-parset kapselen og stolte på
//                  `{id, navn}`. `httpOnly` hindrer JavaScript i å lese
//                  den — den hindrer ikke en forespørsel med et
//                  selvskrevet `Cookie:`-hode. Den som hadde
//                  nettbrettets sesjon kunne sette seg som hvilken som
//                  helst ansatt-ID, uten PIN i det hele tatt.
//
// Bevisene under måler begge dørene. De fire siste er de viktigste:
// de skriver en kapsel for hånd, slik en angriper ville gjort.
// =====================================================================

const NETTBRETT = {
  epost: 'nettbrett-analyse@test.sentiqa.no',
  passord: 'test-nettbrett-analyse-2026',
}

/** Seedet i supabase/seed.sql. Se kommentaren der for hvorfor hver rad finnes. */
const ADA = { id: '88888888-8888-4888-8888-000000000001', nr: '1001', pin: '1234', navn: 'Ada Testad' }
const BO = { id: '88888888-8888-4888-8888-000000000002', nr: '1002', pin: '5678', navn: 'Bo Testad' }
const KIM = { pin: '9999' } // aktiv, men uten ansattnummer
const DAG = { id: '88888888-8888-4888-8888-000000000004', nr: '1003', pin: '1111' } // deaktivert
const EIR = { id: '88888888-8888-4888-8888-000000000005' } // annen kjede

async function loggInn(page: Page) {
  await page.addInitScript(() => {
    try { localStorage.setItem('sjekk-vist', String(Date.now())) } catch { /* */ }
  })
  await page.goto('/logg-inn')
  await page.fill('input[name="epost"]', NETTBRETT.epost)
  await page.fill('input[name="passord"]', NETTBRETT.passord)
  await page.click('button[type="submit"]')
  await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })
}

async function startVakt(page: Page, nr: string, pin: string) {
  await page.goto('/oversikt')
  await page.fill('.vakt input[name="ansatt_nr"]', nr)
  await page.fill('.vakt input[name="pin"]', pin)
  await page.locator('.vakt button[type="submit"]').click()
}

/** Navnet i toppstripa når vakta er i gang. Tom streng når ingen står på vakt. */
async function vaktnavn(page: Page): Promise<string> {
  const n = page.locator('.vakt-navn')
  return (await n.count()) === 0 ? '' : ((await n.textContent()) ?? '').trim()
}

/**
 * Skriver vaktkapselen for hånd — slik en angriper med nettbrettets
 * sesjon ville gjort det.
 *
 * Dette er selve poenget med B-delen: `httpOnly` beskytter mot
 * JavaScript, ikke mot en HTTP-klient. Playwright setter kapselen på
 * konteksten, ikke gjennom sida, og treffer derfor nøyaktig samme hull.
 */
async function skrivKapsel(page: Page, innhold: unknown) {
  const url = new URL(page.url())
  await page.context().addCookies([{
    name: 'sentiqa_vakt',
    value: JSON.stringify(innhold),
    domain: url.hostname,
    path: '/',
    httpOnly: true,
    sameSite: 'Lax',
  }])
}

// ---------------------------------------------------------------------
// A. INNGANGSDØRA: nummer utpeker, PIN beviser
// ---------------------------------------------------------------------
test.describe('vaktinnlogging krever nummer OG pin', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  test('riktig nummer + riktig PIN gir vakt', async ({ page }) => {
    await startVakt(page, ADA.nr, ADA.pin)
    await expect(page.locator('.vakt-navn')).toHaveText(ADA.navn, { timeout: 15_000 })
  })

  test('riktig nummer + feil PIN avvises', async ({ page }) => {
    await startVakt(page, ADA.nr, BO.pin)
    await expect(page.locator('.vakt-feil')).toBeVisible()
    expect(await vaktnavn(page), 'noen kom inn med feil PIN').toBe('')
  })

  test('As nummer + Bs PIN avvises — og ingen av dem slipper inn', async ({ page }) => {
    // Den klassiske svindelen med stemplingsur. Oppslaget er paa
    // nummeret, saa raden ER Ada; hashen er Bos, saa den stemmer ikke.
    // Det avgjorende er at INGEN av de to blir logget paa: en
    // implementasjon som falt tilbake til aa lete etter PIN-en ville
    // logget inn Bo her, og sett riktig ut i en rask sjekk.
    await startVakt(page, ADA.nr, BO.pin)
    const navn = await vaktnavn(page)
    expect(navn, 'noen ble logget paa med feil kombinasjon').toBe('')
  })

  test('ukjent nummer med en annens gyldige PIN avvises', async ({ page }) => {
    await startVakt(page, '999999', ADA.pin)
    await expect(page.locator('.vakt-feil')).toBeVisible()
    expect(await vaktnavn(page)).toBe('')
  })

  test('meldingen skiller ikke ukjent nummer fra feil PIN', async ({ page }) => {
    // To ulike meldinger ville latt hvem som helst kartlegge hvilke
    // ansattnumre som finnes, ett forsok om gangen.
    await startVakt(page, ADA.nr, BO.pin)
    const feilPin = (await page.locator('.vakt-feil').textContent())?.trim()

    await page.reload()
    await startVakt(page, '999999', ADA.pin)
    const ukjentNr = (await page.locator('.vakt-feil').textContent())?.trim()

    expect(feilPin, 'meldingen mangler').toBeTruthy()
    expect(ukjentNr, 'ukjent nummer gir en annen melding enn feil PIN').toBe(feilPin)
  })

  test('PIN alene virker ikke lenger', async ({ page }) => {
    // Skjemaet har ikke lenger en vei inn med PIN alene, og
    // serverhandlingen avviser et tomt nummer. Begge maales: en knapp
    // som er borte er ikke det samme som en dor som er laast.
    await page.goto('/oversikt')
    await expect(page.locator('.vakt input[name="ansatt_nr"]')).toHaveCount(1)

    await page.fill('.vakt input[name="pin"]', ADA.pin)
    await page.locator('.vakt button[type="submit"]').click()
    await expect(page.locator('.vakt-feil')).toBeVisible()
    expect(await vaktnavn(page), 'PIN alene ga fortsatt vakt').toBe('')
  })

  test('PIN-feltet er maskert og fylles ikke ut av nettleseren', async ({ page }) => {
    await page.goto('/oversikt')
    const pin = page.locator('.vakt input[name="pin"]')
    await expect(pin).toHaveAttribute('type', 'password')
    await expect(pin).toHaveAttribute('autocomplete', 'off')
  })

  test('ansatt uten ansattnummer avvises, med en vei videre', async ({ page }) => {
    // Kim har PIN, men ikke nummer. Hun kan ikke starte vakt - og
    // beskjeden skal si hva hun skal gjore, uten aa rope at nettopp
    // hennes PIN var riktig.
    await startVakt(page, '', KIM.pin)
    const melding = (await page.locator('.vakt-feil').textContent())?.trim() ?? ''
    expect(await vaktnavn(page)).toBe('')
    expect(melding.toLowerCase(), 'beskjeden sier ikke hva hun skal gjore')
      .toContain('ansattnummer')
  })
})

// ---------------------------------------------------------------------
// B. DØRA VED SIDEN AV: kapselen er ikke bevis
// ---------------------------------------------------------------------
test.describe('vaktkapselen er ubetrodd', () => {
  test.beforeEach(async ({ page }) => {
    await loggInn(page)
  })

  test('legitim vakt overlever navigasjon og reload', async ({ page }) => {
    // Kontrollen maa ikke bli saa streng at den kaster ut den som
    // faktisk logget seg paa. Uten dette beviset kunne alle de andre
    // vaert gronne av at vakta aldri virket i det hele tatt.
    await startVakt(page, ADA.nr, ADA.pin)
    await expect(page.locator('.vakt-navn')).toHaveText(ADA.navn, { timeout: 15_000 })

    for (const sti of ['/rutiner', '/ikmat', '/vaar-stasjon', '/oversikt']) {
      await page.goto(sti)
      expect(await vaktnavn(page), `vakta forsvant paa ${sti}`).toBe(ADA.navn)
    }
    await page.reload()
    expect(await vaktnavn(page), 'vakta forsvant ved reload').toBe(ADA.navn)
  })

  test('skrevet kapsel med en annen gyldig ansatt-ID gir ikke den identiteten', async ({ page }) => {
    // HULLET SOM BLE LUKKET. Bo sin ID, uten at noen har tastet Bo sin
    // PIN. For korrekthetstrinnet ville navnet hans staatt i toppstripa
    // og ID-en hans havnet paa alt som ble utfort.
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: BO.id, navn: BO.navn })
    await page.goto('/oversikt')
    expect(await vaktnavn(page), 'en skrevet kapsel ga Bos identitet').not.toBe(BO.navn)
  })

  test('navnet i kapselen brukes ikke — det hentes fra basen', async ({ page }) => {
    // En kapsel med Adas EKTE id, men et paafunnet navn. Godtas ID-en,
    // skal navnet likevel komme fra raden. Et navn paa skjermen er
    // nettopp det som far folk til aa stole paa at riktig person staar
    // paalogget.
    await startVakt(page, ADA.nr, ADA.pin)
    await expect(page.locator('.vakt-navn')).toHaveText(ADA.navn, { timeout: 15_000 })

    await skrivKapsel(page, { id: ADA.id, navn: 'Direktøren' })
    await page.goto('/oversikt')
    const navn = await vaktnavn(page)
    expect(navn, 'kapselens navn ble vist').not.toContain('Direkt')
    expect(navn, 'den ekte raden ble ikke lest').toBe(ADA.navn)
  })

  test('skrevet kapsel med ansatt fra en annen kjede avvises', async ({ page }) => {
    // Eir finnes, er aktiv og er ikke slettet - men hun hoerer til
    // Testkjeden. Bade RLS og det eksplisitte kjedefilteret skal stoppe
    // dette, og de maa svikte samtidig for at det skal slippe gjennom.
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: EIR.id, navn: 'Eir Annenkjede' })
    await page.goto('/oversikt')
    expect(await vaktnavn(page), 'en ansatt fra en annen kjede ble vakt').toBe('')
  })

  test('kapsel med deaktivert ansatt gir ikke vakt', async ({ page }) => {
    // Dag er deaktivert og slettet. En kapsel fra for han sluttet skal
    // ikke fortsette aa virke i tolv timer.
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: DAG.id, navn: 'Dag Deaktivert' })
    await page.goto('/oversikt')
    expect(await vaktnavn(page), 'en deaktivert ansatt sto som paa vakt').toBe('')
  })

  test('soppel i kapselen velter ingenting', async ({ page }) => {
    // Ikke en angrepsvei, men en robusthetssjekk: `JSON.parse` paa
    // soppel kaster, og en kapsel man ikke forstaar skal bety «ingen
    // vakt» - ikke en femhundrefeil paa hele nettbrettet.
    await page.goto('/oversikt')
    for (const soppel of ['ikke json', '{}', '{"id":123}', '{"navn":"bare navn"}', '[]']) {
      await page.context().clearCookies({ name: 'sentiqa_vakt' })
      const url = new URL(page.url())
      await page.context().addCookies([{
        name: 'sentiqa_vakt', value: soppel, domain: url.hostname, path: '/',
      }])
      const svar = await page.goto('/oversikt')
      expect(svar?.status(), `kapsel «${soppel}» velter sida`).toBeLessThan(400)
      expect(await vaktnavn(page), `kapsel «${soppel}» ga vakt`).toBe('')
    }
  })
})

// ---------------------------------------------------------------------
// C. TILSKRIVING: at vakta virker skal ikke bety at den skrives ned
// ---------------------------------------------------------------------
test.describe('en skrevet kapsel tilskrives ikke arbeid', () => {
  test('sjekkpunktsvar under en skrevet kapsel far ikke Bos identitet', async ({ page }) => {
    // Den ENESTE maaten aa bevise dette utenfra: gjor noe under den
    // skrevne kapselen, og se at flata ikke oppforer seg som om Bo er
    // paalogget. Selve `ansatt_id`-kolonnen er ikke lesbar herfra -
    // sjekkpunkt_svar leses ikke ut med ansatt i noen visning - saa
    // beviset maaler det som ER synlig: at identiteten aldri ble antatt.
    await loggInn(page)
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: BO.id, navn: BO.navn })

    await page.goto('/sjekkpunkt')
    expect(await vaktnavn(page), 'Bo sto som paa vakt paa arbeidsflata').not.toBe(BO.navn)

    const ja = page.locator('.tsjekk-ja')
    if (await ja.count() > 0) {
      await ja.click()
      // Svaret skal ga gjennom - handlingen tillater vakt-loese svar,
      // slik den alltid har gjort - men uten Bos identitet i toppstripa.
      await expect(page.locator('.rutine-liste')).toBeVisible({ timeout: 15_000 })
      expect(await vaktnavn(page)).not.toBe(BO.navn)
    }
  })
})
