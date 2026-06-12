'use client'
import { useState, useTransition } from 'react'
import { tall } from '@/lib/format'
import { setLinje, setNotat, publiser } from './handlinger'

export type Produkt = {
  varenavn: string
  baseline: number
  faktor: number
  foreslatt: number
  planlagt: number
  start_antall: number
  ekskludert: boolean
  flagg?: string[]
}
export type Gruppe = { kode: string | null; navn: string; produkter: Produkt[] }

const FLAGG_MERKE: Record<string, { ikon: string; tekst: string }> = {
  fjor_kampanje: { ikon: '🚩', tekst: 'Kampanje i fjor — justert ned' },
  paagaaende_kampanje: { ikon: '🎯', tekst: 'Mulig pågående kampanje — vektet 50/50' },
  ny: { ikon: '✨', tekst: 'Nytt produkt — basert på nylig salg' },
  fa_data: { ikon: '⚠️', tekst: 'Lite historikk' },
}

export function PlanTabell({
  grupper, stasjonId, dato, notat: notatInit, publisertTid,
}: {
  grupper: Gruppe[]
  stasjonId: string
  dato: string
  notat: string | null
  publisertTid: string | null
}) {
  const alle = grupper.flatMap((g) => g.produkter)
  const lag = (felt: 'planlagt' | 'start_antall') => Object.fromEntries(alle.map((p) => [p.varenavn, p[felt]]))
  const [planlagt, setPlanlagt] = useState<Record<string, number>>(lag('planlagt'))
  const [start, setStart] = useState<Record<string, number>>(lag('start_antall'))
  const [ekskl, setEkskl] = useState<Set<string>>(() => new Set(alle.filter((p) => p.ekskludert).map((p) => p.varenavn)))
  const [notat, setNotatTekst] = useState(notatInit ?? '')
  const [publisert, setPublisert] = useState<boolean>(!!publisertTid)
  const [melding, setMelding] = useState<string | null>(null)
  const [, overgang] = useTransition()

  function lagre(g: Gruppe, p: Produkt, over: { planlagt?: number; start_antall?: number; ekskludert?: boolean }) {
    overgang(() => {
      void setLinje({
        stasjon_id: stasjonId, dato, varenavn: p.varenavn, varegruppe_kode: g.kode, varegruppe_navn: g.navn,
        foreslatt: p.foreslatt,
        planlagt: over.planlagt ?? planlagt[p.varenavn] ?? p.foreslatt,
        start_antall: over.start_antall ?? start[p.varenavn] ?? 0,
        ekskludert: over.ekskludert ?? ekskl.has(p.varenavn),
      })
    })
  }
  function endrePlan(g: Gruppe, p: Produkt, ny: number) {
    const v = Math.max(0, Math.round(ny || 0)); setPlanlagt((s) => ({ ...s, [p.varenavn]: v })); lagre(g, p, { planlagt: v })
  }
  function endreStart(g: Gruppe, p: Produkt, ny: number) {
    const v = Math.max(0, Math.round(ny || 0)); setStart((s) => ({ ...s, [p.varenavn]: v })); lagre(g, p, { start_antall: v })
  }
  function toggleEkskl(g: Gruppe, p: Produkt) {
    const ny = !ekskl.has(p.varenavn)
    setEkskl((s) => { const c = new Set(s); if (ny) c.add(p.varenavn); else c.delete(p.varenavn); return c })
    lagre(g, p, { ekskludert: ny })
  }
  function publiserNa() {
    overgang(async () => {
      const r = await publiser(stasjonId, dato)
      setPublisert(r.ok); setMelding(r.ok ? 'Publisert til tableten ✓' : 'Kunne ikke publisere')
    })
  }

  const aktive = (p: Produkt) => !ekskl.has(p.varenavn)
  const total = alle.filter(aktive).reduce((a, p) => a + (planlagt[p.varenavn] ?? 0), 0)
  const totalForeslatt = alle.filter(aktive).reduce((a, p) => a + p.foreslatt, 0)
  const totalStart = alle.filter(aktive).reduce((a, p) => a + (start[p.varenavn] ?? 0), 0)

  return (
    <>
      <section className="nokkeltall">
        <div className="kpi"><span className="kpi-tall">{tall.format(total)} <small>stk</small></span><span className="kpi-merke">Planlagt</span></div>
        <div className="kpi"><span className="kpi-tall">{tall.format(totalStart)} <small>stk</small></span><span className="kpi-merke">Klart til morgenskift</span></div>
        <div className="kpi"><span className="kpi-tall">{tall.format(totalForeslatt)} <small>stk</small></span><span className="kpi-merke">AI-forslag</span></div>
      </section>

      {grupper.map((g) => {
        const sum = g.produkter.filter(aktive).reduce((b, p) => b + (planlagt[p.varenavn] ?? 0), 0)
        return (
          <section className="kort" key={g.kode ?? g.navn}>
            <h2>{g.navn} <span className="undertittel">· {g.kode}</span> <span className="gruppe-sum">{tall.format(sum)} stk</span></h2>
            <table className="tabell pp-tabell">
              <thead>
                <tr><th>Produkt</th><th className="mob-skjul">Snitt</th><th className="mob-skjul">×</th><th>Forslag</th><th>Start</th><th>Planlagt</th><th></th></tr>
              </thead>
              <tbody>
                {g.produkter.map((p) => {
                  const ute = ekskl.has(p.varenavn)
                  return (
                    <tr key={p.varenavn} className={ute ? 'pp-ute' : ''}>
                      <td>
                        {p.varenavn}
                        {(p.flagg ?? []).map((fl) => FLAGG_MERKE[fl] ? <span key={fl} className="pp-flagg" title={FLAGG_MERKE[fl].tekst}> {FLAGG_MERKE[fl].ikon}</span> : null)}
                      </td>
                      <td className="mob-skjul">{tall.format(Math.round(p.baseline))}</td>
                      <td className="mob-skjul">{p.faktor.toFixed(2)}</td>
                      <td>{tall.format(p.foreslatt)}</td>
                      <td>
                        <div className="stepper liten">
                          <button type="button" disabled={ute} onClick={() => endreStart(g, p, (start[p.varenavn] ?? 0) - 1)} aria-label="Mindre start">−</button>
                          <input inputMode="numeric" disabled={ute} value={start[p.varenavn] ?? 0} onChange={(e) => endreStart(g, p, Number(e.target.value.replace(/\D/g, '')))} aria-label={`Start ${p.varenavn}`} />
                          <button type="button" disabled={ute} onClick={() => endreStart(g, p, (start[p.varenavn] ?? 0) + 1)} aria-label="Mer start">+</button>
                        </div>
                      </td>
                      <td>
                        <div className="stepper">
                          <button type="button" disabled={ute} onClick={() => endrePlan(g, p, (planlagt[p.varenavn] ?? 0) - 1)} aria-label="Mindre">−</button>
                          <input inputMode="numeric" disabled={ute} value={planlagt[p.varenavn] ?? 0} onChange={(e) => endrePlan(g, p, Number(e.target.value.replace(/\D/g, '')))} aria-label={`Planlagt ${p.varenavn}`} />
                          <button type="button" disabled={ute} onClick={() => endrePlan(g, p, (planlagt[p.varenavn] ?? 0) + 1)} aria-label="Mer">+</button>
                        </div>
                      </td>
                      <td>
                        <button type="button" className="pp-ekskl" onClick={() => toggleEkskl(g, p)} title={ute ? 'Ta med igjen' : 'Ekskluder fra planen'}>{ute ? '↩' : '✕'}</button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </section>
        )
      })}

      <section className="kort">
        <h2>📝 Notat til de ansatte</h2>
        <textarea
          className="pp-notat" rows={2} value={notat} placeholder="F.eks. «Ekstra fokus på baguetter til lunsj»"
          onChange={(e) => setNotatTekst(e.target.value)}
          onBlur={() => overgang(() => { void setNotat(stasjonId, dato, notat) })}
        />
        <div className="pp-publiser">
          <button type="button" onClick={publiserNa}>{publisert ? 'Publiser på nytt' : 'Publiser til tableten'}</button>
          {publisert && <span className="ok">Publisert — synlig på tableten</span>}
          {melding && <span className="generer-melding">{melding}</span>}
        </div>
      </section>
    </>
  )
}
