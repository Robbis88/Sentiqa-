import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

// =====================================================================
// Tilgjengelighet MED layout.
//
// tilgjengelighet.test.ts kjorer axe i jsdom og maa slaa av
// contrast-regelen: uten rendering finnes det ingen farger aa regne paa.
// Her finnes de. Dette er den eneste vakten i repoet som faktisk kan si
// noe om kontrast og storrelser.
//
// Sidene under er de som naas UTEN oekt. Alt bak innlogging krever et
// seedet testprosjekt - se e2e/README.
// =====================================================================

const apneSider = [
  { sti: '/', navn: 'forsiden' },
  { sti: '/logg-inn', navn: 'innlogging' },
  { sti: '/personvern', navn: 'personvern' },
  { sti: '/databehandleravtale', navn: 'databehandleravtale' },
]

for (const { sti, navn } of apneSider) {
  test(`${navn} har ingen axe-brudd, kontrast inkludert`, async ({ page }) => {
    await page.goto(sti)
    const res = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze()

    const funn = res.violations.map(
      (v) => `${v.id}: ${v.help}\n    ${v.nodes.map((n) => n.target.join(' ')).join('\n    ')}`,
    )
    expect(funn, `\n${funn.join('\n')}\n`).toEqual([])
  })
}

test('innlogging kan betjenes med tastatur alene', async ({ page }) => {
  // Den som ikke kan bruke mus skal komme forbi forste side. Tabber vi
  // gjennom og aldri treffer et felt, er resten av systemet uten
  // betydning for henne.
  await page.goto('/logg-inn')
  const naadd: string[] = []
  for (let i = 0; i < 12; i++) {
    await page.keyboard.press('Tab')
    naadd.push(await page.evaluate(() => {
      const a = document.activeElement
      return a ? `${a.tagName.toLowerCase()}${(a as HTMLInputElement).type ? `[${(a as HTMLInputElement).type}]` : ''}` : ''
    }))
  }
  expect(naadd.some((t) => t.startsWith('input')), `Tabbet: ${naadd.join(', ')}`).toBe(true)
  expect(naadd.some((t) => t.startsWith('button')), `Tabbet: ${naadd.join(', ')}`).toBe(true)
})

test('klikkbare flater er store nok for en finger', async ({ page }) => {
  // 44x44 er iOS-minimum for bar finger. Nettbrettets egne skjermer er
  // satt til 56 (globals.css, .tablet .kryss) fordi arbeidshansker
  // bommer - men de skjermene krever oekt og kan ikke naas herfra.
  await page.goto('/logg-inn')
  const smaa = await page.evaluate(() => {
    const ut: string[] = []
    for (const el of document.querySelectorAll('button, a, input[type=submit]')) {
      const r = el.getBoundingClientRect()
      if (r.width === 0 && r.height === 0) continue // skjult

      // WCAG unntar mål som ligger INNE i en tekstlinje - en lenke midt
      // i en setning kan ikke gjøres 44px høy uten å ødelegge avsnittet.
      // Uten dette unntaket melder testen hver eneste brødtekstlenke, og
      // en vakt med kjente falske funn blir lest som støy.
      if (getComputedStyle(el).display === 'inline') continue

      if (r.height < 44 || r.width < 44) {
        ut.push(`${el.tagName.toLowerCase()} "${(el.textContent ?? '').trim().slice(0, 30)}" ${Math.round(r.width)}x${Math.round(r.height)}`)
      }
    }
    return ut
  })
  expect(smaa, `For smaa treffomraader:\n  ${smaa.join('\n  ')}\n`).toEqual([])
})
