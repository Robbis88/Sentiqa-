'use client'
import { useState, useRef, useEffect } from 'react'
import { spørAssistent } from './assistent/handlinger'
import type { Melding } from '@/lib/ai/assistent'

type Visning = Melding & { kilder?: string[] }

const FORSLAG = [
  'Hvor mye solgte vi sist?',
  'Hvordan ligger vi an mot budsjett?',
  'Hvilken stasjon har mest svinn?',
]

export function AiBoble() {
  const [apen, setApen] = useState(false)
  const [meldinger, setMeldinger] = useState<Visning[]>([])
  const [tekst, setTekst] = useState('')
  const [venter, setVenter] = useState(false)
  const bunn = useRef<HTMLDivElement>(null)
  const felt = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (apen) bunn.current?.scrollIntoView({ behavior: 'smooth' })
  }, [meldinger, venter, apen])

  useEffect(() => {
    if (apen) felt.current?.focus()
  }, [apen])

  async function send(melding: string) {
    const m = melding.trim()
    if (!m || venter) return
    const historikk = meldinger.map(({ rolle, tekst }) => ({ rolle, tekst }))
    setMeldinger((f) => [...f, { rolle: 'bruker', tekst: m }])
    setTekst('')
    setVenter(true)
    try {
      const svar = await spørAssistent(historikk, m)
      setMeldinger((f) => [...f, { rolle: 'assistent', tekst: svar.svar, kilder: svar.kilder }])
    } catch {
      setMeldinger((f) => [...f, { rolle: 'assistent', tekst: 'Noe gikk galt. Prøv igjen.' }])
    } finally {
      setVenter(false)
    }
  }

  return (
    <>
      {apen && (
        <div className="ai-panel" role="dialog" aria-label="Sentiqa AI-assistent">
          <header className="ai-topp">
            <span className="ai-avatar">✨</span>
            <span className="ai-tittel-blokk">
              <span className="ai-tittel">Sentiqa AI-assistent</span>
              <span className="ai-und">Spør om dine egne tall</span>
            </span>
            <button type="button" className="ai-lukk" aria-label="Lukk" onClick={() => setApen(false)}>✕</button>
          </header>

          <div className="ai-logg">
            {meldinger.length === 0 && (
              <div className="ai-tom">
                <p>Hei! Spør meg om salget, svinnet eller regnskapet ditt — jeg svarer med tall fra dine egne data.</p>
                <div className="forslag">
                  {FORSLAG.map((f) => (
                    <button key={f} type="button" onClick={() => send(f)} className="liten">{f}</button>
                  ))}
                </div>
              </div>
            )}
            {meldinger.map((m, i) => (
              <div key={i} className={`boble ${m.rolle}`}>
                <p>{m.tekst}</p>
                {m.kilder && m.kilder.length > 0 && <p className="kilder">Kilder: {m.kilder.join(', ')}</p>}
              </div>
            ))}
            {venter && <div className="boble assistent venter">Tenker …</div>}
            <div ref={bunn} />
          </div>

          <form className="ai-skriv" onSubmit={(e) => { e.preventDefault(); send(tekst) }}>
            <input ref={felt} value={tekst} onChange={(e) => setTekst(e.target.value)} placeholder="Skriv en melding …" disabled={venter} />
            <button type="submit" disabled={venter || !tekst.trim()} aria-label="Send">➤</button>
          </form>
        </div>
      )}

      <button
        type="button"
        className={`ai-fab ${apen ? 'apen' : ''}`}
        aria-label={apen ? 'Lukk AI-assistent' : 'Åpne AI-assistent'}
        aria-expanded={apen}
        onClick={() => setApen((v) => !v)}
      >
        {apen ? '✕' : '✨'}
      </button>
    </>
  )
}
