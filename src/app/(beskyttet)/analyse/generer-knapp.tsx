'use client'
import { useState, useTransition } from 'react'
import { generer, genererHeleAaret } from './handlinger'

export function AnalyseKnapp({ aar }: { aar?: string }) {
  const [venter, start] = useTransition()
  const [melding, setMelding] = useState<string | null>(null)

  const kjor = (fn: () => Promise<{ ok: boolean; grunn?: string }>) =>
    start(async () => {
      setMelding(null)
      const res = await fn()
      setMelding(res.ok ? 'Analyse oppdatert.' : `Kunne ikke kjøre: ${res.grunn}`)
    })

  return (
    <div className="generer">
      <button type="button" disabled={venter} onClick={() => kjor(generer)}>
        {venter ? <><span className="spinner" />Analyserer …</> : 'Kjør analyse (siste måned)'}
      </button>
      <button type="button" disabled={venter} className="sekundaer" onClick={() => kjor(() => genererHeleAaret(aar))}>
        {venter ? <><span className="spinner" />Analyserer …</> : `Analyser hele året${aar ? ` (${aar})` : ''}`}
      </button>
      {melding && <span className="generer-melding">{melding}</span>}
    </div>
  )
}
