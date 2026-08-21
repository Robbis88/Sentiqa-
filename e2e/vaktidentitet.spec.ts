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

/**
 * Fyller ut vaktskjemaet og VENTER TIL SERVEREN HAR SVART.
 *
 * Foerste utgave klikket og gikk rett til en `toHaveText` med femten
 * sekunders tak. Det holdt i den foerste describen og feilet i den
 * andre - samme kode, samme data, ulik plassering i fila. Aarsaken var
 * ikke koden: `/oversikt` er nettbrettets tyngste side, og naar de
 * andre arbeiderne er dypt inne i sine spec-er tar den lenger tid enn
 * taket. En «element(s) not found» sier ingenting om det.
 *
 * Naa ventes det paa at skjemaet har SETTLET - enten staar navnet der,
 * eller saa staar det en feilmelding - og en mislykket innlogging
 * rapporteres med meldingen sin i stedet for som et savnet element.
 */
async function startVakt(page: Page, nr: string, pin: string) {
  await page.goto('/oversikt')
  await page.fill('.vakt input[name="ansatt_nr"]', nr)
  await page.fill('.vakt input[name="pin"]', pin)
  await page.locator('.vakt button[type="submit"]').click()
  await expect(
    page.locator('.vakt-navn, .vakt-feil'),
    'vaktskjemaet svarte hverken med navn eller feilmelding',
  ).toHaveCount(1, { timeout: 45_000 })
}

/** Krever at vakta faktisk kom i gang, og sier hvorfor hvis den ikke gjorde det. */
async function krevVakt(page: Page, navn: string) {
  const feil = page.locator('.vakt-feil')
  if (await feil.count() > 0) {
    throw new Error(`vakta startet ikke: «${(await feil.textContent())?.trim()}»`)
  }
  await expect(page.locator('.vakt-navn')).toHaveText(navn, { timeout: 45_000 })
}

/** Navnet i toppstripa når vakta er i gang. Tom streng når ingen står på vakt. */
async function vaktnavn(page: Page): Promise<string> {
  const n = page.locator('.vakt-navn')
  return (await n.count()) === 0 ? '' : ((await n.textContent()) ?? '').trim()
}

/**
 * Leser vaktkapselen slik serveren skrev den.
 *
 * `cookies().set()` URL-koder verdien, saa raa `JSON.parse` faller paa
 * `%7B%22id%22...`. Den feilen sto som en syntaksfeil i beviset og saa
 * ut som om signaturen manglet.
 */
function lesKapsel(raa: string): { id?: string; sig?: string } {
  return JSON.parse(decodeURIComponent(raa)) as { id?: string; sig?: string }
}

/**
 * Fyller ut stemplingsskjemaet og venter til det har SETTLET.
 *
 * SELEKTORENE ER SKOPET TIL SKJEMAET. `/stempling` har ni
 * submit-knapper - spraakvelgeren alene har seks - og vaktskjemaet i
 * toppstripa har OGSAA et `ansatt_nr`-felt etter korrekthetstrinnet.
 * Et globalt `input[name="ansatt_nr"]` traff derfor to felter.
 *
 * OG DEN VENTER PAA BEGGE UTFALL. Foerste utgave ventet bare paa
 * kvitteringen, og brukte opp hele testens tidsbudsjett paa aa se etter
 * et element som aldri kom - uten aa si et ord om hva som sto der i
 * stedet. «element(s) not found» er ikke en diagnose.
 */
async function stemple(page: Page, nr: string, pin: string) {
    await stemple(page, nr, pin)
  await expect(
    page.locator('.stempling-kvittering, .stempling-feil'),
    'stemplingsskjemaet svarte hverken med kvittering eller feilmelding',
  ).toHaveCount(1, { timeout: 45_000 })
}

