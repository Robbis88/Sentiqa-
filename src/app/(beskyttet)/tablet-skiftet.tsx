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

  // Overskriften settes sammen i `overskrift()`, som får `t` med seg.
  //
  // TO FORSØK BLE FORKASTET FØR DETTE. Først sto den som `t(overskrift(n))`
  // — én ferdig streng — og da kunne den ikke oversettes: «4 ting igjen»
  // finnes ikke i noen ordliste, og finnes aldri, fordi det er uendelig
  // mange av dem. Nettbrettets viktigste overskrift sto på norsk uansett
  // hvilket språk hun hadde valgt.
  //
  // Så sto den som en IIFE midt inne i `<h2>`, og da forsvant den ut av
  // vakthundens seksjonskart: vakten leser navnet på en seksjon ut av
  // kilden, og en funksjon som kalles på stedet har ikke noe navn å lese.
  // Seksjonen så ut som fjernet fordi den var blitt uleselig — akkurat
  // den formen for stille tap vakten finnes for.
  //
  // Nå gjøres begge deler ett sted: tallet står utenfor frasen, og
  // uttrykket har et navn vakten kan se.
  const tittel = overskrift(alle.length, t)

  return (
    <section className="tskift" aria-labelledby="tskift-tittel">
      <h2 className="tskift-tittel" id="tskift-tittel">{tittel}</h2>

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
          {t('og')} {flere} {t('ting til')}
        </p>
      )}
    </section>
  )
}
