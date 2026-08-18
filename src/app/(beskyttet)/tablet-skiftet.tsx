import Link from 'next/link'
import { gjenstaar, overskrift, VIS_ANTALL, type Kilder } from '@/lib/tablet/gjenstaar'

// =====================================================================
// «Hva gjenstår på skiftet» — det første man ser på nettbrettet.
//
// Erstatter ikke flisene, men står FORAN dem. Flisene er fortsatt veien
// til alt systemet kan; denne svarer på det man faktisk kom for.
//
// Se → forstå → gjør → ferdig. Hver linje er en lenke rett til
// handlingen, ikke til en modul man må navigere videre i.
// =====================================================================

export function TabletSkiftet({
  kilder,
  ord = {},
}: {
  kilder: Kilder
  ord?: Record<string, string>
}) {
  const t = (s: string) => ord[s] ?? s
  const alle = gjenstaar(kilder)
  const vist = alle.slice(0, VIS_ANTALL)
  const flere = alle.length - vist.length

  if (alle.length === 0) {
    return (
      <section className="tskift tskift-ferdig">
        <p className="tskift-ferdig-tekst">{t('Alt er gjort')}</p>
        <p className="tskift-ferdig-under">{t('Ingenting venter på deg akkurat nå.')}</p>
      </section>
    )
  }

  return (
    <section className="tskift" aria-labelledby="tskift-tittel">
      <h2 className="tskift-tittel" id="tskift-tittel">{t(overskrift(alle.length))}</h2>

      <ol className="tskift-liste">
        {vist.map((g, i) => (
          <li key={g.id}>
            <Link href={g.sti} className={`tskift-rad${g.kritisk ? ' kritisk' : ''}`}>
              {/* Nummeret gjør rekkefølgen til en beskjed: ta denne først. */}
              <span className="tskift-nr" aria-hidden>{i + 1}</span>
              <span className="tskift-tekst">
                {g.tekst}
                {g.klokkeslett && (
                  <span className="tskift-tid">{t('skulle vært gjort')} {g.klokkeslett}</span>
                )}
              </span>
              <span className="tskift-pil" aria-hidden>›</span>
            </Link>
          </li>
        ))}
      </ol>

      {flere > 0 && (
        // Ingenting er skjult — resten står i kø. Uten denne linjen ville
        // en tom liste kunnet lyve.
        <p className="tskift-flere">
          {t('og')} {flere} {flere === 1 ? t('ting til') : t('ting til')}
        </p>
      )}
    </section>
  )
}
