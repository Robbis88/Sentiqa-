import { expect, type Page } from '@playwright/test'

// =====================================================================
// Er trykkflatene store nok — og er de i det hele tatt lagt ut?
//
// TO ULIKE PROBLEMER SOM SER LIKE UT I ETT TALL. Første utgave av
// opplæringstesten leste `getBoundingClientRect().height` og fikk 0 px
// på en knapp. Det er ikke et for lite treffområde; det er et element
// uten layout — og rapportert som «for lav» sender det feilsøkingen mot
// CSS-en for høyde, der det ikke er noe å finne.
//
// Derfor skilles de her, med hver sin beskjed, og den skjulte får
// nærmeste forfar som faktisk skjuler den navngitt.
//
// KRAVET ER 48 PX, ikke WCAG 2.2 sine 24. Prosjektet har allerede 44 som
// sin egen grense for skjemafelt (se globals.css, «Trykkflater og
// skriftstørrelse»); et nettbrett på en benk, betjent av noen som har
// hendene fulle, tåler litt mer.
// =====================================================================

export async function treffomraadeneHolder(
  page: Page, velger: string, minstHoyde = 48,
): Promise<void> {
  const funn = await page.evaluate(
    ({ velger, minstHoyde }: { velger: string; minstHoyde: number }) => {
      const lave: string[] = []
      const skjulte: string[] = []
      let maalt = 0
      for (const el of document.querySelectorAll(velger)) {
        const r = el.getBoundingClientRect()
        const navn = (el.textContent ?? '').trim().slice(0, 30)
        if (r.height === 0) {
          // Nærmeste forfar som faktisk skjuler den. Uten dette sier
          // meldingen bare at noe er borte, ikke hvor det ble borte.
          let p: Element | null = el
          let skyldig = '(ingen forfar skjuler den — nullhøyde av andre grunner)'
          while (p) {
            const ps = getComputedStyle(p)
            if (ps.display === 'none' || ps.visibility === 'hidden') {
              skyldig = `${p.tagName.toLowerCase()}.${p.className} → ${ps.display}/${ps.visibility}`
              break
            }
            p = p.parentElement
          }
          skjulte.push(`${navn}: ${Math.round(r.width)}x${Math.round(r.height)}, skjult av ${skyldig}`)
          continue
        }
        maalt++
        if (r.height < minstHoyde) lave.push(`${navn} ${Math.round(r.height)}px`)
      }
      return { lave, skjulte, maalt }
    },
    { velger, minstHoyde },
  )

  expect(funn.skjulte, `Knapper uten layout (${velger}):\n  ${funn.skjulte.join('\n  ')}\n`)
    .toEqual([])
  expect(funn.lave, `For lave (${velger}):\n  ${funn.lave.join('\n  ')}\n`)
    .toEqual([])

  // KANARIFUGL. Uten denne ville hjelperen bestått om velgeren ikke
  // traff noe — og «ingen for lave» ser nøyaktig ut som «alle er store
  // nok». Det er den samme feilen som en vakt som slutter å se.
  expect(funn.maalt, `Ingen elementer ble målt for ${velger}`).toBeGreaterThan(0)
}
