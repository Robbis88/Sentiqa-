'use client'
import { useRef, useState, useTransition } from 'react'
import { TYPE_ETIKETT, FREKVENS_ETIKETT } from '@/lib/ikmat/standard'
import { oppdaterPunkt, slettKontrollpunkt, lagrePunktRekkefolge } from '../handlinger'
import { SlettKnapp } from '@/components/ui/slett-knapp'

export type Punkt = { id: string; navn: string; type: string; frekvens: string; min_temp: number | null; max_temp: number | null }

const TYPER = ['kjol', 'frys', 'oppvarming', 'varmholding', 'skyllevann', 'annet']
const FREKVENSER = ['daglig', 'to_ukentlig', 'ukentlig']

export function IkPunktListe({ stasjonId, punkter }: { stasjonId: string; punkter: Punkt[] }) {
  const [order, setOrder] = useState(punkter)
  const [over, setOver] = useState<string | null>(null)
  const dragId = useRef<string | null>(null)
  const [, start] = useTransition()

  function dropPaa(targetId: string) {
    const from = dragId.current
    setOver(null)
    dragId.current = null
    if (!from || from === targetId) return
    const next = [...order]
    const fi = next.findIndex((p) => p.id === from)
    const ti = next.findIndex((p) => p.id === targetId)
    if (fi < 0 || ti < 0) return
    const [m] = next.splice(fi, 1)
    next.splice(ti, 0, m)
    setOrder(next)
    start(async () => { await lagrePunktRekkefolge(stasjonId, next.map((p) => p.id)) })
  }

  if (order.length === 0) return <p className="undertittel">Ingen kontrollpunkter ennå — legg til det første over.</p>

  return (
    <ul className="rutine-kort-liste">
      {order.map((p) => (
        <li
          key={p.id}
          className={`rutine-kort ${over === p.id ? 'drag-over' : ''}`}
          onDragOver={(e) => { e.preventDefault(); if (over !== p.id) setOver(p.id) }}
          onDragLeave={() => setOver((o) => (o === p.id ? null : o))}
          onDrop={() => dropPaa(p.id)}
        >
          <div
            className="rutine-kort-flytt"
            draggable
            onDragStart={() => { dragId.current = p.id }}
            onDragEnd={() => { setOver(null); dragId.current = null }}
            title="Dra for å endre rekkefølge"
            aria-label="Dra for å endre rekkefølge"
          >
            ⠿
          </div>
          <div className="rutine-kort-innhold">
            <form action={oppdaterPunkt} className="rutine-kort-form">
              <input type="hidden" name="id" value={p.id} />
              <input name="navn" defaultValue={p.navn} placeholder="Navn på enhet (f.eks. Kjøleskap baguette)" required />
              <div className="ik-punkt-rad">
                <select name="type" defaultValue={p.type} aria-label="Type">
                  {TYPER.map((t) => <option key={t} value={t}>{TYPE_ETIKETT[t] ?? t}</option>)}
                </select>
                <select name="frekvens" defaultValue={p.frekvens} aria-label="Frekvens">
                  {FREKVENSER.map((f) => <option key={f} value={f}>{FREKVENS_ETIKETT[f] ?? f}</option>)}
                </select>
                <input name="min_temp" inputMode="decimal" defaultValue={p.min_temp ?? ''} placeholder="min °C" aria-label="Min" />
                <input name="max_temp" inputMode="decimal" defaultValue={p.max_temp ?? ''} placeholder="maks °C" aria-label="Maks" />
              </div>
              <div className="rutine-kort-knapper"><button type="submit" className="liten primar">Lagre</button></div>
            </form>
            <SlettKnapp hva={p.navn} handling={slettKontrollpunkt} id={p.id} merke="Slett punkt" />
          </div>
        </li>
      ))}
    </ul>
  )
}
