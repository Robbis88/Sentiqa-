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
                    // TO FEIL I EN LINJE, begge funnet forst da fixturen
                    // gjorde kartet synlig i CI:
                    //
                    // 1) Fargen var `rgba(37, 99, 235, ...)` - den GAMLE
                    //    bla merkevarefargen, staaende igjen etter
                    //    palettbyttet i trinn 01. Fargevakten TALTE den,
                    //    men som en av 261 i grunnlinja; ingen saa hvilken.
                    //
                    // 2) Hvit tekst slo inn ved alpha 0.5, og hvitt paa
                    //    den halvgjennomsiktige flata gir 2.6:1. Under
                    //    kravet, og usynlig for enhver vakt som ikke
                    //    kjorer med data.
                    //
                    // Naa: merkevarefargen via token, og tintet stopper
                    // paa 55 % saa teksten alltid staar mork paa lyst.
                    // Kartet mister ingen lesbarhet - forskjellen mellom
                    // en rolig og en travel time var aldri de siste 45
                    // prosentene metning.
                    <td
                      key={s.id}
                      style={{
                        background: `color-mix(in srgb, var(--primaer) ${Math.round(alpha * 55)}%, transparent)`,
                      }}
                    >
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
