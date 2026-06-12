'use client'
import { useState, useEffect } from 'react'
import { svarSjekkpunktTablet } from './sjekkpunkt/handlinger'
import { useT } from './oversett-kontekst'

type Sjekk = { id: string; sporsmaal: string; kritisk: boolean; stasjon_id: string }

// Sporadisk popup (som puls) med dagens ubesvarte sjekkpunkter. Throttlet 30 min.
export function SjekkpunktPopp({ punkter }: { punkter: Sjekk[] }) {
  const t = useT()
  const [igjen, setIgjen] = useState<Sjekk[]>(punkter)
  const [vis, setVis] = useState(false)
  const [venter, setVenter] = useState<string | null>(null)

  useEffect(() => {
    if (punkter.length === 0) return
    try {
      const vist = Number(localStorage.getItem('sjekk-vist') || 0)
      if (Date.now() - vist < 1000 * 60 * 30) return // snooze 30 min
    } catch {
      /* */
    }
    const t = setTimeout(() => setVis(true), 2500)
    return () => clearTimeout(t)
  }, [punkter.length])

  if (!vis || igjen.length === 0) return null

  function svarPunkt(s: Sjekk, ja: boolean) {
    setVenter(s.id)
    svarSjekkpunktTablet(s.id, s.stasjon_id, ja)
      .catch(() => {})
      .finally(() => {
        setIgjen((l) => l.filter((x) => x.id !== s.id))
        setVenter(null)
      })
  }
  function snooze() {
    try {
      localStorage.setItem('sjekk-vist', String(Date.now()))
    } catch {
      /* */
    }
    setVis(false)
  }

  return (
    <div className="puls-popp">
      <div className="puls-popp-kort sjekk-popp">
        <p className="puls-popp-q">✅ {t('Sjekkpunkter')} ({igjen.length})</p>
        <ul className="sjekk-liste">
          {igjen.map((s) => (
            <li key={s.id} className={s.kritisk ? 'kritisk' : ''}>
              <span>{s.sporsmaal}{s.kritisk ? ' ❗' : ''}</span>
              <span className="sjekk-knapper">
                <button type="button" className="sjekk-ja" disabled={venter === s.id} onClick={() => svarPunkt(s, true)}>{t('Ja')}</button>
                <button type="button" className="sjekk-nei" disabled={venter === s.id} onClick={() => svarPunkt(s, false)}>{t('Nei')}</button>
              </span>
            </li>
          ))}
        </ul>
        <div className="puls-popp-knapper">
          <button type="button" className="liten" onClick={snooze}>{t('Ikke nå')}</button>
        </div>
      </div>
    </div>
  )
}
