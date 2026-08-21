'use client'
import { useState, useEffect, useActionState } from 'react'
import { svarRunde, type SvarResultat } from './puls/handlinger'
import { useT } from './oversett-kontekst'

// FJESENE ER SELVE SPOERSMAALET, og blir staaende: en femtrinns skala
// tegnet som ansikter leses av folk som ikke leser norsk godt, og det er
// halve poenget med aa spoerre paa nettbrettet.
//
// MEN ETIKETTEN SA `1`. En skjermleser leste «knapp, 1» fem ganger, og
// tallet alene sier ikke om 1 er best eller verst. Naa staar ordet.
const FJES = [
  { v: 1, e: '😣', ord: 'Veldig dårlig' },
  { v: 2, e: '🙁', ord: 'Dårlig' },
  { v: 3, e: '😐', ord: 'Sånn passe' },
  { v: 4, e: '🙂', ord: 'Bra' },
  { v: 5, e: '😄', ord: 'Veldig bra' },
]

// Sporadisk puls-popup: dukker opp av og til (throttlet pr runde via
// localStorage), ikke ved hver lasting.
//
// IKKE anonymt, og det staar det naa. Svaret lagres knyttet til deg saa du
// ikke kan svare to ganger — men ingen med lederinnlogging kan lese den
// koblingen (0104). Paa en stasjon med ti ansatte er en fritekstkommentar
// dessuten ofte gjenkjennelig paa innholdet alene, uansett hva basen gjor.
// Et lofte som ikke kan holdes teknisk, gir vi ikke.
export function PulsPopp({ runde }: { runde: { id: string; tekst: string } | null }) {
  const t = useT()
  const [vis, setVis] = useState(false)
  const [valgt, setValgt] = useState<number | null>(null)
  const [tilstand, handling, venter] = useActionState<SvarResultat | undefined, FormData>(svarRunde, undefined)

  useEffect(() => {
    if (!runde) return
    try {
      if (localStorage.getItem(`puls-svart-${runde.id}`)) return
      const vist = Number(localStorage.getItem(`puls-vist-${runde.id}`) || 0)
      if (Date.now() - vist < 1000 * 60 * 60 * 4) return // snooze 4 timer
    } catch {
      /* ingen storage */
    }
    const t = setTimeout(() => {
      if (Math.random() < 0.5) setVis(true) // sporadisk
    }, 2000)
    return () => clearTimeout(t)
  }, [runde])

  useEffect(() => {
    if (tilstand?.ok && runde) {
      try {
        localStorage.setItem(`puls-svart-${runde.id}`, '1')
      } catch {
        /* */
      }
      const t = setTimeout(() => setVis(false), 1800)
      return () => clearTimeout(t)
    }
  }, [tilstand, runde])

  if (!runde || !vis) return null

  function snooze() {
    try {
      localStorage.setItem(`puls-vist-${runde!.id}`, String(Date.now()))
    } catch {
      /* */
    }
    setVis(false)
  }

  return (
    <div className="puls-popp">
      <div className="puls-popp-kort">
        {tilstand?.ok ? (
          <p className="puls-popp-takk">{t('Takk for svaret!')}</p>
        ) : (
          <>
            <p className="puls-popp-q">{runde.tekst}</p>
            <form action={handling}>
              <input type="hidden" name="runde_id" value={runde.id} />
              <input type="hidden" name="skala" value={valgt ?? ''} />
              <div className="puls-faces">
                {FJES.map((f) => (
                  <button type="button" key={f.v} className={`puls-face ${valgt === f.v ? 'valgt' : ''}`} onClick={() => setValgt(f.v)} aria-label={t(f.ord)}>
                    <span className="puls-emoji">{f.e}</span>
                  </button>
                ))}
              </div>
              <textarea name="kommentar" rows={2} placeholder={t('Kommentar (valgfri)')} />
              <p className="puls-popp-fotnote">
                {t('Lederen ser svaret og kommentaren, men ikke hvem som skrev den. '
                  + 'Er dere fa paa jobb, kan en kommentar likevel vaere lett aa kjenne igjen.')}
              </p>
              <div className="puls-popp-knapper">
                <button type="button" className="liten" onClick={snooze}>{t('Ikke nå')}</button>
                <button type="submit" disabled={!valgt || venter}>{venter ? t('Sender …') : t('Send')}</button>
              </div>
              {tilstand?.feil ? <p className="feil">{tilstand.feil}</p> : null}
            </form>
          </>
        )}
      </div>
    </div>
  )
}
