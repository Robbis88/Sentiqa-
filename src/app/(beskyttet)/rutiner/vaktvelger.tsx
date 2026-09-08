'use client'
import { useState, type ReactNode } from 'react'

// =====================================================================
// ÉN VAKT OM GANGEN
//
// Overlappen på ±60 minutter finnes for at den som avslutter dagvakta
// skal rekke å hake av. Men den gjør også at to vakter er aktive
// samtidig rundt skiftet — og flata stablet dem under hverandre og
// summerte dem til ett tall.
//
// Målt på Bønes 8. september kl. 15:20: morgen (04–15) med 19 rutiner
// og kveld (15–24) med 36. Femtifem oppgaver i én liste, uten at noe
// sa hvilken vakt de hørte til. Den som står der skal vite hva som
// gjenstår på SITT skift.
//
// ---------------------------------------------------------------------
// FORVALGET ER VAKTA MAN STÅR I
//
// `kjerne` fra `skjemaAktiv` sier hvilken av dem som er inne i sitt
// eget vindu, og ikke bare i nåden rundt. Den velges. Den andre er ett
// trykk unna, med antallet sitt synlig — så ingenting er gjemt, bare
// sortert.
//
// ---------------------------------------------------------------------
// ÉN VAKT GIR INGEN VELGER
//
// Er bare ett skjema aktivt — som det er på de fleste stasjoner mesteparten
// av døgnet — vises innholdet rett fram. En fanerad med én fane er
// støy som ser ut som et valg.
// =====================================================================

export type Vakt = {
  id: string
  /** «Kveldsvakt · Bakeri», ferdig oversatt av serveren. */
  etikett: string
  /** «15:00–00:00» */
  tid: string
  igjen: number
  totalt: number
  kjerne: boolean
  innhold: ReactNode
}

export function Vaktvelger({ vakter, igjenOrd }: { vakter: Vakt[]; igjenOrd: string }) {
  // Vakta man står i, ellers den første. Aldri «den med flest igjen» —
  // det ville flyttet valget under føttene på folk når de haker av.
  const forvalg = vakter.find((v) => v.kjerne)?.id ?? vakter[0]?.id
  const [valgt, setValgt] = useState(forvalg)

  if (vakter.length === 0) return null
  if (vakter.length === 1) return <>{vakter[0].innhold}</>

  const aktiv = vakter.find((v) => v.id === valgt) ?? vakter[0]

  return (
    <>
      <div className="vaktvelger" role="group" aria-label="Velg vakt">
        {vakter.map((v) => (
          <button
            key={v.id}
            type="button"
            className="vaktvelger-fane"
            aria-pressed={v.id === aktiv.id}
            onClick={() => setValgt(v.id)}
          >
            <span className="vaktvelger-navn">{v.etikett}</span>
            {/* TIDEN OG ANTALLET STÅR PÅ FANEN. Uten dem må man trykke
                for å finne ut om det er noe å gjøre der — og da er
                valget bare et ekstra steg. */}
            <span className="vaktvelger-under">
              {v.tid}
              {' · '}
              {v.igjen === 0 ? '✓' : `${v.igjen} ${igjenOrd}`}
            </span>
          </button>
        ))}
      </div>
      {aktiv.innhold}
    </>
  )
}
