'use client'
import { useState, useTransition } from 'react'
import { tall } from '@/lib/format'
import { setLinje } from './handlinger'

export type Produkt = {
  varenavn: string
  baseline: number
  faktor: number
  foreslatt: number
  planlagt: number
  flagg?: string[]
}
export type Gruppe = { kode: string | null; navn: string; produkter: Produkt[] }

const FLAGG_MERKE: Record<string, { ikon: string; tekst: string }> = {
  fjor_kampanje: { ikon: '🚩', tekst: 'Kampanje i fjor — justert ned' },
  paagaaende_kampanje: { ikon: '🎯', tekst: 'Mulig pågående kampanje — vektet 50/50' },
  ny: { ikon: '✨', tekst: 'Nytt produkt — basert på nylig salg' },
  fa_data: { ikon: '⚠️', tekst: 'Lite historikk' },
}

export function PlanTabell({ grupper, stasjonId, dato }: { grupper: Gruppe[]; stasjonId: string; dato: string }) {
  const start0: Record<string, number> = {}
  for (const g of grupper) for (const p of g.produkter) start0[p.varenavn] = p.planlagt
  const [verdier, setVerdier] = useState<Record<string, number>>(start0)
  const [, start] = useTransition()

  function endre(g: Gruppe, p: Produkt, ny: number) {
    const v = Math.max(0, Math.round(ny || 0))
    setVerdier((prev) => ({ ...prev, [p.varenavn]: v }))
    start(() => {
      void setLinje({
        stasjon_id: stasjonId,
        dato,
        varenavn: p.varenavn,
        varegruppe_kode: g.kode,
        varegruppe_navn: g.navn,
        foreslatt: p.foreslatt,
        planlagt: v,
      })
    })
  }

  const total = grupper.reduce((a, g) => a + g.produkter.reduce((b, p) => b + (verdier[p.varenavn] ?? 0), 0), 0)
  const totalForeslatt = grupper.reduce((a, g) => a + g.produkter.reduce((b, p) => b + p.foreslatt, 0), 0)

  return (
    <>
      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{tall.format(total)} <small>stk</small></span>
          <span className="kpi-merke">Planlagt produksjon i dag</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{tall.format(totalForeslatt)} <small>stk</small></span>
          <span className="kpi-merke">AI-forslag</span>
        </div>
      </section>

      {grupper.map((g) => {
        const sum = g.produkter.reduce((b, p) => b + (verdier[p.varenavn] ?? 0), 0)
        return (
          <section className="kort" key={g.kode ?? g.navn}>
            <h2>{g.navn} <span className="undertittel">· {g.kode}</span> <span className="gruppe-sum">{tall.format(sum)} stk</span></h2>
            <table className="tabell pp-tabell">
              <thead>
                <tr><th>Produkt</th><th className="mob-skjul">Snitt/dag</th><th className="mob-skjul">Faktor</th><th>Forslag</th><th>Planlagt</th></tr>
              </thead>
              <tbody>
                {g.produkter.map((p) => (
                  <tr key={p.varenavn}>
                    <td>
                      {p.varenavn}
                      {(p.flagg ?? []).map((fl) => FLAGG_MERKE[fl] ? <span key={fl} className="pp-flagg" title={FLAGG_MERKE[fl].tekst}> {FLAGG_MERKE[fl].ikon}</span> : null)}
                    </td>
                    <td className="mob-skjul">{tall.format(Math.round(p.baseline))}</td>
                    <td className="mob-skjul">×{p.faktor.toFixed(2)}</td>
                    <td>{tall.format(p.foreslatt)}</td>
                    <td>
                      <div className="stepper">
                        <button type="button" onClick={() => endre(g, p, (verdier[p.varenavn] ?? 0) - 1)} aria-label="Mindre">−</button>
                        <input
                          inputMode="numeric"
                          value={verdier[p.varenavn] ?? 0}
                          onChange={(e) => endre(g, p, Number(e.target.value.replace(/\D/g, '')))}
                          aria-label={`Planlagt ${p.varenavn}`}
                        />
                        <button type="button" onClick={() => endre(g, p, (verdier[p.varenavn] ?? 0) + 1)} aria-label="Mer">+</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        )
      })}
    </>
  )
}
