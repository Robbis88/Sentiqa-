'use client'
import { useState, useEffect, useActionState } from 'react'
import { svarRunde, type SvarResultat } from './puls/handlinger'

const FJES = [
  { v: 1, e: '😣' }, { v: 2, e: '🙁' }, { v: 3, e: '😐' }, { v: 4, e: '🙂' }, { v: 5, e: '😄' },
]

// Sporadisk puls-popup: dukker opp av og til (throttlet pr runde via
// localStorage), ikke ved hver lasting. Svar er anonymt.
export function PulsPopp({ runde }: { runde: { id: string; tekst: string } | null }) {
  const [vis, setVis] = useState(false)
  const [valgt, setValgt] = useState<number | null>(null)
  const [tilstand, handling, venter] = useActionState<SvarResultat | undefined, FormData>(svarRunde, undefined)

  useEffect(() => {
    if (!runde) return
    try {
      if (localStorage.getItem(`puls-svart-${runde.id}`)) return
      const vist = Number(localStorage.getItem(`puls-vist-${runde.id}`) || 0)
      if (Date.now() - vist < 1000 * 60 * 60 * 4) return // snooze 4 timer
    } catch {
      /* ingen storage */
    }
    const t = setTimeout(() => {
      if (Math.random() < 0.5) setVis(true) // sporadisk
    }, 2000)
    return () => clearTimeout(t)
  }, [runde])

  useEffect(() => {
    if (tilstand?.ok && runde) {
      try {
        localStorage.setItem(`puls-svart-${runde.id}`, '1')
      } catch {
        /* */
      }
      const t = setTimeout(() => setVis(false), 1800)
      return () => clearTimeout(t)
    }
  }, [tilstand, runde])

  if (!runde || !vis) return null

  function snooze() {
    try {
      localStorage.setItem(`puls-vist-${runde!.id}`, String(Date.now()))
    } catch {
      /* */
    }
    setVis(false)
  }

  return (
    <div className="puls-popp">
      <div className="puls-popp-kort">
        {tilstand?.ok ? (
          <p className="puls-popp-takk">Takk for svaret! 💙</p>
        ) : (
          <>
            <p className="puls-popp-q">{runde.tekst}</p>
            <form action={handling}>
              <input type="hidden" name="runde_id" value={runde.id} />
              <input type="hidden" name="skala" value={valgt ?? ''} />
              <div className="puls-faces">
                {FJES.map((f) => (
                  <button type="button" key={f.v} className={`puls-face ${valgt === f.v ? 'valgt' : ''}`} onClick={() => setValgt(f.v)} aria-label={`${f.v}`}>
                    <span className="puls-emoji">{f.e}</span>
                  </button>
                ))}
              </div>
              <textarea name="kommentar" rows={2} placeholder="Kommentar (valgfri, anonym)" />
              <div className="puls-popp-knapper">
                <button type="button" className="liten" onClick={snooze}>Ikke nå</button>
                <button type="submit" disabled={!valgt || venter}>{venter ? 'Sender …' : 'Send'}</button>
              </div>
              {tilstand?.feil ? <p className="feil">{tilstand.feil}</p> : null}
            </form>
          </>
        )}
      </div>
    </div>
  )
}
