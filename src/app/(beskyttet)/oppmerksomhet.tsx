import Link from 'next/link'
import type { Signal } from '@/lib/signaler'

// Ett funn = én rad, ikke ett kort. Et kort sier «her er en modul»; en rad
// med alvorlighetsstripe sier «her er en sak». Rekkefølgen er informasjon,
// så alle radene ser like ut bortsett fra stripen og tallet.
//
// <details> er bevisst: utvidelsen virker uten JavaScript, og skjermlesere
// får åpne/lukke gratis.
export function Oppmerksomhet({ signaler }: { signaler: Signal[] }) {
  if (signaler.length === 0) {
    return (
      <section className="sq-seksjon">
        <div className="sq-seksjon-hode">
          <h2>Ingenting trenger oppmerksomhet</h2>
        </div>
        <p className="undertittel">
          Ingen avvik i salget, ingen forsinkede oppgaver og ingen uleste tilbakemeldinger.
        </p>
      </section>
    )
  }

  return (
    <section className="sq-seksjon">
      <div className="sq-seksjon-hode">
        <h2>
          {signaler.length} {signaler.length === 1 ? 'ting trenger' : 'ting trenger'} oppmerksomhet
        </h2>
        <span className="sq-merkelapp">Sortert etter konsekvens</span>
      </div>

      {signaler.map((s) => (
        <details className="sq-sak" data-niva={s.niva} key={s.id}>
          <summary>
            <span className="sq-stripe" aria-hidden="true" />
            <span className="sq-sak-tekst">
              <span className="sq-sak-tittel">
                <b>{s.tittel}</b>
                {s.endring ? <span className="sq-endring">{s.endring}</span> : null}
              </span>
              <span className="sq-sak-under">{s.detalj}</span>
            </span>
            <span className="sq-sak-hoyre">
              <span className="sq-merkelapp">{s.merke}</span>
              <svg className="sq-pil" width="12" height="12" viewBox="0 0 12 12" aria-hidden="true">
                <path d="M4 2.5 8 6l-4 3.5" fill="none" stroke="currentColor" strokeWidth="1.6"
                  strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
          </summary>

          <div className="sq-utdyp">
            <div className="sq-utdyp-rad">
              <span className="sq-merkelapp">Hva Sentiqa ser</span>
              <p>{s.detalj}</p>
            </div>

            {(s.konsekvensKr != null || s.dager != null) && (
              <div className="sq-utdyp-rad">
                <span className="sq-merkelapp">Grunnlag</span>
                <span className="sq-bevis">
                  {s.konsekvensKr != null && (
                    <span>{Math.abs(Math.round(s.konsekvensKr)).toLocaleString('nb-NO')} kr</span>
                  )}
                  {s.dager != null && <span>{s.dager} {s.dager === 1 ? 'dag' : 'dager'}</span>}
                </span>
              </div>
            )}

            <div className="sq-utdyp-rad">
              <span className="sq-merkelapp">Neste steg</span>
              <span className="sq-handlinger">
                <Link href={s.lenke} className="sq-knapp primar">Undersøk</Link>
              </span>
            </div>
          </div>
        </details>
      ))}
    </section>
  )
}
