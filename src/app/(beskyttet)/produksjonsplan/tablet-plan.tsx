'use client'
import { useState } from 'react'
import { loggLagd } from './handlinger'
import { useT } from '../oversett-kontekst'

export type TabletProdukt = { varenavn: string; planlagt: number; start_antall: number; lagd_hittil: number }
export type TabletGruppe = { navn: string; produkter: TabletProdukt[] }

export function TabletPlan({ stasjonId, dato, notat, grupper }: { stasjonId: string; dato: string; notat: string | null; grupper: TabletGruppe[] }) {
  const t = useT()
  const [lagd, setLagd] = useState<Record<string, number>>(() =>
    Object.fromEntries(grupper.flatMap((g) => g.produkter).map((p) => [p.varenavn, p.lagd_hittil])),
  )

  function endre(p: TabletProdukt, ny: number) {
    const v = Math.max(0, Math.round(ny))
    setLagd((s) => ({ ...s, [p.varenavn]: v }))
    void loggLagd(stasjonId, dato, p.varenavn, v)
  }

  return (
    <>
      {notat && (
        <div className="tablet-melding viktig">
          <span className="tablet-melding-merke">{t('Beskjed')}</span>
          <span>{notat}</span>
        </div>
      )}
      {grupper.map((g) => (
        <section className="tablet-seksjon" key={g.navn}>
          <h2>{g.navn}</h2>
          <div className="pp-tab-liste">
            {g.produkter.map((p) => {
              const x = lagd[p.varenavn] ?? 0
              const pst = p.planlagt > 0 ? Math.min(100, Math.round((x / p.planlagt) * 100)) : 0
              const ferdig = x >= p.planlagt && p.planlagt > 0
              return (
                <div className={`pp-tab-rad ${ferdig ? 'ferdig' : ''}`} key={p.varenavn}>
                  <div className="pp-tab-topp">
                    <span className="pp-tab-navn">{p.varenavn}</span>
                    <span className="pp-tab-tall">{x} / {p.planlagt}</span>
                  </div>
                  <div className="pp-tab-bar"><span style={{ width: `${pst}%` }} /></div>
                  <div className="pp-tab-bunn">
                    {p.start_antall > 0 && <span className="pp-tab-start">{t('Klart til morgen')}: {p.start_antall}</span>}
                    <div className="stepper">
                      <button type="button" onClick={() => endre(p, x - 1)} aria-label="−">−</button>
                      <input inputMode="numeric" value={x} onChange={(e) => endre(p, Number(e.target.value.replace(/\D/g, '')))} aria-label={`${t('Lagd')} ${p.varenavn}`} />
                      <button type="button" onClick={() => endre(p, x + 1)} aria-label="+">+</button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </section>
      ))}
    </>
  )
}
