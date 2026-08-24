'use client'
import { useRef, useState, useTransition } from 'react'
import { oppdaterRutine, slettRutine, lagreRekkefolge } from '../handlinger'
import { SlettKnapp } from '@/components/ui/slett-knapp'

type Rutine = { id: string; tittel: string; beskrivelse: string | null; ukedager: number[]; paakrevd_bilde: boolean }

const DAG_REKKE = [1, 2, 3, 4, 5, 6, 0]
const UKEDAG_NAVN = ['Søn', 'Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør']

function Ukedager({ valgt }: { valgt: number[] }) {
  return (
    <span className="ukedag-velger">
      {DAG_REKKE.map((i) => (
        <label key={i} className="ukedag"><input type="checkbox" name="ukedager" value={i} defaultChecked={valgt.includes(i)} /> {UKEDAG_NAVN[i]}</label>
      ))}
    </span>
  )
}

export function RutineListe({ skjemaId, rutiner }: { skjemaId: string; rutiner: Rutine[] }) {
  const [order, setOrder] = useState(rutiner)
  const [over, setOver] = useState<string | null>(null)
  const dragId = useRef<string | null>(null)
  const [, start] = useTransition()

  function dropPaa(targetId: string) {
    const from = dragId.current
    setOver(null)
    dragId.current = null
    if (!from || from === targetId) return
    const next = [...order]
    const fi = next.findIndex((r) => r.id === from)
    const ti = next.findIndex((r) => r.id === targetId)
    if (fi < 0 || ti < 0) return
    const [m] = next.splice(fi, 1)
    next.splice(ti, 0, m)
    setOrder(next)
    start(async () => { await lagreRekkefolge(skjemaId, next.map((r) => r.id)) })
  }

  if (order.length === 0) return <p className="undertittel">Ingen rutiner ennå — legg til den første over.</p>

  return (
    <ul className="rutine-kort-liste">
      {order.map((r) => (
        <li
          key={r.id}
          className={`rutine-kort ${over === r.id ? 'drag-over' : ''}`}
          onDragOver={(e) => { e.preventDefault(); if (over !== r.id) setOver(r.id) }}
          onDragLeave={() => setOver((o) => (o === r.id ? null : o))}
          onDrop={() => dropPaa(r.id)}
        >
          <div
            className="rutine-kort-flytt"
            draggable
            onDragStart={() => { dragId.current = r.id }}
            onDragEnd={() => { setOver(null); dragId.current = null }}
            title="Dra for å endre rekkefølge"
            aria-label="Dra for å endre rekkefølge"
          >
            ⠿
          </div>
          <div className="rutine-kort-innhold">
            <form action={oppdaterRutine} className="rutine-kort-form">
              <input type="hidden" name="id" value={r.id} />
              <input type="hidden" name="skjema_id" value={skjemaId} />
              <input name="tittel" defaultValue={r.tittel} required />
              <textarea name="beskrivelse" rows={2} defaultValue={r.beskrivelse ?? ''} placeholder="Notis (valgfri)" />
              <label className="avkryss bilde-krav"><input type="checkbox" name="paakrevd_bilde" defaultChecked={r.paakrevd_bilde} /> <span>📷 Krev bilde</span></label>
              <span className="undertittel">Ukedager (tom = alle skjema-dager)</span>
              <Ukedager valgt={r.ukedager} />
              <div className="rutine-kort-knapper"><button type="submit" className="liten primar">Lagre</button></div>
            </form>
            <SlettKnapp hva={r.tittel} handling={slettRutine} id={r.id} merke="Slett rutine" />
          </div>
        </li>
      ))}
    </ul>
  )
}
