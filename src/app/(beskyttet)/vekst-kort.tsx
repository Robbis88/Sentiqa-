'use client'
import { useState } from 'react'
import { kr } from '@/lib/format'
import type { VekstMetrikk } from '@/lib/tablethjem'
import { kortDato, ukedag, type Sammenlikning } from '@/lib/vekst-ifjor'
import { useT } from './oversett-kontekst'

// =====================================================================
// Vekst mot fjoråret, med ukedagene på plass.
//
// PREMISSET: ukedag betyr mer enn dato i detaljhandel. En lørdag likner
// mer på fjorårets lørdag enn på fjorårets samme kalenderdato. Derfor
// −364 dager (52 uker), ikke «samme dato i fjor».
//
// ALT SOM BESKRIVER DATAENE UTLEDES AV DATAENE. Undertittelen sa
// «torsdag mot torsdag» som fast tekst. Den var riktig den dagen koden
// ble skrevet, og feil resten av uka.
//
// «SISTE SALGSDAG», IKKE «I DAG». Importen henger ett til to døgn etter.
// Sto det «I dag» over et tall fra i forgårs, leste alle det som
// dagsferskt — og en butikk som hadde en dårlig mandag så det ikke før
// onsdag, uten å vite hvorfor tallet ikke stemte med kassa.
// =====================================================================

type Valg = 'samlet' | 'mat' | 'kaldDrikke'
const VALG: { key: Valg; navn: string }[] = [
  // «Samlet» er alt butikksalg UTEN drivstoff — pumpa betjener seg selv
  // og drukner alt annet. Se `v_butikksalg`.
  { key: 'samlet', navn: 'Samlet' },
  { key: 'mat', navn: 'Mat' },
  { key: 'kaldDrikke', navn: 'Kald drikke' },
]

/**
 * Prosenten, eller ingenting.
 *
 * ER FJORÅRET NULL, FINNES INGEN PROSENT. «+100 %» og «∞» er begge
 * usanne — da står kronene alene, og de er fortsatt sanne.
 */
function Diff({ s }: { s: Sammenlikning }) {
  const t = useT()
  if (s.pct === null) return null
  const opp = s.diff >= 0
  return (
    <span className={`vekst-diff ${opp ? 'opp' : 'ned'}`}>
      {opp ? '▲' : '▼'} {opp ? '+' : '−'}{Math.abs(s.pct)} % {t('mot i fjor')}
    </span>
  )
}

function Celle({ merke, s }: { merke: string; s: Sammenlikning }) {
  const t = useT()
  return (
    <div className="vekst-celle">
      <span className="vekst-merke">{merke}</span>
      <span className="vekst-tall">{kr.format(s.iAar)}</span>
      <Diff s={s} />
      {/* FJORÅRSVINDUET STÅR EKSPLISITT. Uten det er «−12 %» et tall
          uten motpart, og ingen kan etterprøve hva det ble målt mot. */}
      <span className="vekst-ifjor">
        {kr.format(s.iFjor)} {t('i fjor')}
        {' · '}
        {s.vinduIFjor.fra === s.vinduIFjor.til
          ? kortDato(s.vinduIFjor.til)
          : `${kortDato(s.vinduIFjor.fra)}–${kortDato(s.vinduIFjor.til)}`}
      </span>
      {/* SUMMERING OVER RADER SOM IKKE FINNES GIR 0, IKKE FEIL. Var
          butikken stengt i fjor, eller kom aldri importen, ser veksten
          strålende ut uten at noen får vite hvorfor. */}
      {s.manglerDager > 0 && (
        <span className="vekst-mangler">
          {t('Fjoråret mangler')} {s.manglerDager} {t('av')} {s.dagerIAar} {t('dager')}
        </span>
      )}
    </div>
  )
}

export function VekstKort(
  { metrikker, sisteDato }: {
    metrikker: { samlet: VekstMetrikk; mat: VekstMetrikk; kaldDrikke: VekstMetrikk }
    sisteDato: string
  },
) {
  const [valg, setValg] = useState<Valg>('samlet')
  const t = useT()
  const m = metrikker[valg]

  return (
    <section className="tablet-seksjon vekst-eng">
      <div className="vekst-eng-topp">
        <h2>{t('Vekst mot i fjor')}</h2>
        <div className="metrikk-bytte mork">
          {VALG.map((v) => (
            <button
              key={v.key}
              type="button"
              className={`metrikk-knapp ${valg === v.key ? 'aktiv' : ''}`}
              onClick={() => setValg(v.key)}
            >
              {t(v.navn)}
            </button>
          ))}
        </div>
      </div>

      {/* UKEDAGEN UTLEDES AV DATOEN. Aldri hardkodet. */}
      <p className="vekst-undertittel">
        {t('Sammenliknet med samme ukedag i fjor')} — {ukedag(sisteDato)}{' '}
        {t('mot')} {ukedag(m.sisteDag.vinduIFjor.til)}.
      </p>

      {m.streak > 0 && (
        <div className="vekst-streak-badge">
          {m.streak} {t(m.streak === 1 ? 'dag' : 'dager')} {t('på rad over fjoråret!')}
        </div>
      )}

      <div className="vekst-tall-rad">
        <Celle merke={`${t('Siste salgsdag')} · ${kortDato(sisteDato)}`} s={m.sisteDag} />
        <Celle merke={t('Måneden hittil')} s={m.maanedHittil} />
      </div>
    </section>
  )
}
