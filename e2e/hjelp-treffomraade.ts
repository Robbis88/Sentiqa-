import { expect, type Page } from '@playwright/test'

// =====================================================================
// Er trykkflatene store nok — og er de i det hele tatt lagt ut?
//
// TRE TILFELLER SOM SER LIKE UT I ETT TALL. Første utgave leste
// `getBoundingClientRect().height` og fikk 0 px på en knapp, og
// rapporterte det som «for lav». Det sendte feilsøkingen mot CSS-en for
// høyde, der det ikke var noe å finne.
//
// Da testen ble bedt om å si HVEM som skjulte den, svarte den:
// `div. → none/visible` — en klasseløs `<div>` med `display: none`.
// Det er Reacts streaming-plassholder: under strømming legges innholdet
// først i en skjult div og flyttes så på plass. Kopien blir liggende.
//
//   skjult av en forfar med display:none   ikke på siden — hoppes over
//   nullhøyde uten en slik forfar          ekte layoutfeil — feiler
//   lagt ut, men under kravet              for lite treffområde — feiler
//
// Å slå de to første sammen ville gjort testen enten blind (hopper over
// ekte feil) eller uskikket (feiler på en plassholder som ikke er der).
//
// KRAVET ER 48 PX, ikke WCAG 2.2 sine 24. Prosjektet har allerede 44 som
// sin egen grense for skjemafelt (se globals.css, «Trykkflater og
// skriftstørrelse»); et nettbrett på en benk, betjent av noen som har
// hendene fulle, tåler litt mer.
// =====================================================================

export async function treffomraadeneHolder(
  page: Page, velger: string, minstHoyde = 48,
): Promise<void> {
  // VENT TIL NOE ER SYNLIG FØR DU MÅLER. `page.evaluate` spør DOM-en i
  // det øyeblikket den kalles, og under strømming er plassholderkopien
  // ofte det eneste som finnes ennå. Da hoppes alt over, ingenting måles,
  // og kanarifuglen fyrer på et kappløp i stedet for på en ekte feil.
  //
  // Det var nøyaktig det som gjorde `main` rød etter #72: grønn på PR-en,
  // rød på neste kast. Ett grønt kast er ikke et bevis.
  //
  // `waitFor` gjør målingen deterministisk - Playwright prøver igjen til
  // en treffer faktisk er lagt ut. Kanarifuglen nederst blir stående, men
  // svarer nå på «traff velgeren noe i det hele tatt» i stedet for på
  // «kom vi for tidlig».
  await page.locator(velger).first().waitFor({ state: 'visible' })

  const funn = await page.evaluate(
    ({ velger, minstHoyde }: { velger: string; minstHoyde: number }) => {
      const lave: string[] = []
      const uforklart: string[] = []
      let maalt = 0
      let hoppet = 0
      for (const el of document.querySelectorAll(velger)) {
        const r = el.getBoundingClientRect()
        const navn = (el.textContent ?? '').trim().slice(0, 30)
        if (r.height === 0) {
          // Er den skjult av en forfar, er den ikke på siden — typisk
          // Reacts streaming-plassholder. Er den IKKE det, er nullhøyde
          // en ekte layoutfeil, og da skal den si fra.
          let p: Element | null = el
          let skjult = false
          while (p) {
            const ps = getComputedStyle(p)
            if (ps.display === 'none' || ps.visibility === 'hidden') { skjult = true; break }
            p = p.parentElement
          }
          if (skjult) { hoppet++; continue }
          uforklart.push(`${navn}: ${Math.round(r.width)}x${Math.round(r.height)}, ingen forfar skjuler den`)
          continue
        }
        maalt++
        if (r.height < minstHoyde) lave.push(`${navn} ${Math.round(r.height)}px`)
      }
      return { lave, uforklart, maalt, hoppet }
    },
    { velger, minstHoyde },
  )

  expect(funn.uforklart,
    `Nullhøyde uten at noe skjuler dem (${velger}):\n  ${funn.uforklart.join('\n  ')}\n`)
    .toEqual([])
  expect(funn.lave, `For lave (${velger}):\n  ${funn.lave.join('\n  ')}\n`)
    .toEqual([])

  // KANARIFUGL. Uten denne ville hjelperen bestått om velgeren ikke
  // traff noe — og «ingen for lave» ser nøyaktig ut som «alle er store
  // nok». Det er den samme feilen som en vakt som slutter å se.
  expect(funn.maalt,
    `Ingen elementer ble målt for ${velger}`
    + ` (${funn.hoppet} ble hoppet over fordi en forfar skjuler dem)`,
  ).toBeGreaterThan(0)
}
