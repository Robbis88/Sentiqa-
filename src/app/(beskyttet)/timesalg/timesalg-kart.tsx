'use client'
import { useState } from 'react'
import { kr, tall } from '@/lib/format'

type Rad = { stasjon_id: string; time: string; salg: number; inne: number; ute: number }
type Stasjon = { id: string; navn: string }
type Metrikk = 'salg' | 'inne' | 'ute'

const VALG: { key: Metrikk; navn: string; fmt: (v: number) => string }[] = [
  { key: 'salg', navn: 'Salg', fmt: (v) => kr.format(v) },
  { key: 'inne', navn: 'Innekunder', fmt: (v) => tall.format(v) },
  { key: 'ute', navn: 'Utekunder', fmt: (v) => tall.format(v) },
]

function startTime(t: string): number {
  return Number.parseInt(t.split('-')[0], 10) || 0
}

export function TimesalgKart({ stasjoner, rader, harInneUte }: { stasjoner: Stasjon[]; rader: Rad[]; harInneUte: boolean }) {
  const [metrikk, setMetrikk] = useState<Metrikk>('salg')
  const valg = VALG.find((v) => v.key === metrikk)!
  const timer = [...new Set(rader.map((r) => r.time))].sort((a, b) => startTime(a) - startTime(b))

  const verdi = new Map<string, number>()
  let maks = 0
  for (const r of rader) {
    const v = r[metrikk] ?? 0
    verdi.set(`${r.stasjon_id}|${r.time}`, v)
    if (v > maks) maks = v
  }
  const sumPer = (id: string) => timer.reduce((a, t) => a + (verdi.get(`${id}|${t}`) ?? 0), 0)

  return (
    <>
      {harInneUte && (
        <div className="metrikk-bytte">
          {VALG.map((v) => (
            <button key={v.key} type="button" className={`metrikk-knapp ${metrikk === v.key ? 'aktiv' : ''}`} onClick={() => setMetrikk(v.key)}>
              {v.navn}
            </button>
          ))}
        </div>
      )}

      <div className="heatmap-wrap">
        <table className="heatmap">
          <thead>
            <tr>
              <th>Time</th>
              {stasjoner.map((s) => <th key={s.id}>{s.navn}</th>)}
            </tr>
          </thead>
          <tbody>
            {timer.map((t) => (
              <tr key={t}>
                <td className="time">{t}</td>
                {stasjoner.map((s) => {
                  const v = verdi.get(`${s.id}|${t}`) ?? 0
                  const alpha = maks > 0 ? v / maks : 0
                  return (
                    <td key={s.id} style={{ background: `rgba(37, 99, 235, ${alpha.toFixed(3)})`, color: alpha > 0.5 ? '#fff' : 'inherit' }}>
                      {v > 0 ? valg.fmt(v) : ''}
                    </td>
                  )
                })}
              </tr>
            ))}
            <tr className="sum">
              <td className="time">Sum</td>
              {stasjoner.map((s) => <td key={s.id}>{valg.fmt(sumPer(s.id))}</td>)}
            </tr>
          </tbody>
        </table>
      </div>
    </>
  )
}