/** Krever kvittering, og sier hva som sto der hvis den mangler. */
async function krevKvittering(page: Page) {
  const feil = page.locator('.stempling-feil')
  if (await feil.count() > 0) {
    throw new Error(`stemplingen gikk ikke gjennom: «${(await feil.textContent())?.trim()}»`)
  }
  await expect(page.locator('.stempling-kvittering')).toBeVisible({ timeout: 45_000 })
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
    await krevVakt(page, ADA.navn)
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
    // Kim er aktiv og har PIN, men intet ansattnummer. Etter
    // korrekthetstrinnet er nummeret identiteten, saa det finnes ingen
    // vei inn for henne - og beskjeden maa si hva hun skal gjore.
    //
    // Maalt med et NUMMER som ikke finnes, ikke med et tomt felt: et
    // tomt felt beviser bare at skjemaet krever noe.
    await startVakt(page, '900001', KIM.pin)
    const melding = (await page.locator('.vakt-feil').textContent())?.trim() ?? ''
    expect(await vaktnavn(page), 'Kim kom inn uten nummer').toBe('')
    expect(melding.toLowerCase(), 'beskjeden sier ikke hva hun skal gjore')
      .toContain('ansattnummer')

    // Og et tomt felt gir ogsaa avvisning.
    await page.reload()
    await startVakt(page, '', KIM.pin)
    expect(await vaktnavn(page)).toBe('')
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
    await krevVakt(page, ADA.navn)

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
    // Adas EKTE signatur, hennes EKTE ID — og et påfunnet navn limt inn
    // ved siden av. Signaturen er gyldig, så kapselen slipper gjennom
    // lås 1; spørsmålet er hva systemet så viser.
    //
    // FØRSTE UTGAVE AV DETTE BEVISET VAR STILLE FEIL. Den skrev en helt
    // ny kapsel `{id, navn}` uten signatur, og fikk selvsagt ingen vakt.
    // Testen felte — men den felte på lås 1, ikke på det den skulle
    // måle. Et bevis som består av feil grunn er verdiløst; et som
    // FEILER av feil grunn skjuler at det aldri prøvde.
    //
    // Et navn på skjermen er nettopp det som får folk til å stole på at
    // riktig person er pålogget. Derfor bærer kapselen ikke noe navn i
    // det hele tatt, og et som limes inn skal ignoreres.
    await startVakt(page, ADA.nr, ADA.pin)
    await krevVakt(page, ADA.navn)

    const raa = (await page.context().cookies()).find((k) => k.name === 'sentiqa_vakt')?.value
    expect(raa, 'fant ingen vaktkapsel etter innlogging').toBeTruthy()
    const ekte = lesKapsel(raa!)

    await skrivKapsel(page, { id: ADA.id, sig: ekte.sig, navn: 'Direktøren' })
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

  test('kapsel med ekte ID men feil signatur avvises', async ({ page }) => {
    // Signaturen er det som skiller «denne identiteten finnes» fra
    // «denne identiteten ble bevist». Uten den kunne Bos ID limes inn
    // uten at noen hadde tastet Bos PIN — og Bo ER en gyldig, aktiv
    // ansatt i samme kjede, så et databaseoppslag sier ja.
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: BO.id, sig: 'a'.repeat(64) })
    await page.goto('/oversikt')
    expect(await vaktnavn(page), 'en gjettet signatur ble godtatt').toBe('')
  })

  test('ekte signatur limt paa en annen ID avvises', async ({ page }) => {
    // DEN SKARPESTE VARIANTEN. Vi logger inn som Ada, tar hennes EKTE
    // signatur ut av kapselen, og limer den paa Bos ID. Signaturen er
    // gyldig - den er bare ikke gyldig FOR DEN ID-EN.
    //
    // En implementasjon som signerte noe konstant, eller som bare sjekket
    // at signaturen «ser riktig ut», ville sluppet dette gjennom.
    await startVakt(page, ADA.nr, ADA.pin)
    await krevVakt(page, ADA.navn)

    const kapsler = await page.context().cookies()
    const raa = kapsler.find((k) => k.name === 'sentiqa_vakt')?.value
    expect(raa, 'fant ingen vaktkapsel etter innlogging').toBeTruthy()
    const adas = lesKapsel(raa!)
    expect(adas.id, 'kapselen baerer ikke Adas ID').toBe(ADA.id)
    expect(adas.sig, 'kapselen er usignert').toBeTruthy()

    await skrivKapsel(page, { id: BO.id, sig: adas.sig })
    await page.goto('/oversikt')
    expect(await vaktnavn(page), 'Adas signatur ga Bos identitet').not.toBe(BO.navn)
  })

  test('kapselen baerer ikke lenger et navn', async ({ page }) => {
    // Navnet var den delen kapselen aldri hadde noen rett til aa
    // bestemme. Det er ikke bare uleste data: sto det der, ville neste
    // utvikler som trengte et navn raskt, lest det derfra.
    await startVakt(page, ADA.nr, ADA.pin)
    await krevVakt(page, ADA.navn)
    const raa = (await page.context().cookies()).find((k) => k.name === 'sentiqa_vakt')?.value
    expect(raa ?? '', 'navnet ligger fortsatt i kapselen').not.toContain('Ada')
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
// C. TILSKRIVING: identiteten som fester seg til arbeidet
// ---------------------------------------------------------------------
test.describe('en skrevet kapsel tilskrives ikke arbeid', () => {
  test('Bo staar ikke som paa vakt paa noen arbeidsflate', async ({ page }) => {
    // HVA SOM FAKTISK AVGJOR TILSKRIVING: `ansatt_id` paa
    // rutine_utforinger, ik_avlesninger, sjekkpunkt_svar, avvik, puls og
    // tilbakemeldinger settes fra `lesAktivAnsatt()` - den samme
    // funksjonen som fyller navnet i toppstripa. Er vakta tom der, er
    // `ansatt_id` null overalt. Det er derfor toppstripa ER beviset.
    //
    // FORSTE UTGAVE KLIKKET «ja» PAA ET SJEKKPUNKT, og det var feil paa
    // to maater. Den beviste ingenting ekstra - `ansatt_id` er ikke
    // lesbar fra noen visning, saa klikket kunne ikke observeres - og
    // den ENDRET DELT TILSTAND: sjekkpunktene ligger i den samme
    // seedede basen som e2e/tablet.spec.ts maaler «kritisk foerst» mot,
    // og de to filene kjorer parallelt. Beviset felte en annen fils
    // bevis.
    //
    // Naa leses tre arbeidsflater uten aa roere noe.
    await loggInn(page)
    await page.goto('/oversikt')
    await skrivKapsel(page, { id: BO.id, navn: BO.navn })

    for (const sti of ['/sjekkpunkt', '/rutiner', '/ikmat/maaling']) {
      const svar = await page.goto(sti)
      expect(svar?.status(), `${sti} svarte ${svar?.status()}`).toBeLessThan(400)
      expect(await vaktnavn(page), `Bo sto som paa vakt paa ${sti}`).not.toBe(BO.navn)
      expect(await vaktnavn(page), `${sti} ga en vakt uten signatur`).toBe('')
    }
  })
})


// ---------------------------------------------------------------------
// D. PRODUKTET: begge veiene gjennom den nye funksjonen
// ---------------------------------------------------------------------
//
// Rettighetene, rate limitingen, tenantgjerdet og revisjonssporet er
// bevist i SQL (supabase/tests/pin_hash_lukket.sql) - der de faktisk
// bor, og der de tre approllene er den samme Postgres-rollen.
//
// Her maales det SQL ikke kan se: at menneskene fortsatt kommer inn.
test.describe('verifiseringen virker for begge innlogginger', () => {
  test('stempling gaar gjennom med nummer og PIN', async ({ page }) => {
    // SELEKTORENE ER SKOPET TIL SKJEMAET. `/stempling` har ni
    // submit-knapper - spraakvelgeren alene har seks - og vaktskjemaet
    // i toppstripa har OGSAA et `ansatt_nr`-felt etter
    // korrekthetstrinnet. Et globalt `input[name="ansatt_nr"]` traff
    // derfor to felter, og Playwright nektet aa gjette.
    // `stemple()` gikk fra et direkte oppslag paa `pin_hash` til RPC-en.
    // Ingen e2e rorte skjemaet foer dette, saa den veien var uten bevis
    // gjennom hele omleggingen.
    await loggInn(page)
    await stemple(page, ADA.nr, ADA.pin)

    // Kvitteringen sier NAVN og KLOKKESLETT. «Lagret» er ikke nok: hun
    // skal se at det ble riktig person uten aa lete.
    await krevKvittering(page)
    const kvittering = page.locator('.stempling-kvittering')
    await expect(kvittering).toContainText(ADA.navn)
    await expect(kvittering).toContainText(/INN|UT/)
  })

  test('feil PIN paa stempling avvises uten aa royke noe', async ({ page }) => {
    await loggInn(page)
    await page.goto('/stempling')
    await page.fill('.stempling-skjema input[name="ansatt_nr"]', ADA.nr)
    await page.fill('.stempling-skjema input[name="pin"]', BO.pin)
    await page.locator('.stempling-skjema button[type="submit"]').click()

    const feil = page.locator('.stempling-feil')
    await expect(feil).toBeVisible({ timeout: 30_000 })
    await expect(feil).toContainText(/Fant ingen/i)
    await expect(page.locator('.stempling-kvittering')).toHaveCount(0)
  })
})

// ---------------------------------------------------------------------
// E. PAUSEN, SETT FRA BUTIKKGULVET
// ---------------------------------------------------------------------
//
// EGEN KJEDE MED VILJE. Forsoekene telles per (retailer, ansattnummer) og
// per (retailer, enhet). Brant dette beviset fem feil paa et nummer i
// Analysekjeden, ville de andre bevisene i fila arvet en teller som
// staar og tikker - og en test som gjor andre tester roede er verre enn
// ingen test. Testkjeden har sin egen Eir, og sine egne tellere.
test.describe('for mange forsoek gir en pause, ikke en laast doer', () => {
  const TOMT = { epost: 'nettbrett@test.sentiqa.no', passord: 'test-nettbrett-2026' }
  const EIR_NR = '2001'

  test('sjette forsoek moeter en beskjed om aa vente', async ({ page }) => {
    await page.addInitScript(() => {
      try { localStorage.setItem('sjekk-vist', String(Date.now())) } catch { /* */ }
    })
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', TOMT.epost)
    await page.fill('input[name="passord"]', TOMT.passord)
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })

    // Fem feil paa samme nummer. Grensa er fem per ansattnummer per
    // kvarter; det sjette skal moete pausen.
    for (let i = 0; i < 5; i++) {
      await startVakt(page, EIR_NR, '0000')
      await expect(page.locator('.vakt-feil')).toBeVisible({ timeout: 30_000 })
    }

    await startVakt(page, EIR_NR, '0000')
    const melding = (await page.locator('.vakt-feil').textContent())?.trim() ?? ''

    // BESKJEDEN MAA SI AT DET ER EN PAUSE. Sto det «feil PIN» mens
    // systemet ikke engang saa paa PIN-en, ville hun staatt og tastet
    // riktig kode om og om igjen uten aa forstaa hvorfor.
    expect(melding.toLowerCase(), `sjette forsoek sa: «${melding}»`)
      .toMatch(/for mange|vent|prøv igjen om/)

    // Og pausen gjelder ogsaa med RIKTIG PIN - ellers ville den bare
    // bremset de mislykkede forsoekene, altsaa ingenting.
    await startVakt(page, EIR_NR, '4321')
    expect(await vaktnavn(page), 'pausen kunne omgaas med riktig PIN').toBe('')
  })
})