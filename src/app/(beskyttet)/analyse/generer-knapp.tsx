'use client'
import { useState, useTransition } from 'react'
import { generer, genererHeleAaret } from './handlinger'

// aar = år for «hele året»-analysen. maaneder = alle opplastede regnskaps-
// måneder (også de uten analyse ennå), så du kan kjøre analyse for hvilken
// som helst måned — ikke bare siste.
export function AnalyseKnapp({ aar, maaneder = [] }: { aar?: string; maaneder?: { verdi: string; navn: string }[] }) {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)
  const [mnd, setMnd] = useState(maaneder[0]?.verdi ?? '')

  const kjor = (fn: () => Promise<{ ok: boolean; grunn?: string }>) =>
    start(async () => {
      setMelding(null)
      const res = await fn()
      setMelding(res.ok ? 'Analyse oppdatert.' : `Kunne ikke kjøre: ${res.grunn}`)
    })

  return (
    <div className="generer" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
      <div className="generer">
        {maaneder.length > 0 && (
          <select value={mnd} onChange={(e) => setMnd(e.target.value)} aria-label="Måned å analysere" className="periode-select">
            {maaneder.map((m) => <option key={m.verdi} value={m.verdi}>{m.navn}</option>)}
          </select>
        )}
        <button type="button" disabled={venter} onClick={() => kjor(() => generer(mnd || undefined))}>
          {venter ? <><span className="spinner" />Analyserer …</> : 'Kjør analyse (valgt måned)'}
        </button>
        <button type="button" disabled={venter} className="sekundaer" onClick={() => kjor(() => genererHeleAaret(aar))}>
          {venter ? <><span className="spinner" />Analyserer …</> : `Analyser hele året${aar ? ` (${aar})` : ''}`}
        </button>
      </div>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
