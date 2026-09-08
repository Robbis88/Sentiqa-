'use client'
import { useState, useTransition } from 'react'
import { loggLagd } from './handlinger'
import { useT } from '../oversett-kontekst'

export type TabletProdukt = { varenavn: string; planlagt: number; start_antall: number; lagd_hittil: number }
export type TabletGruppe = { navn: string; produkter: TabletProdukt[] }

export function TabletPlan({ stasjonId, dato, notat, grupper }: { stasjonId: string; dato: string; notat: string | null; grupper: TabletGruppe[] }) {
  const t = useT()
  const [lagd, setLagd] = useState<Record<string, number>>(() =>
    Object.fromEntries(grupper.flatMap((g) => g.produkter).map((p) => [p.varenavn, p.lagd_hittil])),
  )
  const [feil, setFeil] = useState<string | null>(null)
  const [, start] = useTransition()

  // =================================================================
  // `void` KASTET HELE SVARET
  // =================================================================
  // Her sto `void loggLagd(...)`. `loggLagd` er nøye bygget for å kaste
  // både på feil OG på null skrevne rader — hele poenget med `0167`:
  // «en handling som svarer ok på noe som ikke ble skrevet, ser ut som
  // en som virket». `void` gjorde nettopp det umulige mulig.
  //
  // Følgen: hun trykker seg opp til «Alt er lagd», baren går til 100 %,
  // og ved neste lasting står tallet på 0. Butikksjefen ser at
  // ingenting ble produsert.
  //
  // TALLET RULLES TILBAKE PÅ SKJERMEN. Å bare vise en feilmelding ved
  // siden av et tall som fortsatt står, ville latt to sannheter stå
  // samtidig — og den hun ser er den hun tror på.
  function endre(p: TabletProdukt, ny: number) {
    const v = Math.max(0, Math.round(ny))
    const forrige = lagd[p.varenavn] ?? p.lagd_hittil
    setLagd((s) => ({ ...s, [p.varenavn]: v }))
    setFeil(null)
    start(async () => {
      try {
        await loggLagd(stasjonId, dato, p.varenavn, v)
      } catch {
        setLagd((s) => ({ ...s, [p.varenavn]: forrige }))
        setFeil(t('Tallet ble ikke lagret. Prøv en gang til.'))
      }
    })
  }

  return (
    <>
      {feil && (
        <div className="tablet-melding viktig" role="alert">
          <span>{feil}</span>
        </div>
      )}
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
                    {/* ETT TRYKK FOR DET SOM SKJEDDE I EN BEVEGELSE. Ni boller
                        var ni trykk paa pluss. De to knappene daekker de to
                        vanlige tilfellene; stepperen blir staaende, fordi den
                        er den eneste veien NED igjen — og en flate uten anger
                        er en flate folk ikke toer trykke i. */}
                    {p.start_antall > 0 && x < p.start_antall && (
                      <button
                        type="button"
                        className="pp-tab-kvitt"
                        onClick={() => endre(p, p.start_antall)}
                      >
                        {t('Startpartiet er lagd')}
                      </button>
                    )}
                    {p.planlagt > 0 && (
                      <button
                        type="button"
                        className="pp-tab-kvitt alt"
                        disabled={ferdig}
                        onClick={() => endre(p, p.planlagt)}
                      >
                        {t('Alt er lagd')}
                      </button>
                    )}
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
