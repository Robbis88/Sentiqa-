import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { OKTFIL } from './eier'

// =====================================================================
// /businessplan — «ligger vi i rute mot planen?»
//
// HVA DENNE FILA KAN OG IKKE KAN BEVISE, SKREVET NED SÅ INGEN TROR DEN
// DEKKER MER ENN DEN GJØR:
//
// CI-basen har INGEN `regnskapslinjer` i det hele tatt — seeden har
// salgsdata, men aldri regnskap eller BP. Sida viser derfor alltid
// tomtilstanden her. Det som KAN måles er rolle, tomtilstand,
// tilgjengelighet og at ruta i det hele tatt svarer.
//
// Selve dommen — hva som står øverst, hvilket ord det får og hvilken
// terskel som gjelder — er bevist deterministisk i
// `src/lib/regnskap/bp-dom.test.ts`, og regnestykket bak i
// `supabase/tests/bp_status.sql`. Begge kjører på millisekunder og
// felles av en feil.
//
// Det er en bevisst arbeidsdeling, ikke en mangel som er glemt: å seede
// et helt regnskap for å teste en overskrift ville flyttet risikoen fra
// «er tallet riktig» til «ligner testdataene på virkeligheten».
// =====================================================================

test.describe('/businessplan som eier', () => {
  // Eieren har to-faktor. `eier.setup.ts` logger inn ÉN gang og legger
  // økta i en fil som alle spec-ene deler. En egen innlogging her ville
  // vært en femte kopi av den samme dansen.
  test.use({ storageState: OKTFIL })

  test('eieren kommer inn, og sida sier hvorfor den er tom', async ({ page }) => {
    const svar = await page.goto('/businessplan')
    expect(svar?.status(), `/businessplan svarte ${svar?.status()}`).toBeLessThan(400)

    // TOMTILSTANDEN SKAL FORKLARE, IKKE BARE VÆRE TOM. Uten BP finnes
    // det ingenting å måle mot, og det er en opplysning — ikke en feil
    // brukeren skal gjette seg til.
    await expect(page.locator('body')).toContainText(/businessplan/i)
    await expect(page.locator('.sq-tom, .bp-liste')).toHaveCount(1)
  })

  test('ingen axe-brudd', async ({ page }) => {
    await page.goto('/businessplan')
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const funn = res.violations.flatMap((v) => v.nodes.map(
      (n) => `${v.id}: ${n.target.join(' ')}\n      ${(n.failureSummary ?? '').replace(/\n/g, '\n      ')}`,
    ))
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
})

test.describe('/businessplan for andre roller', () => {
  test('nettbrettet slipper ikke inn', async ({ page }) => {
    // Businessplanen er lederens spørsmål. Nettbrettet spør «hva skal
    // jeg gjøre nå», og et budsjettavvik er ikke et svar på det.
    await page.goto('/logg-inn')
    await page.fill('input[name="epost"]', 'nettbrett-analyse@test.sentiqa.no')
    await page.fill('input[name="passord"]', 'test-nettbrett-analyse-2026')
    await page.click('button[type="submit"]')
    await expect(page).not.toHaveURL(/\/logg-inn$/, { timeout: 15_000 })

    await page.goto('/businessplan')
    await expect(page.locator('body')).toContainText(/ikke tilgang|Kun eier|butikksjef/i)
  })
})
