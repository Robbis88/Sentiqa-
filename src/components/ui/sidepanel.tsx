'use client'
import { useEffect, useRef, useState } from 'react'

// =====================================================================
// Sidepanel for sekundære handlinger.
//
// Problemet det løser: i dag ligger «Ny ansatt» øverst på /ansatte,
// «Ny oppgave» øverst på /oppgaver, «Ny bruker» øverst på /brukere. Den
// sjeldneste handlingen på siden står først, hver gang — fordi det ikke
// fantes noe annet sted å gjøre av den.
//
// Med et sidepanel beholder brukeren lista si mens hun oppretter én ting.
// Konteksten ryker ikke for et navn og en PIN.
//
// Bygget på <dialog>, ikke en div med posisjonering. Nettleseren gir da
// fokusfelle, Esc, inert bakgrunn og riktig rolle for skjermlesere —
// fire ting som er lette å tro man har gjort, og vanskelige å gjøre
// riktig for hånd.
// =====================================================================

export function Sidepanel({
  knapp,
  tittel,
  beskrivelse,
  knappeklasse = 'sq-knapp primar',
  children,
}: {
  /** Teksten på knappen som åpner. Skriv handlingen: «Ny ansatt». */
  knapp: string
  tittel: string
  beskrivelse?: string
  knappeklasse?: string
  children: React.ReactNode
}) {
  const ref = useRef<HTMLDialogElement>(null)
  const [aapen, settAapen] = useState(false)

  useEffect(() => {
    const d = ref.current
    if (!d) return
    if (aapen && !d.open) d.showModal()
    if (!aapen && d.open) d.close()
  }, [aapen])

  return (
    <>
      <button type="button" className={knappeklasse} onClick={() => settAapen(true)}>
        {knapp}
      </button>

      <dialog
        ref={ref}
        className="sq-sidepanel"
        // Esc lukker av seg selv i <dialog>; onClose fanger det opp så
        // React-tilstanden ikke blir stående og påstå at panelet er åpent.
        onClose={() => settAapen(false)}
        // Klikk på mørket utenfor. Treffer man selve dialogen, er target
        // dialogen — det er bakgrunnen, ikke innholdet.
        onClick={(e) => { if (e.target === ref.current) settAapen(false) }}
      >
        <div className="sq-sidepanel-innhold">
          <header className="sq-sidepanel-topp">
            <div>
              <h2>{tittel}</h2>
              {beskrivelse && <p className="undertittel">{beskrivelse}</p>}
            </div>
            <button
              type="button"
              className="sq-sidepanel-lukk"
              onClick={() => settAapen(false)}
              aria-label="Lukk"
            >
              ×
            </button>
          </header>
          {children}
        </div>
      </dialog>
    </>
  )
}
