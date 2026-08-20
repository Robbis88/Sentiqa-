'use client'
import { useState, useTransition } from 'react'
import { kravTekst } from '@/lib/ikmat/standard'
import { loggMaaling } from '../handlinger'

export type Punkt = { id: string; navn: string; min_temp: number | null; max_temp: number | null }
export type Logget = { temp: number; innenfor: boolean }

function utenfor(temp: number, min: number | null, max: number | null) {
  return (min != null && temp < min) || (max != null && temp > max)
}

function PunktRad({ p, startLogget }: { p: Punkt; startLogget: Logget | null }) {
  const [temp, setTemp] = useState('')
  const [tiltak, setTiltak] = useState('')
  const [feil, setFeil] = useState<string | null>(null)
  const [logget, setLogget] = useState<Logget | null>(startLogget)
  const [venter, start] = useTransition()

  const num = Number(temp.replace(',', '.'))
  const harTall = temp.trim() !== '' && Number.isFinite(num)
  const avvik = harTall && utenfor(num, p.min_temp, p.max_temp)

  function lagre() {
    setFeil(null)
    start(async () => {
      const r = await loggMaaling(p.id, temp, tiltak)
      if (r.feil) { setFeil(r.feil); return }
      setLogget({ temp: num, innenfor: !!r.innenfor })
    })
  }

  if (logget) {
    return (
      <li className={`maaling-rad ${logget.innenfor ? 'ok-rad' : 'avvik-rad'}`}>
        <span className="maaling-navn">{p.navn}</span>
        <span className="krav">{kravTekst(p.min_temp, p.max_temp)}</span>
        <span className={`status-pip ${logget.innenfor ? 'gronn' : 'rod'}`}>{logget.temp}°C{logget.innenfor ? ' ✓' : ' avvik'}</span>
      </li>
    )
  }

  return (
    <li className={`maaling-rad ${avvik ? 'avvik-rad' : ''}`}>
      <span className="maaling-navn">{p.navn}</span>
      <span className="krav">{kravTekst(p.min_temp, p.max_temp)}</span>
      <div className="maaling-input">
        <div className="maaling-input-rad">
          <input inputMode="decimal" value={temp} onChange={(e) => setTemp(e.target.value)} placeholder="°C" aria-label={`Temperatur ${p.navn}`} />
          <button type="button" className="liten" onClick={lagre} disabled={venter || !harTall}>{venter ? '…' : 'Lagre'}</button>
        </div>
        {avvik && (
          <textarea
            value={tiltak}
            onChange={(e) => setTiltak(e.target.value)}
            rows={2}
            className="maaling-tiltak"
            placeholder="Avvik! Hva gjorde du med en gang? (strakstiltak — kreves)"
          />
        )}
        {feil && <span className="feil" role="alert">{feil}</span>}
      </div>
    </li>
  )
}

export function MaalingListe({ punkter, logget }: { punkter: Punkt[]; logget: Record<string, Logget> }) {
  if (punkter.length === 0) return <p className="undertittel">Ingen enheter i denne gruppen.</p>
  return (
    <ul className="maaling-liste">
      {punkter.map((p) => <PunktRad key={p.id} p={p} startLogget={logget[p.id] ?? null} />)}
    </ul>
  )
}
