'use client'
import { useEffect, useRef, useState } from 'react'
import { SPORSMAL } from './demo'
import { useRolig } from './bevegelse'

// =====================================================================
// ASSISTENTEN
//
// AI er ikke produktet — det er inngangen til det. Derfor vises
// VERKTØYNAVNENE før svaret: `hent_salg`, `hent_timesalg`,
// `hent_produksjonsplan`. De er de ekte, fra `VERKTOYNAVN` i
// lib/ai/verktoy.ts, og de sier noe et pent svar ikke kan si — at den
// slår opp i tabeller i stedet for å finne på.
//
// Assistenten har 25 slike verktøy. Å vise fire av dem per spørsmål er
// nok til å vise formen; å liste alle ville vært en funksjonsliste.
//
// **Fet skrift kommer fra `**`-merking i demodataene**, ikke fra HTML i
// en streng. Å sette `dangerouslySetInnerHTML` på markedsføringstekst
// for å få to ord i halvfet, er en dør som står åpen for alltid mot en
// gevinst på null.
// =====================================================================

/** Deler «tekst med **fet** i» til noder. Ingen HTML, ingen innerHTML. */
function medFet(tekst: string) {
  return tekst.split('**').map((del, i) => (
    i % 2 === 1 ? <strong key={i}>{del}</strong> : <span key={i}>{del}</span>
  ))
}

export function Assistent() {
  const [valgt, setValgt] = useState(0)
  const [steg, setSteg] = useState(0)
  const rolig = useRolig()
  const timere = useRef<ReturnType<typeof setTimeout>[]>([])

  // NULLSTILLING UNDER RENDER, ikke i en effekt. Å bytte spørsmål skal
  // starte trappen på nytt; gjøres det i en effekt, rekker det gamle
  // svaret å vises i én frame først.
  const [forrige, setForrige] = useState(valgt)
  if (valgt !== forrige) { setForrige(valgt); setSteg(0) }

  const d = SPORSMAL[valgt]
  // Med ro står alt ferdig. Ellers følger det trappen.
  const viste = rolig ? d.verktoy.length : Math.min(steg, d.verktoy.length)
  const svarPaa = rolig || steg > d.verktoy.length

  useEffect(() => {
    timere.current.forEach(clearTimeout)
    timere.current = []
    if (rolig) return
    const antall = SPORSMAL[valgt].verktoy.length
    for (let i = 1; i <= antall + 1; i++) {
      timere.current.push(setTimeout(() => setSteg(i), 90 * i + (i > antall ? 220 : 0)))
    }
    return () => timere.current.forEach(clearTimeout)
  }, [valgt, rolig])

  return (
    <section className="lp-seksjon lp-seksjon-tont">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Assistenten</p>
        <h2 className="lp-h2">Spør virksomheten din.</h2>
        <p className="lp-ingress">
          Assistenten har 25 verktøy inn i de samme tabellene som resten av systemet. Den
          finner ikke på tall — den slår opp, og sier hvor svaret kommer fra.
        </p>

        <div className="lp-spor">
          <p className="lp-spor-felt">
            <span className="lp-spor-q">{d.q}</span>
            <span className="lp-karet" aria-hidden="true" />
          </p>
          <div className="lp-spor-svar">
            <p className="lp-verktoy" aria-label="Verktøy assistenten brukte">
              {d.verktoy.map((v, i) => (
                <span key={v} className={i < viste ? 'lp-inn' : undefined}>{v}</span>
              ))}
            </p>
            <p className="lp-svar" aria-live="polite">{svarPaa ? medFet(d.svar) : null}</p>
          </div>
        </div>

        <div className="lp-forslag" role="group" aria-label="Eksempelspørsmål">
          {SPORSMAL.map((s, i) => (
            <button
              key={s.q} type="button"
              aria-pressed={valgt === i}
              onClick={() => setValgt(i)}
            >
              {s.q}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
