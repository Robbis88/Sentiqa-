import Link from 'next/link'
import type { Signal } from '@/lib/signaler'
import { SignalKnapper } from './signal-knapper'

// Ett funn = én rad, ikke ett kort. Et kort sier «her er en modul»; en rad
// med alvorlighetsstripe sier «her er en sak». Rekkefølgen er informasjon,
// så alle radene ser like ut bortsett fra stripen og tallet.
//
// <details> er bevisst: utvidelsen virker uten JavaScript, og skjermlesere
// får åpne/lukke gratis.

const NIVAA_ORD: Record<string, string> = {
  kritisk: 'Haster',
  folg: 'Følg med',
  info: 'Til orientering',
}

// «7 ting trenger oppmerksomhet» sier ikke om det er sju kritiske eller sju
// uleste meldinger. Da må sjefen lese alle sju for å finne de to som betyr
// noe — nøyaktig jobben denne lista skulle spare hen for.
function overskrift(signaler: Signal[]): string {
  const haster = signaler.filter((s) => s.niva === 'kritisk').length
  const resten = signaler.length - haster
  if (haster === 0) return `${resten} ${resten === 1 ? 'ting' : 'ting'} å se på`
  if (resten === 0) return `${haster} ting haster`
  return `${haster} ting haster · ${resten} til orientering`
}

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
        <h2>{overskrift(signaler)}</h2>
        <span className="sq-merkelapp">Viktigst øverst</span>
      </div>

      {signaler.map((s) => (
        <details className="sq-sak" data-niva={s.niva} key={s.id}>
          <summary>
            <span className="sq-stripe" aria-hidden="true" />
            <span className="sq-sak-tekst">
              <span className="sq-sak-tittel">
                {/* Alvorligheten må stå i ord, ikke bare i 3 px farge — stripen
                    er usynlig for skjermlesere, og rødt mot gult er ikke noe
                    alle skiller. */}
                <span className="sq-nivaa">{NIVAA_ORD[s.niva] ?? s.niva}</span>
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

          {/* Utvidelsen gjentok tidligere samme setning som sto i sammendraget
              — man betalte et klikk for null ny informasjon. Nå står bare det
              som ikke fikk plass over: grunnlaget og hva man kan gjøre. */}
          <div className="sq-utdyp">
            {(s.konsekvensKr != null || s.dager != null) && (
              <div className="sq-utdyp-rad">
                <span className="sq-merkelapp">Grunnlag</span>
                <span className="sq-bevis">
                  {s.konsekvensKr != null && (
                    <span>{Math.abs(Math.round(s.konsekvensKr)).toLocaleString('nb-NO')} kr i utslag</span>
                  )}
                  {s.dager != null && (
                    <span>{s.dager} {s.dager === 1 ? 'dag' : 'dager'} på rad</span>
                  )}
                </span>
              </div>
            )}

            <div className="sq-utdyp-rad">
              <span className="sq-merkelapp">Neste steg</span>
              <span className="sq-handlinger">
                <Link href={s.lenke} className="sq-knapp primar">Undersøk</Link>
                <SignalKnapper signalId={s.id} tittel={s.tittel} detalj={s.detalj} stasjonId={s.stasjonId} />
              </span>
            </div>
          </div>
        </details>
      ))}
    </section>
  )
}
