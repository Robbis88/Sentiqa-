'use client'
import { useState } from 'react'

// Sammenleggbar seksjon (kort) for dashbordet.
export function Sammenleggbar({
  tittel,
  ikon,
  children,
  apen: apenInit = true,
}: {
  tittel: string
  ikon?: string
  children: React.ReactNode
  apen?: boolean
}) {
  const [apen, setApen] = useState(apenInit)
  return (
    <section className="kort sammenleggbar">
      <button type="button" className="sammenleggbar-topp" onClick={() => setApen((v) => !v)} aria-expanded={apen}>
        <h2>{ikon ? `${ikon} ` : ''}{tittel}</h2>
        <span className={`sammenleggbar-pil ${apen ? 'apen' : ''}`}>▾</span>
      </button>
      {apen && <div className="sammenleggbar-innhold">{children}</div>}
    </section>
  )
}
