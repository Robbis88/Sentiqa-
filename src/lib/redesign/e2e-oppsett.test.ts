import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'

// =====================================================================
// E2E-OPPSETTET ER EN FORUTSETNING, IKKE EN SMAKSSAK
// =====================================================================
//
// `e2e/maanedsplan.spec.ts` har en MUTERENDE arbeidsflyt: den bygger
// månedsplanutkast, slipper én og avviser én — på ekte rader i den ene
// databasen alle spec-filene deler.
//
// Tre innstillinger må holde for at den flyten skal bety noe. De står i
// `playwright.config.ts` med begrunnelse, og her står de som en vakt:
// endrer noen dem, skal det bli rødt i vitest på millisekunder, ikke
// oppdages som en uforklarlig flaky e2e ti minutter ut i CI.
//
//   retries: 0       en retry ville startet midt i flyten, på en halvt
//                    mutert base, og latt som det var seedtilstanden
//   workers: 1       filene deler database; parallelle filer skriver i
//                    hverandres fikstur
//   fullyParallel    false — samme grunn, ett nivå ned
//
// `workers` var dessuten avhengig av MASKINEN før den ble satt:
// standarden er halvparten av kjernene, så en to-kjerners runner ga én
// arbeider og en fire-kjerners ga to. Da ville en test bestått eller
// feilet av hvor den kjørte.
// =====================================================================

const KONFIG = readFileSync(join('playwright.config.ts'), 'utf8')

describe('playwright-oppsettet', () => {
  test('retries er 0 — en retry ville startet på en mutert base', () => {
    expect(KONFIG).toMatch(/retries:\s*0\s*,/)
  })

  test('workers er 1 — spec-filene deler database', () => {
    expect(KONFIG).toMatch(/workers:\s*1\s*,/)
  })

  test('fullyParallel er av', () => {
    expect(KONFIG).toMatch(/fullyParallel:\s*false\s*,/)
  })

  test('KANARIFUGL: mønstrene ville sett en endring', () => {
    // Uten denne kunne alle tre stått og matchet på noe helt annet.
    expect(/retries:\s*0\s*,/.test('retries: 1,')).toBe(false)
    expect(/workers:\s*1\s*,/.test('workers: 4,')).toBe(false)
    expect(/fullyParallel:\s*false\s*,/.test('fullyParallel: true,')).toBe(false)
  })
})

describe('den muterende flyten er merket som serial', () => {
  const SPEC = readFileSync(join('e2e', 'maanedsplan.spec.ts'), 'utf8')

  test('månedsplanflyten står i en serial describe', () => {
    // `test.describe.serial` er forskjellen mellom «de kjører i
    // rekkefølge fordi de tilfeldigvis gjør det» og «de kjører i
    // rekkefølge fordi det står skrevet».
    expect(SPEC).toContain('test.describe.serial(')
  })

  test('og den dokumenterer hvilke rader den eier', () => {
    expect(SPEC).toContain('RADENE DENNE FLYTEN EIER')
  })
})
