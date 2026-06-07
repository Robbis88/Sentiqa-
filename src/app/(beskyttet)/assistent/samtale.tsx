'use client'
import { useState, useRef, useEffect } from 'react'
import { spørAssistent } from './handlinger'
import type { Melding } from '@/lib/ai/assistent'

type Visning = Melding & { kilder?: string[] }

const FORSLAG = [
  'Hvor mye solgte vi sist?',
  'Hvordan ligger vi an mot budsjett?',
  'Hvilken stasjon har mest svinn?',
]

export function Samtale() {
  const [meldinger, setMeldinger] = useState<Visning[]>([])
  const [tekst, setTekst] = useState('')
  const [venter, setVenter] = useState(false)
  const bunn = useRef<HTMLDivElement>(null)

  useEffect(() => {
    bunn.current?.scrollIntoView({ behavior: 'smooth' })
  }, [meldinger, venter])

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
    <div className="chat">
      <div className="chat-logg">
        {meldinger.length === 0 && (
          <div className="chat-tom">
            <p>Spør om salget, svinnet eller regnskapet ditt.</p>
            <div className="forslag">
              {FORSLAG.map((f) => (
                <button key={f} type="button" onClick={() => send(f)} className="liten">
                  {f}
                </button>
              ))}
            </div>
          </div>
        )}
        {meldinger.map((m, i) => (
          <div key={i} className={`boble ${m.rolle}`}>
            <p>{m.tekst}</p>
            {m.kilder && m.kilder.length > 0 && (
              <p className="kilder">Kilder: {m.kilder.join(', ')}</p>
            )}
          </div>
        ))}
        {venter && <div className="boble assistent venter">Tenker …</div>}
        <div ref={bunn} />
      </div>

      <form
        className="chat-skriv"
        onSubmit={(e) => {
          e.preventDefault()
          send(tekst)
        }}
      >
        <input
          value={tekst}
          onChange={(e) => setTekst(e.target.value)}
          placeholder="Skriv en melding …"
          disabled={venter}
        />
        <button type="submit" disabled={venter || !tekst.trim()}>
          Send
        </button>
      </form>
    </div>
  )
}
