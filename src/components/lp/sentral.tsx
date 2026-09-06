'use client'
import { useState } from 'react'
import { SENTRAL } from './demo'
import { useSynlig } from './bevegelse'

// =====================================================================
// DRIFTSSENTRALEN
//
// Poenget er lesetiden: en leder med fem stasjoner skal se HVOR det
// trenger oppmerksomhet på et blikk, og så kunne bore i HVORFOR.
//
// FARGEN ALENE BÆRER IKKE BESKJEDEN. Hver stasjon har også et stikkord
// under navnet («svinn 15,2 %», «regnskap mangler»), og knappen sier i
// aria-etiketten hva tilstanden er. En prikk er en påminnelse for den
// som ser den, ikke informasjon for den som ikke gjør det.
// =====================================================================

const PIP = { ok: 'lp-st-pip lp-st-ok', folg: 'lp-st-pip lp-st-folg', stopp: 'lp-st-pip lp-st-stopp' } as const
const ORD = { ok: 'innenfor', folg: 'følg med', stopp: 'krever handling' } as const

export function Driftssentral() {
  const [valgt, setValgt] = useState(0)
  const { ref, synlig } = useSynlig<HTMLDivElement>(0.25)
  const st = SENTRAL[valgt]

  return (
    <section className="lp-seksjon" id="ledelse">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Flere stasjoner</p>
        <h2 className="lp-h2">Se hvor det brenner. Så hvorfor.</h2>
        <p className="lp-ingress">
          Én rad per stasjon, én farge per tilstand. Trykk på en, så står forklaringen under.
        </p>

        <div className="lp-sentral" ref={ref} role="group" aria-label="Stasjoner">
          {SENTRAL.map((s, i) => (
            <button
              key={s.navn} type="button" className="lp-st"
              aria-pressed={valgt === i}
              aria-label={`${s.navn} — ${ORD[s.status]}. ${s.stikkord}.`}
              onClick={() => setValgt(i)}
            >
              <span className="lp-st-topp">
                <span className="lp-st-navn">{s.navn}</span>
                <span className={PIP[s.status]} aria-hidden="true" />
              </span>
              <span className="lp-st-linje">{s.stikkord}</span>
              <span className="lp-st-bar">
                <i data-fyll={synlig ? s.andel : 0} />
              </span>
            </button>
          ))}
        </div>

        <div className="lp-st-detalj" aria-live="polite">
          <h3>{st.navn}</h3>
          <p>{st.forklaring}</p>
        </div>

        <p className="lp-brev-note"><span className="lp-demo lp-demo-morkt">Demodata</span></p>
      </div>
    </section>
  )
}
