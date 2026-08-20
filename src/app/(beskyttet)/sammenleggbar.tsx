'use client'
import { useState } from 'react'

// Sammenleggbar seksjon (kort) for dashbordet.
//
// `ikon` er borte. Den tok en emoji og satte den foran overskriften -
// 📅 foran «Forrige uke per stasjon», 📊 foran «Stasjonsrangering». Ordet
// sto der allerede; emojien la til farge og et annet formsprak enn
// resten av systemet, og ingen informasjon.
export function Sammenleggbar({
  tittel,
  children,
  apen: apenInit = true,
}: {
  tittel: string
  children: React.ReactNode
  apen?: boolean
}) {
  const [apen, setApen] = useState(apenInit)
  return (
    <section className="kort sammenleggbar">
      <button type="button" className="sammenleggbar-topp" onClick={() => setApen((v) => !v)} aria-expanded={apen}>
        <h2>{tittel}</h2>
        <span className="sammenleggbar-toggle">{apen ? 'Skjul' : 'Vis'} <span className={`sammenleggbar-pil ${apen ? 'apen' : ''}`}>▾</span></span>
      </button>
      {apen && <div className="sammenleggbar-innhold">{children}</div>}
    </section>
  )
}
